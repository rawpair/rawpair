# RawPair™

[![Status: Pre-alpha](https://img.shields.io/badge/status-pre--alpha-orange)]()
[![License: MPL-2.0](https://img.shields.io/github/license/rawpair/rawpair)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/rawpair/rawpair?style=social)](https://github.com/rawpair/rawpair/stargazers)

**RawPair™** is a self-hosted, real-time collaborative development environment.
It provides persistent project workspaces with a shared terminal and collaborative code editor for pair or mob programming.

Native Linux workspaces run through Orqos using systemd, dedicated Unix accounts, cgroup limits and per-workspace network namespaces. Use [prebuilt Ubuntu packages](docs/PACKAGES.md), [native source setup](docs/NATIVE_SETUP.md) or the separate [Docker setup](docs/CONTAINER_SETUP.md). The [delivery handoff](docs/HANDOFF.md) records implementation details, checks and limitations; [goal.txt](goal.txt) remains the canonical scope.

Built for fast, focused collaboration on your own infrastructure, RawPair also supports use cases like remote development, penetration testing, and red teaming, as long as it's done ethically and with proper authorization.

---

![image](https://github.com/user-attachments/assets/f4c790d9-6db7-47ec-9778-39687755ea93)

---

https://github.com/user-attachments/assets/fdbabd96-1bdf-4269-a408-7b6c11948443

---

## Features

- Password login, workspace membership and multiple persistent projects per user
- File-scoped collaborative editing and persistent shared tmux terminals in the browser
- Native Linux workspaces through Orqos, with independent loopback ports and resource limits
- Named HTTPS application previews with WebSocket support and private or deliberate public access
- Retained Docker workspace backend as a separate deployment option
- Licensed under MPL v2.0

---

## Tech Stack

RawPair is built on a modern, production-grade foundation:

- [Phoenix](https://github.com/phoenixframework/phoenix) ([Elixir](https://github.com/elixir-lang/elixir)) - handles real-time collaboration and session management
- [Monaco](https://github.com/microsoft/monaco-editor) + [Yjs](https://github.com/yjs/yjs) - collaborative code editing in the browser
- [ttyd](https://github.com/tsl0922/ttyd) + [tmux](https://github.com/tmux/tmux) - shared terminal sessions
- [Orqos](https://github.com/orqos-project/orqos) + Linux systemd/cgroups/network namespaces - native workspace execution
- [Docker](https://github.com/docker) - optional container workspace backend
- [Nginx](https://github.com/nginx/nginx) - reverse proxy and traffic routing for ttyd
- [PostgreSQL](https://github.com/postgres/postgres) - workspace metadata persistence
- [Vector](https://github.com/vectordotdev/vector) + [Loki](https://github.com/grafana/loki) + [Grafana](https://github.com/grafana/grafana) - observability for logs and metrics
- [Portainer CE](https://github.com/portainer/portainer) - (optional) convenient docker management

---

## Supported Tech Stacks

See [rawpair/stacks](https://github.com/rawpair/stacks) for all supported dev environments.

---

## Setup

Use [PACKAGES.md](docs/PACKAGES.md) for prebuilt Ubuntu 24.04 installation, interactive/unattended setup, diagnostics and upgrades without build toolchains. Use [NATIVE_SETUP.md](docs/NATIVE_SETUP.md) to build from source on a normal Linux systemd host. It includes prerequisites, Orqos installation, workspace-account provisioning, PostgreSQL, Phoenix, collaboration, ttyd/tmux, nginx, local hostname/TLS trust, first login and operating instructions. Native mode needs no Docker, Kubernetes, image downloads or stack catalog. Host language tools are operator-installed or user-local.

Use [CONTAINER_SETUP.md](docs/CONTAINER_SETUP.md) and `compose.container.example.yml` for the retained Docker backend, including authenticated terminals and collaboration. Existing stack images still provide container toolchains. This recipe replaces the old generic Yjs and unauthenticated proxy setup. The CLI quickStart/ensureDeps commands, Ansible recipes and older compose files remain legacy container helpers; they do not install the current native services or secure gateway configuration.

Accounts are operator-created. Workspace owners add collaborators and control application visibility. The intended initial deployment is one Linux host for trusted collaborators. See [HANDOFF.md](docs/HANDOFF.md) for build/test evidence and live paths still unverified.

---

## Environment Variables

The setup guides contain the complete current service configuration. Native examples are in [native/rawpair.env.example](native/rawpair.env.example); Docker uses the root `.env` described in its setup guide. The historical variable reference below also includes options used only by legacy container helpers.

### Core Configuration

| Variable                  | Description                                                                                                                                      | Default           |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------- |
| `RAWPAIR_STACKS_VERSION`  | Version of `stacks.json` to load from the [`rawpair/stacks`](https://github.com/rawpair/stacks) repository. Must match a Git tag or branch.      | `0.1.8`           |
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
