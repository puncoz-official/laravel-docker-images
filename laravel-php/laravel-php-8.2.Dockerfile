# syntax=docker/dockerfile:1

# Declared before the first FROM so the `FROM grpc-${INSTALL_GRPC}` alias
# below can resolve them.
ARG INSTALL_GRPC=false
ARG GRPC_VERSION=1.84.0

# ---------------------------------------------------------------------------
# grpc.so, built on its own.
#
# grpc vendors boringssl, abseil, upb and re2 — roughly 3000 C++ translation
# units, ~13 min on eight native cores and several times that under QEMU
# emulation. Building it here instead of inline below buys two things: the
# compile is keyed only on the PHP base image and GRPC_VERSION, so edits to
# the apt/node/composer layer no longer rebuild it, and the base and -grpc
# variants now share that layer byte-for-byte rather than each building it
# from scratch.
#
# The tarball is unpacked to a fixed path rather than left to pecl, which
# builds under /tmp/pear/temp/pear-build-<random>. ccache keys on the compiler
# command line, and the -I flags pecl derives from that random path differ on
# every run, so the cache would miss every time.
# ---------------------------------------------------------------------------
FROM php:8.2-fpm AS grpc-true

ARG GRPC_VERSION

RUN --mount=type=cache,target=/ccache,id=grpc-ccache,sharing=shared \
    set -ex; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        autoconf ccache g++ make pkg-config zlib1g-dev; \
    mkdir -p /usr/src/grpc; \
    curl -fsSL "https://pecl.php.net/get/grpc-${GRPC_VERSION}.tgz" \
        | tar -xz -C /usr/src/grpc --strip-components=1; \
    cd /usr/src/grpc; \
    export CCACHE_DIR=/ccache CCACHE_MAXSIZE=5G; \
    export CC="ccache cc" CXX="ccache c++"; \
    phpize; \
    ./configure --enable-grpc; \
    make -j"$(nproc)"; \
    ccache --show-stats; \
    mkdir -p /grpc-out; \
    cp modules/grpc.so /grpc-out/grpc.so; \
    strip --strip-debug /grpc-out/grpc.so

# The no-grpc arm of the alias. Same base as the final stage, so it adds one
# empty layer and no extra pull.
FROM php:8.2-fpm AS grpc-false
RUN mkdir -p /grpc-out

# Resolves to grpc-true or grpc-false. BuildKit only builds the stage this
# selects, so the plain :8.2 image never pays for the compile above.
FROM grpc-${INSTALL_GRPC} AS grpc-artifact

FROM php:8.2-fpm

LABEL maintainer="Puncoz Nepal <https://github.com/puncoz>"

ARG COMPOSER_VERSION=2.10.1
ARG NVM_VERSION=0.40.5
ARG DEFAULT_NODE_VERSION=24
# Space-separated list of extra extensions to install via docker-php-ext-install.
# Only works for extensions whose runtime libs are already present in this image
# (e.g. `mysqli`, `calendar`, `ldap`). For extensions needing extra apt deps,
# install them in your own downstream Dockerfile.
ARG PHP_EXTENSIONS=""

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_MEMORY_LIMIT=-1 \
    COMPOSER_HOME=/tmp/composer \
    NVM_DIR=/usr/local/nvm \
    COREPACK_ENABLE_DOWNLOAD_PROMPT=0

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone

# One build layer keeps the toolchain (g++/make/autoconf) out of the final
# image. With grpc hoisted into its own stage this layer is identical for the
# base and -grpc variants, so the second of the pair is a straight cache hit.
# nvm.sh is not `set -u`-safe (it reads $_, which dash leaves unset), so we
# use `set -ex` without -u.
RUN set -ex; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl git xz-utils \
        supervisor unzip zip \
        libgmp-dev libicu-dev libsodium-dev libsqlite3-dev \
        libpq-dev libzip-dev \
        libfreetype6-dev libjpeg62-turbo-dev libpng-dev \
        zlib1g-dev \
        autoconf g++ make pkg-config; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-configure exif --enable-exif; \
    docker-php-ext-install -j"$(nproc)" \
        bcmath \
        exif \
        gd \
        gmp \
        intl \
        opcache \
        pcntl \
        pdo_mysql \
        pdo_pgsql \
        pdo_sqlite \
        pgsql \
        sockets \
        sodium \
        zip; \
    if [ -n "$PHP_EXTENSIONS" ]; then \
        docker-php-ext-install -j"$(nproc)" $PHP_EXTENSIONS; \
    fi; \
    MAKEFLAGS="-j$(nproc)" pecl install redis; \
    docker-php-ext-enable redis; \
    strip --strip-debug /usr/local/lib/php/extensions/*/redis.so; \
    curl -sS https://getcomposer.org/installer | php -- \
        --install-dir=/usr/local/bin --filename=composer --version="${COMPOSER_VERSION}"; \
    mkdir -p "$NVM_DIR"; \
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" \
        | PROFILE=/dev/null bash; \
    . "$NVM_DIR/nvm.sh"; \
    nvm install "${DEFAULT_NODE_VERSION}"; \
    nvm alias default "${DEFAULT_NODE_VERSION}"; \
    nvm use default; \
    corepack enable; \
    corepack prepare yarn@stable --activate; \
    node_bin="$NVM_DIR/versions/node/$(nvm current)/bin"; \
    for b in node npm npx corepack yarn yarnpkg pnpm pnpx; do \
        [ -e "$node_bin/$b" ] && ln -sf "$node_bin/$b" "/usr/local/bin/$b"; \
    done; \
    nvm cache clear; \
    git config --global --add safe.directory '*'; \
    pecl clear-cache; \
    apt-get purge -y --auto-remove autoconf g++ make pkg-config; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.npm /root/.composer

# grpc.so from the stage at the top of this file. /grpc-out is empty when
# INSTALL_GRPC=false, so one COPY covers both variants.
COPY --from=grpc-artifact /grpc-out/ /tmp/grpc-out/
RUN set -ex; \
    if [ -f /tmp/grpc-out/grpc.so ]; then \
        mv /tmp/grpc-out/grpc.so "$(php -r 'echo ini_get("extension_dir");')/grpc.so"; \
        docker-php-ext-enable grpc; \
    fi; \
    rm -rf /tmp/grpc-out

COPY --chmod=755 laravel-php/scripts/nvm-use.sh /usr/local/bin/nvm-use
