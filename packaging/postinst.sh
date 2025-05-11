#!/bin/bash
set -e
ENV_FILE="/etc/rawpair/rawpair.env"
DEFAULT_ENV_FILE="/etc/rawpair/rawpair.env.default"
SERVICE_NAME="rawpair.service"
RAWPAIR_USER="rawpair"
RAWPAIR_GROUP="rawpair"

if ! id -u "$RAWPAIR_USER" >/dev/null 2>&1; then
  useradd --system --no-create-home --shell /usr/sbin/nologin "$RAWPAIR_USER"
fi

mkdir -p /etc/rawpair
chown "$RAWPAIR_USER:$RAWPAIR_GROUP" /etc/rawpair

echo "Installing default environment template at $DEFAULT_ENV_FILE"
chown "$RAWPAIR_USER:$RAWPAIR_GROUP" "$DEFAULT_ENV_FILE"
chmod 644 "$DEFAULT_ENV_FILE"

if [ ! -f "$ENV_FILE" ]; then
  echo "Generating initial environment config at $ENV_FILE"
  cp "$DEFAULT_ENV_FILE" "$ENV_FILE"

  arch=$(uname -m)
  case "$arch" in
    x86_64) docker_platform="linux/amd64" ;;
    aarch64) docker_platform="linux/arm64" ;;
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
  esac

  sed -i "s|^SECRET_KEY_BASE=.*|SECRET_KEY_BASE=$(openssl rand -hex 64)|" "$ENV_FILE"
  sed -i "s|^RAWPAIR_DOCKER_PLATFORM=.*|RAWPAIR_DOCKER_PLATFORM=$docker_platform|" "$ENV_FILE"
  chown "$RAWPAIR_USER:$RAWPAIR_GROUP" "$ENV_FILE"
  chmod 640 "$ENV_FILE"
else
  echo "Environment file already exists, preserving values"
  NEW_KEYS=$(grep -E '^[A-Z0-9_]+=' "$DEFAULT_ENV_FILE" | cut -d= -f1)
  for key in $NEW_KEYS; do
    if ! grep -q "^$key=" "$ENV_FILE"; then
      echo "WARNING: Missing key '$key' in your rawpair.env"
    fi
  done
fi

mkdir -p /opt/rawpair/tmp
chown rawpair:rawpair /opt/rawpair/tmp

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"
