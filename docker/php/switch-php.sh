#!/bin/bash
# SPDX-License-Identifier: MPL-2.0

set -e

PHP_VERSION=$1

if [[ ! "$PHP_VERSION" =~ ^8\.[0-3]$ ]]; then
    echo "Usage: switch-php <8.0|8.1|8.2|8.3>"
    exit 1
fi

BIN_PATH=$(command -v php$PHP_VERSION)

if [[ -z "$BIN_PATH" ]]; then
    echo "php$PHP_VERSION not found. Is it installed?"
    exit 2
fi

# Use user-owned path for symlink
mkdir -p "$HOME/bin"
ln -sf "$BIN_PATH" "$HOME/bin/php"
hash -r # clear bash cache
echo "[✓] Switched CLI to php$PHP_VERSION"
php -v
