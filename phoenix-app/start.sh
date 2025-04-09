#!/bin/sh
set -e

# Wait until Postgres is ready
echo "Waiting for DB..."
until pg_isready -h db -U postgres; do
  sleep 1
done

# Run migrations
echo "Running migrations..."
bin/rawpair eval "Rawpair.Release.migrate"

# Start app
echo "Starting app..."
exec bin/rawpair start
