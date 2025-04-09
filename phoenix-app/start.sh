#!/bin/sh
set -e

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

# Run migrations
echo "Running migrations..."
_build/prod/rel/rawpair/bin/rawpair eval "Rawpair.Release.migrate"

# Start app
echo "Starting app..."
MIX_ENV=prod PHX_SERVER=true exec _build/prod/rel/rawpair/bin/rawpair start
