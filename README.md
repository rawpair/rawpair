# RawPair™

[![Status: Pre-alpha](https://img.shields.io/badge/status-pre--alpha-orange)]()
[![License: MPL-2.0](https://img.shields.io/github/license/rawpair/rawpair)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/rawpair/rawpair?style=social)](https://github.com/beyond-tabs/rawpair/stargazers)

**RawPair™** is a self-hosted, real-time collaborative development environment.
It enables you to spin up isolated containers with a shared terminal and code editor for effective pair (or mob) programming.

Built for fast, focused collaboration on your own infrastructure, RawPair also supports use cases like remote development, penetration testing, and red teaming, as long as it's done ethically and with proper authorization.

**Join the Discord**: [discord.gg/muGYzJg3Aj](https://discord.gg/muGYzJg3Aj)

---

![image](https://github.com/user-attachments/assets/f4c790d9-6db7-47ec-9778-39687755ea93)

---

https://github.com/user-attachments/assets/fdbabd96-1bdf-4269-a408-7b6c11948443

---

## Features

- Collaborative code editing and shared terminal session in the browser
- One container per session, fully isolated from others
- Licensed under MPL v2.0

---

## Tech Stack

RawPair is built on a modern, production-grade foundation:

- [Phoenix](https://github.com/phoenixframework/phoenix) ([Elixir](https://github.com/elixir-lang/elixir)) - handles real-time collaboration and session management
- [Monaco](https://github.com/microsoft/monaco-editor) + [Yjs](https://github.com/yjs/yjs) - collaborative code editing in the browser
- [ttyd](https://github.com/tsl0922/ttyd) + [tmux](https://github.com/tmux/tmux) - shared terminal sessions
- [docker](https://github.com/docker) - isolated containers per user session
- [Nginx](https://github.com/nginx/nginx) - reverse proxy and traffic routing for ttyd
- [PostgreSQL](https://github.com/postgres/postgres) - workspace metadata persistence
- [Vector](https://github.com/vectordotdev/vector) + [Loki](https://github.com/grafana/loki) + [Grafana](https://github.com/grafana/grafana) - observability for logs and metrics
- [Portainer CE](https://github.com/portainer/portainer) - (optional) convenient docker management

---

## Supported Tech Stacks

See [rawpair/stacks](https://github.com/rawpair/stacks) for all supported dev environments.

---

## System Requirements

To run RawPair smoothly in a self-hosted environment, you'll need:

- 64-bit Linux host (Debian/Ubuntu recommended), works also on a Raspberry Pi
- Docker (version 20.10+)
- Docker Compose (v2+)
- At least 2 CPU cores and 4 GB RAM (8 GB recommended for multiple sessions)
- Persistent storage for PostgreSQL and logs
- Optional (but recommended): Domain + TLS for secure public access (via Nginx or a reverse proxy)

---

## Set up

### Install Erlang and Elixir

#### Verify/install dependencies

##### Ubuntu / Debian

```bash
sudo apt update
sudo apt install -y autoconf build-essential libncurses-dev libssl-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils libncurses5-dev openjdk-17-jdk curl git
```

#### Install asdf

Follow the official instructions: https://asdf-vm.com/guide/getting-started.html

#### Proceed with the installation of Erlang and Elixir

```bash
asdf plugin add erlang
asdf install erlang 27.3.2
asdf set -u erlang 27.3.2

asdf plugin add elixir
asdf install elixir 1.18.3
asdf set -u elixir 1.18.3
```

### A note on named volumes in containers

Any files saved in `/home/devuser/app` will persist in the associated named volume. Everything else will be discarded when the container stops.

### Using the Docker images

The majority of the Docker images are available on https://hub.docker.com/u/rawpair

You need to run `docker pull` commands appropriately.

## Quick Start (Development)

```bash
git clone https://github.com/rawpair/rawpair
cd rawpair
docker compose up -d
cd phoenix-app
mix deps.get
cd assets
npm i
cd ..
mkdir -p priv/static/assets
./dev.sh
```

Then open [http://localhost:4000](http://localhost:4000) to begin.

### CLI Setup (Optional)

A prebuilt CLI tool is available in [Releases](https://github.com/rawpair/rawpair/releases).
Either install via `curl -sSf https://rawpair.dev/install.sh | sh` or download the binary matching your platform manually.

Then run to ensure that you have Erlang and Elixir installed:

```bash
./rawpair ensureDeps
```

Or add flags for unsupervised installation of dependencies:

```bash
./rawpair ensureDeps --non-interactive --install-deps
```

**Note: --install-deps requires root**

Run this command, follow the instructions and at the end of the process you will have the opportunity to generate .env and .docker-compose.yml files.

```bash
./rawpair quickStart
```


This should get you up and running with minimal effort.

Use this if you don’t want to manually edit config files.

**Tested on Ubuntu 24.04, Debian Bookwork, Fedora 42, Archlinux (20250430)**

## Quick Start (Production)

Set the required ENV variables, based on `phoenix-app/.env.example`.

Then run:

```bash
git clone https://github.com/rawpair/rawpair
cd rawpair
docker compose up -d
cd phoenix-app
./deploy.sh
./start.sh
```

Refer to [deployment instructions/guidelines](./DEPLOYMENT.md) and [Ansible playbooks](./ansible/README.md)

**Important**: You should generate your own `SECRET_KEY_BASE`

```bash
mix phx.gen.secret
```

Then open [http://localhost:4000](http://localhost:4000) to begin.

It is advisable to use a reverse proxy in production.

---


## Environment Variables

RawPair is configured via the following environment variables. These should be defined in a `.env` file or passed directly into your runtime environment (e.g. Docker, systemd, or a `mix phx.server` session).

### Core Configuration

| Variable                  | Description                                                                                                                                      | Default           |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------- |
| `RAWPAIR_STACKS_VERSION`  | Version of `stacks.json` to load from the [`rawpair/stacks`](https://github.com/rawpair/stacks) repository. Must match a Git tag or branch.      | `0.1.4`           |
| `RAWPAIR_DOCKER_PLATFORM` | Target Docker platform (e.g. `linux/amd64`, `linux/arm64`). If unset, RawPair will detect the local platform using `uname -m` and log a warning. | *(auto-detected)* |

---

### Database

| Variable       | Description                 | Example                                              |
| -------------- | --------------------------- | ---------------------------------------------------- |
| `DATABASE_URL` | Postgres connection string. | `postgres://postgres:postgres@localhost/rawpair_dev` |

---

### Secrets & Security

| Variable          | Description                                                            | Example                          |
| ----------------- | ---------------------------------------------------------------------- | -------------------------------- |
| `SECRET_KEY_BASE` | Phoenix secret key for session encryption.                             | *(random 64-byte base64 string)* |
| `CHECK_ORIGIN`    | Allowed CORS origins, comma-separated. Required for LiveView security. | `//localhost:4000`   |

---

### Application Host

| Variable                | Description                                                                                | Example     |
| ----------------------- | ------------------------------------------------------------------------------------------ | ----------- |
| `PHX_HOST`              | Public hostname used by Phoenix.                                                           | `localhost` |
| `PORT`                  | Port Phoenix listens on.                                                                   | `4000`      |
| `RAWPAIR_PROTOCOL`      | RawPair protocol (used for internal URL generation).                                       | `http`      |
| `RAWPAIR_HOST`          | RawPair hostname (used internally).                                                        | `localhost` |
| `RAWPAIR_PORT`          | RawPair application port.                                                                  | `4000`      |
| `RAWPAIR_BASE_PATH`     | Root path prefix for RawPair (e.g. `/rawpair`). Useful if reverse-proxied under a subpath. | `/`         |
| `RAWPAIR_TERMINAL_HOST` | Hostname of the terminal backend (e.g. `ttyd`).                                            | `localhost` |
| `RAWPAIR_TERMINAL_PORT` | Port of the terminal backend.                                                              | `8080`      |

---

### Grafana

| Variable                | Description                                                  | Example     |
| ----------------------- | ------------------------------------------------------------ | ----------- |
| `RAWPAIR_GRAFANA_HOST`  | Hostname of Grafana (used for embedding metrics dashboards). | `localhost` |
| `RAWPAIR_GRAFANA_PORT`  | Port of Grafana.                                             | `3000`      |

---


## How to scroll the terminal?

ttyd terminals run in the browser and don't support mouse scrollback.
To scroll, press:

`Ctrl-b` followed by `[`

It is now possible to use the mouse wheel or the arrow keys. Press `q` to exit scroll mode.

---

## Security considerations

### Mounting /var/run/docker.sock

RawPair does **not** require Docker socket access by default. However, the current Phoenix backend uses System.cmd/3 to invoke Docker directly via the CLI. For this to work, the process must have permission to run docker commands, typically by having access to the Docker daemon—either directly on the host or via a mounted socket.

If you mount `/var/run/docker.sock` into the container running Phoenix (e.g., for local development), you're granting that container **full control over the host's Docker daemon**. This effectively means **root access to the host**. It's powerful, convenient, and generally unsafe in shared or exposed environments.

For safer setups, consider using [docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy), a minimal Go-based HTTP proxy that lets you expose only specific Docker API endpoints to containers. This allows for fine-grained access control, so you can limit what the Phoenix backend is allowed to do.

Use socket access only if you understand the risks, and only in environments where trust boundaries are clear.

---

## Security Considerations

RawPair provides real-time terminal and editor access to others via containers. Please use responsibly.

> - **Do not expose the service to the public internet without authentication**  
> - **Do not allow unknown users into active sessions**  
> - **Ensure Docker is secured on your host system**

---

## License

This project is licensed under the **Mozilla Public License 2.0 (MPL-2.0)**.
If you modify any source files covered by this license, you must make those files available under the same license, but you may combine them with proprietary code in separate files.

See [`LICENSE`](LICENSE) for details.

The RawPair™ name and logo are trademarks of Andrea Mancuso.  
See [TRADEMARK.md](./TRADEMARK.md) for details.

---

## Legal and Ethical Use

RawPair is intended strictly for **authorized, collaborative development** and **educational** purposes.  
Any use of this software to perform unauthorized access, surveillance, or exploitation of remote systems is **forbidden** and may violate applicable laws.

You are solely responsible for how you use this software.

By using RawPair, you agree to comply with all relevant laws and to use the software **only in environments where you have explicit permission**.

This project is licensed under the [Mozilla Public License 2.0](https://www.mozilla.org/MPL/2.0/), which ensures that **any modifications to MPL-licensed files must remain open-source**, while still allowing broader integration with proprietary systems.

---

## Contributing

Contributions are welcome. Please open issues and submit pull requests through GitHub.

## Acknowledgments

RawPair is made possible thanks to the following open-source libraries:

| Library                                                    | Version           | Description                                         |
|------------------------------------------------------------|-------------------|-----------------------------------------------------|
| https://github.com/phoenixframework/phoenix                | ~> 1.7.21         | Core framework for building interactive web apps   |
| https://github.com/phoenixframework/phoenix_ecto           | ~> 4.5            | Integration between Phoenix and Ecto               |
| https://github.com/elixir-ecto/ecto_sql                    | ~> 3.10           | SQL-based persistence layer                        |
| https://github.com/elixir-ecto/postgrex                    | >= 0.0.0          | PostgreSQL driver for Elixir                       |
| https://github.com/phoenixframework/phoenix_html           | ~> 4.1            | HTML helpers for Phoenix                           |
| https://github.com/phoenixframework/phoenix_live_reload    | ~> 1.2 (dev)      | Live reload support during development             |
| https://github.com/phoenixframework/phoenix_live_view      | ~> 1.0            | Real-time UI with server-rendered DOM diffs        |
| https://github.com/philss/floki                            | >= 0.30.0 (test)  | HTML parser used for testing                       |
| https://github.com/phoenixframework/phoenix_live_dashboard | ~> 0.8.3          | Real-time monitoring dashboard                     |
| https://github.com/evanw/esbuild                           | ~> 0.8 (dev)      | JavaScript bundler                                 |
| https://github.com/tailwindlabs/tailwindcss                | ~> 0.3 (dev)      | Utility-first CSS framework                        |
| https://github.com/tailwindlabs/heroicons                  | v2.1.1            | SVG icons from Tailwind Labs                       |
| https://github.com/swoosh/swoosh                           | ~> 1.5            | Email composition and delivery                     |
| https://github.com/sneako/finch                            | ~> 0.13           | HTTP client for Elixir                             |
| https://github.com/beam-telemetry/telemetry_metrics        | ~> 1.0            | Metrics reporter for Telemetry                     |
| https://github.com/beam-telemetry/telemetry_poller         | ~> 1.0            | Periodic Telemetry measurements                    |
| https://github.com/elixir-gettext/gettext                  | ~> 0.26           | Internationalization (i18n) support                |
| https://github.com/michalmuskala/jason                     | ~> 1.2            | JSON parser and encoder                            |
| https://github.com/phoenixframework/dns_cluster            | ~> 0.1.1          | DNS-based clustering                               |
| https://github.com/mtrudel/bandit                          | ~> 1.5            | HTTP server compatible with Plug and Phoenix       |
| https://github.com/jayjun/slugify                          | ~> 1.3            | Slug generator for URLs and file names             |
| https://github.com/akasprzok/memo_tar                      | ~> 0.1.0          | In-memory tar archive generation                   |
