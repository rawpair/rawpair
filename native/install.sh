#!/usr/bin/env bash
# Source installations use the same setup helper as the prebuilt packages.
set -euo pipefail
if [[ $EUID != 0 || $# -gt 1 ]]; then
  echo 'Usage: sudo native/install.sh [PROTECTED_SETUP_JSON]' >&2; exit 1
fi
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
if [[ -f /var/lib/rawpair/package-owner ]]; then
  echo 'Package installation detected. Use sudo rawpair setup.' >&2; exit 1
fi
if [[ ! -f /var/lib/rawpair/source-owner ]]; then
  for path in /opt/rawpair /etc/rawpair/rawpair.env /etc/systemd/system/rawpair-host.service /usr/local/bin/rawpair; do
    if [[ -e $path || -L $path ]]; then echo "Existing installation at $path; see docs/PACKAGES.md migration instructions." >&2; exit 1; fi
  done
  for account in rawpair rawpair-collab; do
    if getent passwd "$account" >/dev/null || getent group "$account" >/dev/null; then
      echo "Existing $account identity; see docs/PACKAGES.md migration instructions." >&2; exit 1
    fi
  done
fi
if [[ ! -x phoenix-app/_build/prod/rel/rawpair/bin/rawpair || ! -d yjs-server/node_modules ]]; then
  echo 'Run native/build.sh first.' >&2; exit 1
fi
install -d -o root -g root -m 0755 /opt/rawpair /opt/rawpair-collaboration /etc/rawpair /usr/lib/rawpair /var/lib/rawpair
printf '%s\n' rawpair-native-v1 > /var/lib/rawpair/source-owner
for account in rawpair rawpair-collab; do
  if ! getent passwd "$account" >/dev/null; then
    if getent group "$account" >/dev/null; then
      useradd --system --gid "$account" --home-dir "/var/lib/$account" --shell /usr/sbin/nologin "$account"
    else
      useradd --system --user-group --home-dir "/var/lib/$account" --shell /usr/sbin/nologin "$account"
    fi
  fi
done
install -d -o rawpair -g rawpair -m 0700 /var/lib/rawpair/tmp
install -d -o rawpair-collab -g rawpair-collab -m 0700 /var/lib/rawpair-collaboration
install -m 0600 /dev/null /var/lib/rawpair/setup-required
for unit in rawpair-host rawpair-collaboration; do
  if systemctl cat "$unit" >/dev/null 2>&1; then systemctl stop "$unit"; fi
done
cp -a phoenix-app/_build/prod/rel/rawpair/. /opt/rawpair/
python3 -c 'from pathlib import Path; Path("/opt/rawpair/releases/COOKIE").unlink(missing_ok=True)'
cp -a yjs-server/server.mjs yjs-server/package.json yjs-server/package-lock.json yjs-server/node_modules /opt/rawpair-collaboration/
chown -R root:root /opt/rawpair /opt/rawpair-collaboration
install -o root -g root -m 0644 native/setup.py native/configure.py native/nginx.conf.template packaging/compatibility.json /usr/lib/rawpair/
awk '{print $2}' phoenix-app/_build/prod/rel/rawpair/releases/start_erl.data > /usr/lib/rawpair/version
install -o root -g root -m 0644 native/rawpair-host.service native/rawpair-collaboration.service /usr/lib/systemd/system/
printf '%s\n' '#!/bin/sh' 'exec /usr/bin/python3 /usr/lib/rawpair/setup.py "$@"' > /usr/local/bin/rawpair
chmod 0755 /usr/local/bin/rawpair
systemctl daemon-reload
arguments=(setup)
if [[ $# == 1 ]]; then arguments+=(--config "$1"); fi
exec /usr/bin/python3 /usr/lib/rawpair/setup.py "${arguments[@]}"
