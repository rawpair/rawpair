#!/bin/sh
set -eu
# Configuration, identities, databases, project homes and ownership survive purge.
if [ -d /run/systemd/system ]; then systemctl daemon-reload; fi
