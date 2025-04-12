# SPDX-License-Identifier: MPL-2.0
#!/bin/bash
set -e

NEW_VER="$1"
SUPERVISORCTL="supervisorctl -c /etc/supervisor/conf.d/rawpair.conf"

if [[ ! "$NEW_VER" =~ ^8\.[0-3]$ ]]; then
    echo "Usage: switch-phpfpm <8.0|8.1|8.2|8.3>"
    exit 1
fi

echo "[*] Switching PHP-FPM to $NEW_VER..."

# Stop all PHP-FPMs
for ver in 8.0 8.1 8.2 8.3; do
    echo "[*] Stopping php$ver-fpm..."
    $SUPERVISORCTL stop php$ver-fpm || true
done

# Start selected version
echo "[*] Starting php${NEW_VER}-fpm..."
$SUPERVISORCTL start php${NEW_VER}-fpm

# Re-render nginx config
TEMPLATE=/etc/nginx/sites-available/template.conf
TARGET=/etc/nginx/sites-enabled/default.conf

echo "[*] Rendering Nginx config for PHP $NEW_VER..."
env PHP_VERSION=$NEW_VER envsubst '$PHP_VERSION' < "$TEMPLATE" > "$TARGET"


# Reload Nginx
echo "[*] Reloading Nginx..."
nginx -s reload

echo "[✓] PHP-FPM switched to $NEW_VER and Nginx reloaded."
