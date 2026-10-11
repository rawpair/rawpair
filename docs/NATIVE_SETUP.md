# Native RawPair source setup

For installation without build toolchains, use [prebuilt Ubuntu packages](PACKAGES.md). The source path below uses the same installed setup/provisioning helpers with separate source ownership. Older manual installations require the explicit migration described in PACKAGES.md.

This is the native Linux path for RawPair and Orqos. It uses no Docker daemon, Kubernetes, stack images, or container startup/shutdown scripts. The existing container instructions remain in [DEPLOYMENT.md](../DEPLOYMENT.md). Native operations and the control contract are in [Orqos HOST_API.md](../../orqos/docs/HOST_API.md).

## Host prerequisites

Use a normal systemd Linux host, initially Ubuntu 24.04, with cgroup v2, Linux 5.6+ (`openat2`), a nonconflicting private IPv4 /16, and administrative access for installation. The native files API supports x86_64 and aarch64 Linux. Workspace homes live under `/srv/rawpair`, outside `/home`. Accounts are dedicated to workspaces: do not grant them sudo, shared groups, host SSH login, or control-plane secrets. The provisioner sets a locked password, nologin shell and expired account date, preventing SSH sessions and forwarding outside Orqos. Orqos validates these restrictions; systemd launches `/bin/bash` explicitly without PAM login.

Install OS services and build prerequisites:

```sh
sudo apt update
sudo apt install -y build-essential pkg-config libssl-dev git curl unzip python3 \
  postgresql postgresql-client nginx iproute2 nftables tmux ttyd nodejs npm \
  mkcert libnss3-tools
sudo systemctl enable --now postgresql nginx
```

Install Erlang/OTP 27 and Elixir 1.18 using your normal package source or version manager, and Rust stable with Cargo. The locked Phoenix dependencies require at least Elixir 1.16; Ubuntu 24.04's stock Elixir package is older, so use your existing asdf/mise installation or a suitable Elixir package source. Node 18+ is sufficient for collaboration; Node 20+ is a suitable operator choice. Verify `erl -version`, `elixir --version`, `mix --version`, `node --version`, and `cargo --version` before building. The delivery checks used OTP 27, Elixir 1.18.3, Node 24.21.0, Rust 1.99.0, and PostgreSQL 18; PostgreSQL 16 is the Ubuntu recipe's database. Confirm `ttyd --help` includes `--writable`, `--base-path`, and Unix socket support. No automatic workspace-language installer is included.

## Build and install Orqos

Assuming sibling checkouts `~/dev/{rawpair,orqos}`:

```sh
cd ~/dev/orqos
cargo build --release --locked
sudo packaging/install-host.sh
sudo packaging/provision-workspace.sh project-a
sudo packaging/provision-workspace.sh project-b
sudoedit /etc/orqos/host.json
sudo systemctl enable --now orqos-host
sudo journalctl -u orqos-host -n 50 --no-pager
```

The provisioner adds inventory mappings for those two accounts to their home/project directories, distinct network indexes, and ceilings of 2 CPU cores, 2048 MiB RAM, and 512 tasks. Choose a different `subnet` before starting if `10.231.0.0/16` conflicts with LAN/VPN routes. Workspace `index` values allocate distinct /30s within that /16. DNS must use public IPv4 resolvers reachable through your router. The installer enables `net.ipv4.ip_forward=1` through its own sysctl file. Existing firewall tables/default policies are preserved. If another firewall drops forwarded packets, allow outbound traffic and established replies for the configured workspace range in that firewall; inspect `nft list ruleset`, never flush existing tables. Private LAN dependencies and IPv6 egress are not supported in this MVP.

The daemon listens on loopback port 9080 and requires the random bearer secret in `/etc/orqos/host.env` for every host-control or forwarding request. Its root-owned helper accepts only the documented action vocabulary and operator inventory. Never publish this control port. The installer preserves existing inventory and secrets. It does not start workspace runtimes.

## Local hostnames and TLS

The default local deployment is `https://rawpair.localhost`, with application URLs such as `https://a-<id>.apps.rawpair.localhost`. Current Chromium and Firefox resolve `.localhost` names to browser-local loopback; use a browser on the deployment host for this setup. No purchased domain or router change is needed.

Generate and trust a local certificate as your ordinary browser user:

```sh
mkcert -install
mkcert -cert-file /tmp/rawpair-local.pem -key-file /tmp/rawpair-local-key.pem \
  rawpair.localhost '*.apps.rawpair.localhost'
```

If your resolver/browser does not resolve nested `.localhost` names, add the management hostname and each displayed preview hostname to `/etc/hosts` with `127.0.0.1`, or configure a local wildcard resolver for `apps.rawpair.localhost`. Command-line clients can use `curl --resolve rawpair.localhost:443:127.0.0.1 https://rawpair.localhost/`.

For collaborators on another machine, use hostnames resolving to the server's LAN/public IP, for example `pair.example.test` and wildcard `*.apps.example.test`. Generate a certificate for both names and trust its CA on each client. Pass those names to `native/install.sh`; ensure the management origin is separate from every application origin. For public internet use, configure ordinary DNS plus inbound TCP 443 and a publicly trusted certificate (wildcard DNS validation or certificates covering the application names), or use an optional HTTPS tunnel that forwards both hostnames and WebSocket upgrades. No special router feature is required. A local mkcert CA is for your trusted local browsers, not public visitors.

## Build and install RawPair

```sh
cd ~/dev/rawpair
native/build.sh
sudo native/install.sh
# Follow the wizard, or pass a protected JSON config as the sole argument.
sudo rawpair user add
sudo rawpair doctor
```

The account command prompts for username and password without echoing the password. Passwords need 12..1024 UTF-8 bytes. Accounts are operator-created; there is no open registration. Give each collaborator an individual account. Owners grant workspace membership through the UI.

The source installer installs Phoenix in `/opt/rawpair`, collaboration in `/opt/rawpair-collaboration`, and shared setup helpers under `/usr/lib/rawpair`. It installs a source administration wrapper as `/usr/local/bin/rawpair`; the prebuilt package uses the Go CLI as `/usr/bin/rawpair`. Both invoke the same setup helper. Units are installed in `/usr/lib/systemd/system`. Persistent state and protected configuration remain outside the payloads.

The wizard configures PostgreSQL, secrets, nginx, certificates, the first login and both default account slots, runs migrations and starts validated services. Select local mode to use mkcert as the invoking browser user, or remote mode to reference existing certificate paths. JSON input, TLS renewal, upgrade backups, recovery and diagnostics are described in [PACKAGES.md](PACKAGES.md). The earlier `native/install.sh CERT KEY [HOST PREVIEW]` interface has been replaced with `native/install.sh [PROTECTED_JSON]`.

## First projects and collaboration

1. Open `https://rawpair.localhost`, log in, and choose **New project workspace**. Select an unused provisioned account slot. Blank CPU/memory fields use inventory defaults; explicit limits cannot exceed operator ceilings. A reused slot retains its project/home files. Create one workspace for each project.
2. Open a workspace's management page and press **Start / reconnect**. Open its editor and terminal. Both participants join the same tmux session, Unix identity, project files and limits. Start also retries an incomplete initial registration. A stopped workspace keeps all files.
3. In the terminal, work normally, for example `git clone <url> .`, `npm install`, `npm run dev -- --host 127.0.0.1 --port 3000`, `cargo build`, or `mix deps.get`. Keep credentials/caches in the workspace home. Add tmux windows with `Ctrl-b c`; background workers and additional apps share that workspace's cgroup limits.
4. The file selector lists project files. Use **Save** to write the selected shared document to disk. Shared edits are also persisted by the collaboration service; switching files or reconnecting does not seed over an existing shared document. Use the terminal to create directories/files and handle binaries, then refresh the file list.
5. Add the second account under **Workspace members**, selecting `member` or `owner`. Members can edit, use terminals, start/stop, and open private apps. Owners also configure limits, manage membership, publish apps, delete project contents and remove registrations. The last owner cannot be removed.
6. Register an application, for example `web` on port 3000. Its HTTPS URL is distinct from the other project's URL even if both servers use localhost:3000. **Check connection** reports a real upstream HTTP response or failure. Frameworks that validate Host headers may need their displayed preview hostname added to allowed hosts; configure WebSocket/HMR external URLs if that framework requires it.
7. A private preview redirects through management login and exchanges a single-use grant for an application-scoped, secure, HttpOnly, host-only cookie. Management session credentials are never forwarded to app code. App-owned cookies and Authorization headers still work. Only an owner can deliberately **Share publicly**. Public sharing exposes that application route; workspace access remains private.

When an existing collaborative document has unsaved edits, it remains authoritative in the editor until Save. Changes made to the same file independently from Git or terminal tools are not automatically merged into an already persisted shared document. Use **Reload from disk** after a Git checkout or terminal edit to replace that file’s shared editor contents, with explicit confirmation that this discards unsaved edits for every participant. Automatic reconciliation of external file changes is remaining polish.

## Development databases

Install a database toolchain on the host as operator (for example `sudo apt install postgresql-16`). In each workspace's terminal, use its own data and socket directory, not the control-plane PostgreSQL database:

```sh
mkdir -p "$HOME/.data/postgres" "$HOME/.data/pgsocket"
/usr/lib/postgresql/16/bin/initdb -D "$HOME/.data/postgres"
/usr/lib/postgresql/16/bin/pg_ctl -D "$HOME/.data/postgres" \
  -l "$HOME/.data/postgres.log" \
  -o "-h 127.0.0.1 -p 5432 -k $HOME/.data/pgsocket" start
```

Each workspace may use port 5432 because loopback is separate. Use `pg_ctl -D "$HOME/.data/postgres" stop` for an orderly database stop before stopping the workspace when practical. Database processes and workers stop with the workspace, while the data directory remains. This is development data, not managed production database hosting.

## Logs, restart, upgrade and cleanup

```sh
sudo journalctl -u rawpair-host -u rawpair-collaboration -u orqos-host -f
sudo systemctl restart rawpair-host rawpair-collaboration orqos-host
```

Workspace unit names and service errors appear in Orqos observations (`GET /host/workspaces/<runtime-id>`) and control logs. Use `journalctl -u <owned-unit>` to inspect ttyd, supervisor and application startup output. App stdout remains in tmux unless the user redirects it. Browser disconnect and control-service restarts leave healthy workspace services running. Restarting collaboration preserves the server's Yjs snapshots. A host reboot leaves transient workspace services stopped; press Start to restore a workspace from its persistent registration/files.

Use the UI/API Stop for each runtime before shutting down the entire deployment. `systemctl stop rawpair-host rawpair-collaboration orqos-host` stops control services and deliberately leaves independently managed workspaces running. Remove Workspace first stops that runtime and releases registration/membership/application routes while preserving its account/home/project files. Delete Project Contents is a separate, exact-ID confirmation while stopped; it preserves the home and project root and invalidates collaboration documents. Orqos removes only resources whose persisted ownership matches. Never use unit-name-prefix deletion or flush a shared firewall to clean up.

For source upgrades, rebuild both repositories, reinstall their source assets, run `sudo rawpair migrate` and `sudo rawpair setup`. For package upgrades, use the coordinated bootstrap flow in [PACKAGES.md](PACKAGES.md). Keep `/etc/{rawpair,orqos}`, `/var/lib/orqos/host`, PostgreSQL, workspace homes, and `/var/lib/rawpair-collaboration` in backups; the latter contains unsaved collaborative document copies. Do not remove inventory accounts or change their user/home/project/index mappings while registrations exist. After removal, an operator may archive/delete the preserved home and remove the account. Uninstalling services/files is an explicit operator operation; installers do not destroy data.

Expired login/preview credentials can be pruned in PostgreSQL with `DELETE FROM user_sessions WHERE expires_at < now(); DELETE FROM preview_credentials WHERE expires_at < now();`. Logout immediately revokes the originating login and dependent private-preview/collaboration checks. Established proxy WebSockets are authorized at handshake; visibility/membership changes apply on their next connection. Yjs connections additionally recheck authorization every 15 seconds. Stop a workspace to terminate its existing terminal/application connections immediately.

The collaboration reset endpoint is local and service-authenticated: `DELETE http://127.0.0.1:1234/internal/workspaces/<database-id>/documents`, with `Authorization: Bearer <RAWPAIR_COLLABORATION_TOKEN>`. Close affected editors first. It clears that workspace's collaborative snapshots so the next editor connection initializes from project files. Project-file deletion/removal invokes this cleanup automatically. If collaboration was unavailable during deletion, stale snapshots remain inaccessible through the incremented document generation and may be purged when service access recovers.

## Scope and available checks

This is a trusted-collaborator MVP on one Linux host, not hardened isolation for arbitrary untrusted tenants. There is no automatic language/database provisioning, production app supervision, generic TCP/UDP publication, IPv6 workspace egress, enterprise SSO, or Rezn integration. Workspace resource ceilings are enforced; file sizes/number, synchronous collaboration snapshots, and basic file selection are deliberate initial limits. Only HTTP development applications are registered internally; browser ingress is HTTPS and WebSocket-capable. See [HANDOFF.md](HANDOFF.md) for exact checks run and live paths still unverified.
