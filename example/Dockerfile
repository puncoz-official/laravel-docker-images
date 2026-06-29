# Example Dockerfile for a Laravel project consuming puncoz/laravel-php base images.
#
# Layout assumed (copy this Dockerfile + docker/ + .nvmrc into your Laravel repo root):
#   Dockerfile
#   .dockerignore
#   .nvmrc                # Node version (read by `nvm-use`)
#   docker/
#     php/{php.ini, opcache.ini, opcache-jit.ini}
#     php-fpm/www.conf
#     entrypoint.sh
#
# Node version: the base image ships Node 24 as the default. If your project
# needs a different version, either commit a `.nvmrc` (recommended — keeps the
# version pinned next to your code) or replace `RUN nvm-use` below with an
# explicit `RUN nvm-use 20`. If 22 is fine, drop the `nvm-use` lines entirely.
#
# Build:
#   docker build --build-arg PHP_VERSION=8.2 -t my-laravel-app .

ARG PHP_VERSION=8.2

# -------- Stage 1: PHP dependencies --------
FROM puncoz/laravel-php:${PHP_VERSION} AS vendor

WORKDIR /app

COPY composer.json composer.lock ./
RUN composer install \
        --no-dev \
        --no-interaction \
        --no-progress \
        --no-scripts \
        --no-autoloader \
        --prefer-dist

# -------- Stage 2: frontend assets --------
FROM puncoz/laravel-php:${PHP_VERSION} AS assets

WORKDIR /app

# Pin Node from .nvmrc — installs that version into nvm and re-links binaries.
COPY .nvmrc ./
RUN nvm-use

COPY package.json package-lock.json* ./
COPY vite.config.* postcss.config.* tailwind.config.* ./
RUN npm ci --no-audit --no-fund

COPY resources/ resources/
COPY public/ public/
RUN npm run build

# -------- Stage 3: final runtime --------
FROM puncoz/laravel-php:${PHP_VERSION} AS app

WORKDIR /var/www/html

# Match the build-time Node to the runtime image too — only needed if the
# container itself runs `npm`/`node` at runtime (e.g. SSR, queue workers that
# shell out to node scripts). Drop these two lines for pure PHP-FPM workloads.
COPY .nvmrc ./
RUN nvm-use

# Production PHP / FPM config — load order matters (10-, 11-, zz-).
COPY docker/php/opcache.ini       /usr/local/etc/php/conf.d/10-opcache.ini
COPY docker/php/opcache-jit.ini   /usr/local/etc/php/conf.d/11-opcache-jit.ini
COPY docker/php/php.ini           /usr/local/etc/php/conf.d/zz-app.ini
COPY docker/php-fpm/www.conf      /usr/local/etc/php-fpm.d/zz-app.conf

# App source + built artifacts
COPY --chown=www-data:www-data . .
COPY --from=vendor --chown=www-data:www-data /app/vendor       ./vendor
COPY --from=assets --chown=www-data:www-data /app/public/build ./public/build

RUN composer dump-autoload --classmap-authoritative --no-dev \
    && php artisan package:discover --ansi \
    && mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

COPY --chmod=755 docker/entrypoint.sh /usr/local/bin/docker-entrypoint

USER www-data

EXPOSE 9000

ENTRYPOINT ["docker-entrypoint"]
CMD ["php-fpm", "--nodaemonize"]
