# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :rawpair,
  ecto_repos: [RawPair.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :rawpair, RawPairWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: RawPairWeb.ErrorHTML, json: RawPairWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: RawPair.PubSub,
  live_view: [signing_salt: "VAKpHlZy"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :rawpair, RawPair.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  rawpair: [
    args: ~w(
      js/app.ts
      --bundle
      --target=es2020
      --format=esm
      --outdir=../priv/static/assets
      --external:/fonts/*
      --external:/images/*
      --loader:.ttf=file
      --loader:.css=text
      --loader:.js=jsx
    ),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.9",
  rawpair: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
