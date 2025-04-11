# RawPair

**RawPair** is a self-hosted, real-time collaborative development environment.
It enables you to spin up isolated containers with a shared terminal and code editor for effective pair (or mob) programming.

Built for fast, focused collaboration on your own infrastructure, RawPair also supports use cases like remote development, penetration testing, and red teaming, as long as it's done ethically and with proper authorization.

---

![image](https://github.com/user-attachments/assets/4952788a-4520-4d4f-b17d-dc44a28d9924)

---

## Features

- Collaborative code editing and shared terminal session in the browser
- One container per session, fully isolated from others
- Licensed under MPL v2.0

---

## Tech Stack

Rawpair is built on a modern, production-grade foundation:

- [Phoenix](https://github.com/phoenixframework/phoenix) ([Elixir](https://github.com/elixir-lang/elixir)) – handles real-time collaboration and session management
- [Monaco](https://github.com/microsoft/monaco-editor) + [Yjs](https://github.com/yjs/yjs) – collaborative code editing in the browser
- [ttyd](https://github.com/tsl0922/ttyd) + [tmux](https://github.com/tmux/tmux) – shared terminal sessions
- [docker](https://github.com/docker) – isolated containers per user session
- [Nginx](https://github.com/nginx/nginx) – reverse proxy and traffic routing for ttyd
- [PostgreSQL](https://github.com/postgres/postgres) – workspace metadata persistence
- [Vector](https://github.com/vectordotdev/vector) + [Loki](https://github.com/grafana/loki) + [Grafana](https://github.com/grafana/grafana) – observability for logs and metrics

---

## System Requirements

To run Rawpair smoothly in a self-hosted environment, you’ll need:

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
mix phx.server
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

Refer to [./DEPLOYMENT.md](deployment instructions/guidelines)

**Important**: You should generate your own `SECRET_KEY_BASE`

```bash
mix phx.gen.secret
```

Then open [http://localhost:4000](http://localhost:4000) to begin.

In production you may want to run this behind a reverse proxy

---

## How do I scroll the terminal?

This terminal runs in your browser and doesn't support mouse scrollback.
To scroll, press:

`Ctrl-b` followed by `[`

You can now use the mouse wheel or the arrow keys. Press `q` to exit scroll mode.

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
