
asdf install elixir latest
asdf set -u erlang latest

asdf install elixir 1.18.3
asdf set -u elixir 1.18.3

mix assets.deploy
mix phx.server

First time: create `priv/static/assets` if it doesn't already exist.

---

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

---

docker run --name rawpair_db \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=rawpair_dev \
  -p 5432:5432 \
  -d postgres:15

docker network create rawpair_net

HOST=localhost PORT=1234 npx y-websocket
HOST=0.0.0.0 PORT=1234 npx y-websocket


docker run aquasec/trivy fs --scanners vuln,secret,misconfig .