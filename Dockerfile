FROM php:7.4-fpm-alpine

RUN set -xe; \
    apk add --update --no-cache ca-certificates tzdata; \
    \
    apk add --update --no-cache -t .php-rundeps \
        bzip2 \
        c-client \
        freetype \
        icu-libs \
        imagemagick \
        jpegoptim \
        libbz2 \
        libjpeg-turbo \
        libjpeg-turbo-utils \
        libltdl \
        libpng \
        libzip-dev \
        libxslt; \
    \
    apk add --update --no-cache -t .build-deps \
        autoconf \
        cmake \
        build-base \
        bzip2-dev \
        freetype-dev \
        icu-dev \
        imagemagick-dev \
        jpeg-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libtool \
        libxslt-dev \
        openssl-dev \
        postgresql-dev \
        pcre-dev; \
    \
    apk add -U -X http://dl-cdn.alpinelinux.org/alpine/edge/testing/ --allow-untrusted gnu-libiconv; \
    \
    docker-php-source extract; \
    \
    NPROC=$(getconf _NPROCESSORS_ONLN); \
    docker-php-ext-install -j${NPROC} \
        bcmath \
        bz2 \
        calendar \
        exif \
        ftp \
        intl \
        opcache \
        pcntl \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        soap \
        sockets \
        xmlrpc \
        xsl \
        zip; \
    \
    : "GD"; \
    docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg; \
    \
    docker-php-ext-install -j${NPROC} gd; \
    \
    : "PECL extensions"; \
    pecl config-set php_ini "${PHP_INI_DIR}/php.ini"; \
    pecl channel-update pecl.php.net; \
    pecl install \
        imagick \
        "redis-5.3.1" \
        "xdebug-2.9.8"; \
    docker-php-ext-enable \
        imagick \
        redis; \
    : "Cleanup"; \
    docker-php-source delete; \
    apk del --purge .build-deps; \
    pecl clear-cache; \
    \
    rm -rf \
        /usr/include/php \
        /usr/lib/php/build \
        /usr/lib/mysqld* \
        /tmp/* \
        /var/cache/apk/*; \
    rm -rf /usr/src/php.tar.xz; \
    \
    : "Report"; \
    php -v; \
    php -i;
