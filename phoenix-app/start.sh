#!/bin/bash

# SPDX-License-Identifier: MPL-2.0

set -e

if [ ! -f .env ]; then
  echo ".env file not found. Please create one before running the server."
  exit 1
fi

echo "Loading environment from .env"
export $(grep -v '^#' .env | xargs)

if [ -z "$DATABASE_URL" ]; then
  echo "DATABASE_URL is not set"
  exit 1
fi

if [ -z "$SECRET_KEY_BASE" ]; then
  echo "SECRET_KEY_BASE is not set"
  exit 1
fi

if [ -z "$CHECK_ORIGIN" ]; then
  echo "CHECK_ORIGIN is not set"
  exit 1
fi

if [ -z "$RAWPAIR_PROTOCOL" ]; then
  echo "RAWPAIR_PROTOCOL is not set"
  exit 1
fi

if [ -z "$RAWPAIR_HOST" ]; then
  echo "RAWPAIR_HOST is not set"
  exit 1
fi

if [ -z "$RAWPAIR_PORT" ]; then
  echo "RAWPAIR_PORT is not set"
  exit 1
fi

if [ -z "$PHX_HOST" ]; then
  echo "PHX_HOST is not set"
  exit 1
fi

if [ -z "$PORT" ]; then
  echo "PORT is not set"
  exit 1
fi

if [ -z "$RAWPAIR_TERMINAL_HOST" ]; then
  echo "RAWPAIR_TERMINAL_HOST is not set"
  exit 1
fi

if [ -z "$RAWPAIR_TERMINAL_PORT" ]; then
  echo "RAWPAIR_TERMINAL_PORT is not set"
  exit 1
fi

if [ -z "$RAWPAIR_GRAFANA_HOST" ]; then
  echo "RAWPAIR_TERMINAL_HOST is not set"
  exit 1
fi

if [ -z "$RAWPAIR_GRAFANA_PORT" ]; then
  echo "RAWPAIR_TERMINAL_PORT is not set"
  exit 1
fi

# Run migrations
echo "Running migrations..."
_build/prod/rel/rawpair/bin/rawpair eval "RawPair.Release.migrate"

# Start app
echo "Starting app..."
MIX_ENV=prod PHX_SERVER=true exec _build/prod/rel/rawpair/bin/rawpair start
