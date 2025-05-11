#!/bin/bash
set -e
RAWPAIR_USER="rawpair"
RAWPAIR_GROUP="rawpair"
ENV_FILE="/etc/rawpair/rawpair.env"
DEFAULT_ENV_FILE="/etc/rawpair/rawpair.env.default"
CONFIG_DIR="/etc/rawpair"
LOG_DIR="/var/log/rawpair"
SERVICE_NAME="rawpair.service"

if [ -f "/lib/systemd/system/$SERVICE_NAME" ]; then
  systemctl stop "$SERVICE_NAME" || true
  systemctl disable "$SERVICE_NAME" || true
  rm -f "/lib/systemd/system/$SERVICE_NAME"
  systemctl daemon-reload
fi


if [ "$1" = "purge" ]; then
  [ -f "$ENV_FILE" ] && rm -f "$ENV_FILE"
  [ -f "$DEFAULT_ENV_FILE" ] && rm -f "$DEFAULT_ENV_FILE"
  if [ -d "$CONFIG_DIR" ]; then
    rmdir "$CONFIG_DIR" 2>/dev/null || true
  fi
  [ -d "$LOG_DIR" ] && rm -rf "$LOG_DIR"

  id "$RAWPAIR_USER" >/dev/null 2>&1 && userdel "$RAWPAIR_USER"
  getent group "$RAWPAIR_GROUP" >/dev/null 2>&1 && groupdel "$RAWPAIR_GROUP"
fi
