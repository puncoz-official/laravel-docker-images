FROM php:8.1-fpm

LABEL maintainer="Puncoz Nepal <https://github.com/puncoz>"

ARG COMPOSER_VERSION=2.10.1
ARG NVM_VERSION=0.40.5
ARG DEFAULT_NODE_VERSION=24
ARG INSTALL_GRPC=false
# Space-separated list of extra extensions to install via docker-php-ext-install.
# Only works for extensions whose runtime libs are already present in this image
# (e.g. `mysqli`, `calendar`, `sockets`). For extensions needing extra apt deps,
# install them in your own downstream Dockerfile.
ARG PHP_EXTENSIONS=""

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_MEMORY_LIMIT=-1 \
    COMPOSER_HOME=/tmp/composer \
    NVM_DIR=/usr/local/nvm

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl git xz-utils \
        supervisor unzip zip \
        default-mysql-client postgresql-client sqlite3 \
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
        sodium \
        zip; \
    if [ -n "$PHP_EXTENSIONS" ]; then \
        docker-php-ext-install -j"$(nproc)" $PHP_EXTENSIONS; \
    fi; \
    MAKEFLAGS="-j$(nproc)" pecl install redis; \
    docker-php-ext-enable redis; \
    strip --strip-debug /usr/local/lib/php/extensions/*/redis.so; \
    if [ "$INSTALL_GRPC" = "true" ]; then \
        MAKEFLAGS="-j$(nproc)" pecl install grpc; \
        docker-php-ext-enable grpc; \
        strip --strip-debug /usr/local/lib/php/extensions/*/grpc.so; \
    fi; \
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

COPY --chmod=755 laravel-php/scripts/nvm-use.sh /usr/local/bin/nvm-use
