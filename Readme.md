# Docker Images

Lean PHP-FPM base images for Laravel projects. Each PHP version ships in two variants (base + `-grpc`), with **nvm**-managed Node — the image ships Node 24 as the default, and projects switch to any other version with one command.

These images install **binaries and runtimes only** — `php.ini`, OPcache tuning, FPM pool config, `WORKDIR`, and `CMD` are intentionally left to downstream project Dockerfiles, since those vary per project.

## What's included

- PHP-FPM with `bcmath`, `exif`, `gd`, `gmp`, `intl`, `opcache`, `pcntl`, `pdo_mysql`, `pdo_pgsql`, `pdo_sqlite`, `sodium`, `zip`, plus PECL `redis`
- Optional PECL `grpc` (`-grpc` tag variants)
- Optional extra PHP extensions via `PHP_EXTENSIONS` build arg (e.g. `--build-arg PHP_EXTENSIONS="mysqli sockets calendar"`)
- Composer (pinned via `COMPOSER_VERSION`)
- **nvm** + Node 24 (default) at `/usr/local/nvm`; `node`/`npm`/`npx`/`yarn`/`pnpm`/`corepack` symlinked into `/usr/local/bin`
- `nvm-use` helper script — install + activate a different Node version in one line
- DB clients: `default-mysql-client`, `postgresql-client`, `sqlite3`
- Git (with `safe.directory '*'` set for root), Supervisor, `zip`/`unzip`, `xz-utils`, `ca-certificates`

## Tag matrix

| Tag | PHP | gRPC | Notes |
|---|---|---|---|
| `:7.4` / `:7.4-grpc` | 7.4 | no / yes | |
| `:8.1` / `:8.1-grpc` | 8.1 | no / yes | |
| `:8.2` / `:8.2-grpc` | 8.2 | no / yes | |
| `:latest` | 8.2 | no | alias for `:8.2` |

All tags come with Node 24 pre-installed. To use a different Node version inside your project image, see [Switching Node versions](#switching-node-versions) below.

## Setup

Create the multi-platform builder once:

```shell
docker buildx create --use --platform=linux/amd64,linux/arm64 --name multi-platform-builder
docker buildx inspect --bootstrap
```

## Build

All builds are driven by `docker-bake.hcl` at the repo root. A `Makefile` wraps the common commands — run `make help` to see them all.

```shell
make builder         # one-time: create the multi-platform buildx builder
make build           # build all 6 images locally for host arch
make push            # build + push all 6 images, multi-arch
make 8.2             # build 8.2 + 8.2-grpc locally
make push-8.2        # build + push 8.2 + 8.2-grpc, multi-arch
make print           # inspect resolved targets as JSON
make smoke           # quick single-image build to validate setup
```

The bake CLI works directly too:

```shell
docker buildx bake                          # all
docker buildx bake --push                   # all + push
docker buildx bake 'laravel-8-2*' --push    # one PHP version
docker buildx bake laravel-8-2 --push       # one specific tag
docker buildx bake --print                  # dry run
```

### Build args

| Variable | Default | What it controls |
|---|---|---|
| `REGISTRY` | `puncoz` | Image registry |
| `IMAGE_NAME` | `laravel-php` | Repository name |
| `PHP_VERSIONS` | `["7.4", "8.1", "8.2"]` | PHP majors to build |
| `DEFAULT_PHP_VERSION` | `"8.2"` | PHP version that owns `:latest` |
| `COMPOSER_VERSION` | `"2.10.1"` | Pinned Composer release |
| `NVM_VERSION` | `"0.40.5"` | Pinned nvm release |
| `DEFAULT_NODE_VERSION` | `"24"` | Node version pre-installed in the base |
| `PHP_EXTENSIONS` | `""` | Extra extensions to install via `docker-php-ext-install` (space-separated) |
| `PLATFORMS` | `["linux/amd64", "linux/arm64"]` | Target arches |

Override per-invocation, e.g. to downgrade the baked default to Node 20 or to bundle extra extensions:

```shell
DEFAULT_NODE_VERSION=20 docker buildx bake --push
PHP_EXTENSIONS="mysqli sockets calendar" docker buildx bake --push
```

## Switching Node versions

The base image ships with Node 24 active. To use a different version inside your project's Dockerfile:

**Pin via `.nvmrc`** (recommended — keeps the version next to your code):

```dockerfile
FROM puncoz/laravel-php:8.2

COPY .nvmrc ./
RUN nvm-use
```

**Or specify explicitly:**

```dockerfile
RUN nvm-use 20
```

`nvm-use` does three things: `nvm install <version>`, re-aliases it as `default`, and re-links `node`/`npm`/`yarn`/`pnpm` symlinks under `/usr/local/bin` so they're picked up by non-bash shells (sh, php-fpm, supervisor).

If Node 24 (the baked-in default) is fine, you don't need to call `nvm-use` at all — `node`, `npm`, `yarn`, and `pnpm` are already on `PATH`.

## Using the base image in a project

See [`example/`](./example) for a full production-ready setup: multi-stage Dockerfile, `.nvmrc`, tuned `php.ini` / OPcache / FPM config, and an entrypoint that runs `php artisan optimize` at container start. Copy `example/Dockerfile`, `example/.dockerignore`, `example/.nvmrc`, and `example/docker/` into your Laravel project root.

Minimal sketch:

```dockerfile
FROM puncoz/laravel-php:8.2 AS app
WORKDIR /var/www/html

COPY .nvmrc ./
RUN nvm-use

COPY docker/php/opcache.ini  /usr/local/etc/php/conf.d/10-opcache.ini
COPY docker/php/php.ini      /usr/local/etc/php/conf.d/zz-app.ini
COPY docker/php-fpm/www.conf /usr/local/etc/php-fpm.d/zz-app.conf

COPY . .
RUN composer install --no-dev --optimize-autoloader \
    && npm ci && npm run build \
    && php artisan optimize

CMD ["php-fpm", "--nodaemonize"]
```

## Publishing to Docker Hub

```shell
docker login
docker buildx bake --push
```
