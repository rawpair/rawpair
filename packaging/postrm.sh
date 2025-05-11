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

rm -fr /opt/rawpair/tmp

if [ "$1" = "purge" ]; then
  echo "--- Starting purge actions ---"

  echo "Removing $ENV_FILE (if it exists)..."
  [ -f "$ENV_FILE" ] && rm -f "$ENV_FILE"
  echo "Removed $ENV_FILE (or it didn't exist)."

  echo "Removing $DEFAULT_ENV_FILE (if it exists)..."
  [ -f "$DEFAULT_ENV_FILE" ] && rm -f "$DEFAULT_ENV_FILE"
  echo "Removed $DEFAULT_ENV_FILE (or it didn't exist)."

  echo "Attempting to remove directory $CONFIG_DIR..."
  if [ -d "$CONFIG_DIR" ]; then
    rm -rf "$CONFIG_DIR"
  else
    echo "$CONFIG_DIR does not exist."
  fi

  echo "Attempting to remove directory $LOG_DIR..."
  if [ -d "$LOG_DIR" ]; then
    rm -rf "$LOG_DIR"
    if [ "$?" -ne 0 ]; then
      echo "Error removing $LOG_DIR."
    else
      echo "$LOG_DIR removed successfully."
    fi
  else
    echo "$LOG_DIR does not exist."
  fi

  echo "Attempting to remove user $RAWPAIR_USER..."
  if id -u "$RAWPAIR_USER" &>/dev/null; then
    userdel "$RAWPAIR_USER" || true
    echo "User $RAWPAIR_USER deleted."
  else
    echo "User $RAWPAIR_USER does not exist."
  fi

  echo "Attempting to remove group $RAWPAIR_GROUP..."
  if [ getent group "$RAWPAIR_GROUP" &>/dev/null ]; then
    groupdel "$RAWPAIR_GROUP" || true
    echo "Group $RAWPAIR_GROUP removed successfully."
  else
    echo "Group $RAWPAIR_GROUP does not exist."
  fi

  echo "--- Purge actions finished ---"
fi
