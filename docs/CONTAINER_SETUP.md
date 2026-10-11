# Container backend option

For native workspaces, start with [package installation](PACKAGES.md) or [source setup](NATIVE_SETUP.md). Docker workspaces remain a separate backend; Orqos's Docker and Kubernetes APIs also remain unchanged. This recipe supersedes the older development compose snippets in README/DEPLOYMENT now that RawPair requires real login, membership and an authenticated collaboration gateway.

1. Install Docker Engine and Compose, plus Elixir/Mix only if building a release outside the supplied Dockerfile. Obtain a TLS certificate and key for your management hostname. For a local browser on the deployment host, install mkcert and generate/trust the local certificate as your ordinary browser user:

```sh
mkcert -install
mkdir -p ./local-tls
mkcert -cert-file ./local-tls/cert.pem -key-file ./local-tls/key.pem rawpair.localhost
```

Set `RAWPAIR_TLS_DIR` below to the absolute path of that directory. This local hostname points at the browser's own machine. Remote collaborators need a management hostname resolving to the server, a matching trusted certificate and reachable HTTPS.
2. Create `.env` in the repository root (it is gitignored):

```dotenv
PHX_HOST=rawpair.localhost
DB_PASSWORD=REPLACE_WITH_RANDOM_HEX_SECRET
SECRET_KEY_BASE=REPLACE_WITH_64_RANDOM_BYTES_BASE64
RAWPAIR_GATEWAY_TOKEN=REPLACE_WITH_RANDOM_HEX_SECRET
RAWPAIR_COLLABORATION_TOKEN=REPLACE_WITH_RANDOM_HEX_SECRET
RAWPAIR_TLS_DIR=/absolute/path/to/cert-directory
DOCKER_GID=REPLACE_WITH_HOST_DOCKER_SOCKET_GROUP_ID
```

Generate hex secrets with `openssl rand -hex 32`, the base secret with `openssl rand -base64 64 | tr -d '\n'`, and obtain the socket GID with `stat -c '%g' /var/run/docker.sock`. The certificate directory must contain `cert.pem` and `key.pem`. Keep `.env` and the key private.

3. Start the separate container deployment:

```sh
docker compose -f compose.container.example.yml up -d --build
```

The supplied compose starts PostgreSQL, Phoenix, the authenticated Yjs service, and TLS nginx on a network named `rawpair`. It does not expose Phoenix, Yjs or PostgreSQL ports directly. Phoenix runs under an unprivileged container UID with the explicitly supplied Docker socket group. Docker socket access remains powerful and this option is for trusted operators/collaborators. Native mode gives Phoenix no Docker access.

4. Create each operator-managed login without putting its password in shell history:

```sh
read -r -p 'Username: ' RAWPAIR_USERNAME
read -r -s -p 'Password (12+ bytes): ' RAWPAIR_PASSWORD
printf '\n'
export RAWPAIR_USERNAME RAWPAIR_PASSWORD
docker compose -f compose.container.example.yml exec \
  --env RAWPAIR_USERNAME --env RAWPAIR_PASSWORD rawpair \
  bin/rawpair eval 'Rawpair.Release.create_user()'
unset RAWPAIR_USERNAME RAWPAIR_PASSWORD
```

Open `https://rawpair.localhost`. Create Docker workspaces with a compatible image from the [existing stacks catalog](https://github.com/rawpair/stacks), pulling that image on the host first if necessary (`docker pull <image>`). Project volumes retain their contents across runtime removal. Terminal ingress is checked against workspace membership and resolves only the registered container; there is no arbitrary container-name proxy. Collaborative documents use the same authenticated, file-scoped service as native mode. Stop/remove lifecycle uses the retained Docker backend. Named application previews are provided by the native backend in this MVP; the old unrestricted fixed-port application proxy has been removed.

For an existing database, assign previously ownerless workspace records to an operator-created account with `RawPair.Workspaces.adopt_legacy_workspaces("username")`, run through the release's `eval` with a Repo started (see `Rawpair.Release.adopt_legacy()`, which reads `RAWPAIR_USERNAME`). Previously issued chosen-username browser sessions do not authenticate.

Use `docker compose -f compose.container.example.yml logs -f` for control logs. Stopping the control compose does not stop independent workspace containers. Stop each workspace through its UI/API first if that is your intent. Keep Docker named project/database volumes and collaboration data in backups; container-image, catalog, GPU/device and language provisioning remain the existing container operator's responsibility. Do not use the Docker startup/shutdown scripts for native host mode.
