#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../phoenix-app"
export MIX_ENV=prod
export RAWPAIR_BACKENDS=host
mix deps.get
(cd assets && npm ci)
mix assets.deploy
mix release --overwrite
cd ../yjs-server
npm ci --omit=dev
printf '%s\n' 'Built Phoenix release and collaboration service. See docs/NATIVE_SETUP.md for installation.'
