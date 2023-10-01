FROM php:8.1-fpm

LABEL maintainer="Puncoz Nepal"

ARG NODE_VERSION=18

ENV DEBIAN_FRONTEND noninteractive
ENV TZ=UTC

# Set Timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update && apt-get install -y \
        supervisor unzip \
        libgmp-dev \
        autoconf zlib1g-dev \
        libpq-dev libzip-dev \
        libfreetype6-dev libjpeg62-turbo-dev libpng-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure exif --enable-exif\
    && docker-php-ext-install -j$(nproc) gmp pdo pdo_mysql pdo_pgsql pgsql zip pcntl bcmath gd exif \
    && MAKEFLAGS="-j $(nproc)" pecl install grpc \
    && MAKEFLAGS="-j $(nproc)" pecl install redis \
    && strip --strip-debug /usr/local/lib/php/extensions/*/grpc.so \
    && strip --strip-debug /usr/local/lib/php/extensions/*/redis.so \
    && docker-php-ext-enable grpc redis \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && curl -sLS https://deb.nodesource.com/setup_$NODE_VERSION.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm \
    && npm install -g yarn \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

