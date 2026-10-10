#!/usr/bin/env bash
set -euo pipefail
if [[ $EUID != 0 || $# -lt 2 ]]; then
  echo 'Usage: sudo native/install.sh CERT_PEM KEY_PEM [MANAGEMENT_HOST] [PREVIEW_DOMAIN]' >&2; exit 1
fi
cert=$(realpath -- "$1")
key=$(realpath -- "$2")
management_host=${3:-rawpair.localhost}
preview_domain=${4:-apps.rawpair.localhost}
if [[ ! $management_host =~ ^[a-z0-9][a-z0-9.-]+$ || ! $preview_domain =~ ^[a-z0-9][a-z0-9.-]+$ || $management_host == "$preview_domain" ]]; then
  echo 'Use distinct, valid management and preview hostnames.' >&2; exit 1
fi
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
if [[ ! -x phoenix-app/_build/prod/rel/rawpair/bin/rawpair || ! -d yjs-server/node_modules ]]; then
  echo 'Run native/build.sh first.' >&2; exit 1
fi
if [[ ! -f /etc/orqos/host.env ]]; then echo 'Install Orqos native host mode first.' >&2; exit 1; fi
for account in rawpair rawpair-collab; do
  if ! getent passwd "$account" >/dev/null; then
    useradd --system --user-group --home-dir "/var/lib/$account" --shell /usr/sbin/nologin "$account"
  fi
done
install -d -o root -g root -m 0755 /opt/rawpair /opt/rawpair-collaboration /etc/rawpair
install -d -o root -g root -m 0700 /etc/rawpair/tls
install -d -o rawpair -g rawpair -m 0700 /var/lib/rawpair
install -d -o rawpair-collab -g rawpair-collab -m 0700 /var/lib/rawpair-collaboration
cp -a phoenix-app/_build/prod/rel/rawpair/. /opt/rawpair/
cp -a yjs-server/server.mjs yjs-server/package.json yjs-server/package-lock.json yjs-server/node_modules /opt/rawpair-collaboration/
chown -R root:root /opt/rawpair /opt/rawpair-collaboration
install -o root -g root -m 0644 "$cert" /etc/rawpair/tls/cert.pem
install -o root -g root -m 0600 "$key" /etc/rawpair/tls/key.pem
python3 native/configure.py "$management_host" "$preview_domain"
install -o root -g root -m 0644 native/rawpair-host.service native/rawpair-collaboration.service /etc/systemd/system/
systemctl daemon-reload
nginx -t
printf '%s\n' 'Installed. Run migrations and create accounts as described in docs/NATIVE_SETUP.md, then:' \
  '  systemctl enable --now rawpair-host rawpair-collaboration' \
  '  systemctl reload nginx'
