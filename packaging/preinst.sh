#!/bin/sh
set -eu
if [ ! -f /var/lib/rawpair/package-owner ]; then
  for path in /usr/bin/rawpair /usr/bin/rawpair-cli /var/lib/rawpair /opt/rawpair /opt/rawpair-cli /opt/rawpair-collaboration /etc/rawpair/rawpair.env /etc/systemd/system/rawpair.service /etc/systemd/system/rawpair-host.service /usr/lib/systemd/system/rawpair.service /usr/local/bin/rawpair /usr/local/bin/rawpair-cli; do
    if [ -e "$path" ] || [ -L "$path" ]; then
      echo "Existing RawPair installation at $path. Back up and migrate explicitly; see docs/PACKAGES.md (legacy migration)." >&2
      exit 1
    fi
  done
  for account in rawpair rawpair-collab; do
    if getent passwd "$account" >/dev/null || getent group "$account" >/dev/null; then
      echo "Existing $account account/group is not package-owned; see docs/PACKAGES.md." >&2
      exit 1
    fi
  done
fi
# Every upgrade is finalized by setup, never by a maintainer-script migration.
if [ -d /run/systemd/system ]; then
  for unit in rawpair-host.service rawpair-collaboration.service; do
    if systemctl cat "$unit" >/dev/null 2>&1; then systemctl stop "$unit"; fi
  done
fi
