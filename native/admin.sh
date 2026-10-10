#!/usr/bin/env bash
set -euo pipefail
if [[ $EUID != 0 ]]; then echo 'Run as root; this reads /etc/rawpair/rawpair.env.' >&2; exit 1; fi
set -a
source /etc/rawpair/rawpair.env
set +a
case ${1:-} in
  migrate) exec runuser -u rawpair -- /opt/rawpair/bin/rawpair eval 'Rawpair.Release.migrate()' ;;
  create-user)
    read -r -p 'Username: ' RAWPAIR_USERNAME
    read -r -s -p 'Password (12+ bytes): ' RAWPAIR_PASSWORD
    printf '\n'
    export RAWPAIR_USERNAME RAWPAIR_PASSWORD
    exec runuser -u rawpair -- /opt/rawpair/bin/rawpair eval 'Rawpair.Release.create_user()'
    ;;
  adopt-legacy)
    read -r -p 'Existing username to own legacy workspaces: ' RAWPAIR_USERNAME
    export RAWPAIR_USERNAME
    exec runuser -u rawpair -- /opt/rawpair/bin/rawpair eval 'Rawpair.Release.adopt_legacy()'
    ;;
  *) echo 'Usage: sudo native/admin.sh migrate|create-user|adopt-legacy' >&2; exit 1 ;;
esac
