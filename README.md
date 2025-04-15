# RawPair

[![Status: Pre-alpha](https://img.shields.io/badge/status-pre--alpha-orange)]()
[![License: MPL-2.0](https://img.shields.io/github/license/rawpair/rawpair)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/rawpair/rawpair?style=social)](https://github.com/beyond-tabs/rawpair/stargazers)

**RawPair** is a self-hosted, real-time collaborative development environment.
It enables you to spin up isolated containers with a shared terminal and code editor for effective pair (or mob) programming.

Built for fast, focused collaboration on your own infrastructure, RawPair also supports use cases like remote development, penetration testing, and red teaming, as long as it's done ethically and with proper authorization.

**Join the Discord**: [discord.gg/muGYzJg3Aj](https://discord.gg/muGYzJg3Aj)

---

![image](https://github.com/user-attachments/assets/f4c790d9-6db7-47ec-9778-39687755ea93)


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

| Stack                                                    | Docker Repository                                                                     | Notes                                          |
|----------------------------------------------------------|---------------------------------------------------------------------------------------|------------------------------------------------|
| **[Ada](https://www.gnu.org/software/gnat/)**            | [rawpair/ada](https://hub.docker.com/repository/docker/rawpair/ada)                   | Includes GNU GNAT                              |
| **[Clojure](https://clojure.org/)**                      | [rawpair/clojure](https://hub.docker.com/repository/docker/rawpair/clojure)           | Runs on Temurin (OpenJDK)                      |
| **[COBOL](https://gnucobol.sourceforge.io/)**            | [rawpair/gnucobol](https://hub.docker.com/repository/docker/rawpair/gnucobol)         | Includes GNU COBOL                             |
| **[Elixir](https://elixir-lang.org/)**                   | [rawpair/elixir](https://hub.docker.com/repository/docker/rawpair/elixir)             |                                                |
| **[Haskell](https://www.haskell.org/)**                  | [rawpair/haskell](https://hub.docker.com/repository/docker/rawpair/haskell)           | Includes GHC                                   |
| **[Julia](https://julialang.org/)**                      | [rawpair/julia](https://hub.docker.com/repository/docker/rawpair/julia)               |                                                |
| **[.NET](https://dotnet.microsoft.com/)**                | [rawpair/gnucobol](https://hub.docker.com/repository/docker/rawpair/dotnet)           | Includes C#, F#, VB.NET, Mono                  |
| **[Node.js](https://nodejs.org/)**                       | [rawpair/node](https://hub.docker.com/repository/docker/rawpair/node)                 | Managed via NVM                                |
| **[OCaml](https://ocaml.org/)**                          | [rawpair/ocaml](https://hub.docker.com/repository/docker/rawpair/ocaml)               | Includes OPAM, OCaml 4.14.1, Dune, Menhir      |
| **[PHP](https://www.php.net/)**                          | [rawpair-php](https://hub.docker.com/repository/docker/rawpair/php)                   | Includes FPM/CLI; PHP 8.0–8.3                  |
| **[Python](https://www.python.org/)**                    | [rawpair/python](https://hub.docker.com/repository/docker/rawpair/python)             | 2 base images available: Trixie; NVIDIA CUDA   |
| **[Ruby](https://www.ruby-lang.org/en/)**                | [rawpair/ruby](https://hub.docker.com/repository/docker/rawpair/ruby)                 |                                                |
| **[Rust](https://www.rust-lang.org/)**                   | [rawpair/rust](https://hub.docker.com/repository/docker/rawpair/rust)                 |                                                |
| **[Smalltalk](https://www.gnu.org/software/smalltalk/)** | [rawpair/gnusmalltalk](https://hub.docker.com/repository/docker/rawpair/gnusmalltalk) | Includes GNU Smalltalk                         |
| **[Steel Bank Common Lisp](https://www.sbcl.org/)**      | [rawpair/sbcl](https://hub.docker.com/repository/docker/rawpair/sbcl)                 | Includes SBCL and Quicklisp                    |

Can't see your favourite stack? Submit a PR or create an issue.

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

In case you haven't yet installed Erlang and Elixir.

```bash
asdf plugin add erlang
asdf install erlang 27.3.2
asdf set -u erlang 27.3.2

asdf plugin add elixir
asdf install elixir 1.18.3
asdf set -u elixir 1.18.3
```

## An important note on Docker images

RawPair provides Docker images to make development environments easier to spin up and work with—especially for collaborative or short-lived sessions. These images prioritize convenience over minimalism: they include a full toolchain, reasonable defaults, and everything needed to get started without extra setup. They're not security-hardened or optimized for production use, and that's by design.

To work properly with RawPair, containers **must** include the following packages:

- `bash` - for shell consistency
- `tmux` - to manage terminal sessions
- `supervisor` - to coordinate background services
- `vector` - to stream logs to the host
- `ttyd` - to expose the terminal over HTTP

These are essential for enabling terminal access, log streaming, and reliable session orchestration. You're welcome to customize the images, but omitting these components will likely break core functionality. In short: build your own, but build smart.

Additionally, three configuration files are required for proper orchestration: `supervisord.conf`, `ttyd-wrapper.sh`, and `vector.toml`. These are provided in the `docker/` folder of the repository and should be copied into your image during the build process. They set up the necessary services and log routing for the container to behave as expected inside the RawPair environment.

You're welcome to customize the images, but omitting these components will likely break core functionality. In short: build your own, but build smart.

### A note on named volumes

Any files saved in `/home/devuser/app` will persist in the associated named volume. Everything else will be discarded when the container stops.

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

## Architecture Overview

- **Phoenix** handles session logic, orchestration, and WebSocket communication
- **Docker** is used to manage isolated workspace containers
- **ttyd** provides web-based terminal access
- **Monaco + Yjs** power the collaborative code editor
- **Nginx** handles access to ttyd
- **Volumes** allow optional persistent or disposable file systems

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
