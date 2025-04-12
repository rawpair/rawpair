# SPDX-License-Identifier: MPL-2.0
#!/bin/bash
set -e

echo "[startup-check] Ensuring PHP-FPM is active..."

if [ ! -S "/home/devuser/run/php$PHP_VERSION-fpm.sock" ]; then
  echo "[startup-check] PHP-FPM socket not found. Running switch-phpfpm $PHP_VERSION..."
  switch-phpfpm "$PHP_VERSION"
else
  echo "[startup-check] FPM socket already exists. No action taken."
fi
