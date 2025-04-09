#!/bin/sh
set -e

mix deps.get --only prod

cd assets

npm install

cd ..

mkdir -p ./priv/static/assets

MIX_ENV=prod mix compile

MIX_ENV=prod mix assets.deploy

MIX_ENV=prod mix phx.gen.release

MIX_ENV=prod mix release
