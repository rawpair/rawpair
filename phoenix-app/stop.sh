#!/bin/bash
set -e

echo "[rawpair] Stopping Phoenix app..."
_build/prod/rel/rawpair/bin/rawpair stop || true

echo "[rawpair] Stopping managed workspace containers..."
docker ps --filter "label=rawpair.managed=true" --format '{{.ID}}' | xargs -r docker stop

echo "[rawpair] Done."
