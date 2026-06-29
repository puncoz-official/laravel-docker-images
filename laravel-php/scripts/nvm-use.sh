#!/usr/bin/env bash
# nvm-use [version]
#
# Install (if missing) and activate a Node version via nvm, then symlink the
# active node/npm/npx/yarn/pnpm binaries into /usr/local/bin so they're picked
# up by non-bash shells (sh, php-fpm, supervisor, etc).
#
# Usage:
#   nvm-use 22         # explicit version
#   nvm-use            # reads .nvmrc from the current working directory
#
# Must be run as root (writes symlinks under /usr/local/bin).
set -euo pipefail

if [ -z "${NVM_DIR:-}" ] || [ ! -s "${NVM_DIR}/nvm.sh" ]; then
    echo "nvm-use: NVM_DIR not set or nvm not installed" >&2
    exit 1
fi
# shellcheck source=/dev/null
. "${NVM_DIR}/nvm.sh"

if [ "$#" -ge 1 ]; then
    nvm install "$1"
elif [ -f .nvmrc ]; then
    nvm install
else
    echo "nvm-use: provide a version or run from a directory with .nvmrc" >&2
    exit 1
fi

current="$(nvm current)"
nvm alias default "$current" >/dev/null

# corepack ships yarn/pnpm shims with Node ≥16.10. Enabling it lets the symlink
# loop below pick them up.
corepack enable >/dev/null 2>&1 || true

node_bin="${NVM_DIR}/versions/node/${current}/bin"
for b in node npm npx corepack yarn yarnpkg pnpm pnpx; do
    if [ -e "${node_bin}/${b}" ]; then
        ln -sf "${node_bin}/${b}" "/usr/local/bin/${b}"
    fi
done

echo "nvm-use: active Node = $(node --version)"
