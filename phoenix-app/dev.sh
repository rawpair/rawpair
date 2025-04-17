#!/usr/bin/env bash

# SPDX-License-Identifier: MPL-2.0

set -e

ENV_FILE="${1:-.env}"

if [ ! -f "$ENV_FILE" ]; then
  echo "$ENV_FILE not found. Please create one or specify the correct path."
  exit 1
fi

echo "Loading environment from $ENV_FILE"
set -a
source "$ENV_FILE"
set +a

echo "Starting RawPair (on $RAWPAIR_HOST)"
mix phx.server
