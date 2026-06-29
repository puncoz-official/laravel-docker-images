#!/bin/sh
# Container entrypoint — runs Laravel optimizations at start so they pick up
# runtime env (DB host, queue driver, app URL, etc.) instead of build-time env.
set -e

if [ "${APP_ENV:-production}" = "production" ]; then
    php artisan storage:link --quiet || true
    php artisan optimize
fi

exec "$@"
