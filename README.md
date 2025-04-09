# rawpair

**rawpair** is a self-hosted, real-time collaborative development environment.  
It enables you to spin up isolated containers with a shared terminal and code editor for effective pair programming.

No cloud IDEs. No Docker-in-Docker.  
Just fast, focused collaboration on your own infrastructure.

---

## Features

- Shared terminal sessions with [ttyd](https://github.com/tsl0922/ttyd) and `tmux`
- Collaborative code editing using Monaco and Yjs
- One container per session, isolated from others
- No signup required, no tracking
- Licensed under GPL-3.0

---

## Quick Start (Development)

```bash
git clone https://github.com/rawpair/rawpair
cd rawpair
docker compose -f docker-compose.yml -f docker-compose.dev.yml up
```

Then open [http://localhost:4000](http://localhost:4000) to begin.

## Quick Start (Production)

Set the required ENV variables, such as:

```bash
DATABASE_URL=postgres://postgres:postgres@db/rawpair_dev
SECRET_KEY_BASE=SV/7XaCy1K3ZxDqgRZluV0IfgHaSmD5oC1mVCH5vEd2ZWFmJERcSwadMOfvl1o5H
CHECK_ORIGIN=//localhost,//localhost:4000,//192.168.0.213
```

```bash
git clone https://github.com/rawpair/rawpair
cd rawpair
docker compose up
```

Then open [http://<host>:4000](http://<host>:4000) to begin.

In production you may want to run this behind a reverse proxy

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

