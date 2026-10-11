#!/bin/sh
set -eu
case "${1:-}" in
  remove|deconfigure|upgrade)
    if [ -d /run/systemd/system ]; then
      systemctl stop rawpair-host.service rawpair-collaboration.service
    fi
    ;;
esac
if [ "${1:-}" = remove ] && [ -d /run/systemd/system ]; then
  systemctl disable rawpair-host.service rawpair-collaboration.service || true
fi
