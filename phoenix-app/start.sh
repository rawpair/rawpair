#!/usr/bin/env bash
set -euo pipefail
if [[ -f .env ]]; then set -a; source .env; set +a; fi
for name in DATABASE_URL SECRET_KEY_BASE CHECK_ORIGIN RAWPAIR_GATEWAY_TOKEN RAWPAIR_COLLABORATION_TOKEN; do
  if [[ -z ${!name:-} ]]; then printf '%s must be set.\n' "$name" >&2; exit 1; fi
done
release=bin/rawpair
if [[ ! -x $release ]]; then release=_build/prod/rel/rawpair/bin/rawpair; fi
"$release" eval 'Rawpair.Release.migrate()'
exec "$release" start
