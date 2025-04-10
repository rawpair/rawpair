# rawpair

**rawpair** is a self-hosted, real-time collaborative development environment.  
It enables you to spin up isolated containers with a shared terminal and code editor for effective pair (or mob) programming.

Just fast, focused collaboration on your own infrastructure.

---

## Features

- Shared terminal sessions with [ttyd](https://github.com/tsl0922/ttyd) and `tmux`
- Collaborative code editing using Monaco and Yjs
- One container per session, isolated from others
- No signup required, no tracking
- Licensed under GPL-3.0

---

## Set up

In case you haven't yet installed Erlang and Elixir.

```bash
asdf plugin add elixir
asdf install elixir 27.3.2
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

Set the required ENV variables, such as:

```bash
DATABASE_URL=postgres://postgres:postgres@db/rawpair_dev
SECRET_KEY_BASE=SV/7XaCy1K3ZxDqgRZluV0IfgHaSmD5oC1mVCH5vEd2ZWFmJERcSwadMOfvl1o5H
CHECK_ORIGIN=//localhost:4000
```

Then run:

```bash
git clone https://github.com/rawpair/rawpair
cd rawpair
docker compose up -d
cd phoenix-app
./deploy.sh
./start.sh
```

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

## Architecture Overview

- **Phoenix** handles session logic, orchestration, and WebSocket communication
- **Docker** is used to manage isolated workspace containers
- **ttyd** provides web-based terminal access
- **Monaco + Yjs** power the collaborative code editor
- **Nginx** handles access to ttyd
- **Volumes** allow optional persistent or disposable file systems

---

## Security Considerations

rawpair provides real-time terminal and editor access to others via containers. Please use responsibly.

> - **Do not expose the service to the public internet without authentication**  
> - **Do not allow unknown users into active sessions**  
> - **Ensure Docker is secured on your host system**

---

## License

This project is licensed under the **GNU GPL v3.0**.  
If you modify or distribute it, the source code must remain available under the same license.

See [`LICENSE`](LICENSE) for details.

---

## Contributing

Contributions are welcome. Please open issues and submit pull requests through GitHub.


`docker build -f gnucobol/trixie/Dockerfile -t gnucobol:trixie .`