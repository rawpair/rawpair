# SPDX-License-Identifier: MPL-2.0

# ---- Build stage ----
FROM elixir:1.18-alpine AS build

ENV MIX_ENV=prod

# Install build dependencies
RUN apk add --no-cache build-base git nodejs npm postgresql-client

WORKDIR /app

# Install Hex and Rebar
RUN mix local.hex --force && mix local.rebar --force

# Copy and install mix deps
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only prod

# Copy rest of the app
COPY . .

# Compile and build assets
RUN MIX_ENV=prod mix compile

RUN MIX_ENV=prod mix assets.deploy

WORKDIR /app

RUN MIX_ENV=prod mix phx.gen.release

RUN MIX_ENV=prod mix release

RUN ls -l /app/_build/prod/rel/rawpair

# ---- Final minimal image ----
FROM alpine:3.19 AS app

ENV MIX_ENV=prod

RUN echo "DATABASE_URL=$DATABASE_URL"

RUN apk add --no-cache libstdc++ openssl ncurses-libs bash postgresql-client docker-cli

WORKDIR /app

# Copy release from build stage
COPY --from=build /app/_build/prod/rel/rawpair ./

ENV PHX_SERVER=true \
    MIX_ENV=prod \
    LANG=en_US.UTF-8

EXPOSE 4000

COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

CMD ["/app/start.sh"]
    