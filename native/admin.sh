#!/usr/bin/env bash
set -euo pipefail
case ${1:-} in
  migrate) exec /usr/bin/python3 /usr/lib/rawpair/setup.py migrate ;;
  create-user) exec /usr/bin/python3 /usr/lib/rawpair/setup.py user add ;;
  *) echo 'Use sudo rawpair migrate or sudo rawpair user add.' >&2; exit 1 ;;
esac
