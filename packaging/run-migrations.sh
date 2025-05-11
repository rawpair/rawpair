#!/bin/bash
[ -z "$DATABASE_URL" ] && { echo "Missing DATABASE_URL"; exit 1; }

exec /opt/rawpair/bin/rawpair eval "Rawpair.Release.migrate"
