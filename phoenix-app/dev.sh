#!/usr/bin/env bash
set -e

if [ ! -f .env ]; then
  echo ".env file not found. Please create one before running the server."
  exit 1
fi

echo "Loading environment from .env"
set -a
source .env
set +a

echo "Starting RawPair (on $RAWPAIR_HOST)"
mix phx.server
