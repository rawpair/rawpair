# Native RawPair source setup

For installation without build toolchains, use [prebuilt Ubuntu packages](PACKAGES.md). The source path below uses the same installed setup/provisioning helpers with separate source ownership. Older manual installations require the explicit migration described in PACKAGES.md.

This is the native Linux path for RawPair and Orqos. It uses no Docker daemon, Kubernetes, stack images, or container startup/shutdown scripts. The separate container instructions are in [CONTAINER_SETUP.md](CONTAINER_SETUP.md). Native operations and the control contract are in [Orqos HOST_API.md](https://github.com/orqos-project/orqos/blob/main/docs/HOST_API.md).

## Host prerequisites

Use an Ubuntu 24.04 or 26.04 systemd host (the setup helper enforces these versions), with cgroup v2, Linux 5.6+ (`openat2`), a nonconflicting private IPv4 /16, and administrative access for installation. The native files API supports x86_64 and aarch64 Linux. Workspace homes live under `/srv/rawpair`, outside `/home`. Accounts are dedicated to workspaces: do not grant them sudo, shared groups, host SSH login, or control-plane secrets. The provisioner sets a locked password, nologin shell and expired account date, preventing SSH sessions and forwarding outside Orqos. Orqos validates these restrictions; systemd launches `/bin/bash` explicitly without PAM login.

Install OS services and build prerequisites:

```sh
sudo apt update
sudo apt install -y build-essential pkg-config libssl-dev git curl unzip python3 \
  postgresql postgresql-client nginx iproute2 nftables tmux ttyd nodejs npm \
  mkcert libnss3-tools
sudo systemctl enable --now postgresql nginx
```

Install Erlang/OTP 27 and Elixir 1.18 using your normal package source or version manager, and Rust stable with Cargo. The locked Phoenix dependencies require at least Elixir 1.16; Ubuntu 24.04's stock Elixir package is older, so use your existing asdf/mise installation or a suitable Elixir package source. Node 18+ is sufficient for collaboration; Node 20+ is a suitable operator choice. Verify `erl -version`, `elixir --version`, `mix --version`, `node --version`, and `cargo --version` before building. The delivery checks used OTP 27, Elixir 1.18.3, Node 24.21.0, Rust 1.99.0, and PostgreSQL 18. The distribution database is PostgreSQL 16 on Ubuntu 24.04 and PostgreSQL 18 on Ubuntu 26.04. Confirm `ttyd --help` includes `--writable`, `--base-path`, and Unix socket support. No automatic workspace-language installer is included.

## Get both repositories and install Orqos

The source path uses sibling checkouts. If you do not have them yet:

```sh
mkdir -p ~/dev
cd ~/dev
git clone https://github.com/orqos-project/orqos.git
git clone https://github.com/rawpair/rawpair.git
```

Build and install the Orqos execution assets. Choose a private `/16` that does not overlap your LAN/VPN routes; the installer checks before initialization. This example uses the setup wizard's default:

```sh
cd ~/dev/orqos
cargo build --release --locked
sudo packaging/install-host.sh 10.231.0.0/16
```

Do not provision the default slots or start Orqos separately for a new integrated installation. RawPair's wizard does that next. If you choose a different subnet here, enter that same subnet in the RawPair wizard. Initialization refuses changing an existing inventory subnet silently.

Each provisioned slot gets its own account/home/project directory, network index and ceilings of 2 CPU cores, 2048 MiB RAM and 512 tasks. Workspace `index` values allocate distinct `/30`s within the private `/16`. DNS must use public IPv4 resolvers reachable through your router. The installer enables `net.ipv4.ip_forward=1` through its own sysctl file. Existing firewall tables/default policies are preserved. If another firewall drops forwarded packets, allow outbound traffic and established replies for the configured workspace range in that firewall; inspect `nft list ruleset`, never flush existing tables. Private LAN dependencies and IPv6 workspace egress are not supported in this MVP.

The daemon listens on loopback port 9080 and requires the random bearer secret in `/etc/orqos/host.env` for every host-control or forwarding request. Its root-owned helper accepts only the documented action vocabulary and operator inventory. Keep this control port private. Initialization preserves existing inventory and secrets; it does not start workspace runtimes.

## Choose local or remote access

Use **local** mode for a browser on the deployment host. The wizard runs mkcert trust installation and generates a certificate as your invoking ordinary user; you do not need to generate or pass certificates first. The management URL defaults to `https://rawpair.localhost`, with application URLs under `*.apps.rawpair.localhost`. If your browser/resolver needs an explicit mapping, follow [local TLS and hostname instructions](PACKAGES.md#local-tls-and-browser-trust).

Use **remote** mode for friends/coworkers on another machine. Prepare server-resolving management/wildcard-preview DNS and a certificate/key covering those names, then enter their absolute paths in the wizard. [Remote setup](PACKAGES.md#remote-setup-dns-and-certificates) covers DNS, HTTPS reachability, free public certificate options and renewal. `.localhost` cannot name your server from another computer.

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

Follow [Your first shared workspace](FIRST_WORKSPACE.md) after setup prints your login URL. It covers creating and starting a workspace, serving a page with the installed Python, opening its private preview, shared editing/terminal, adding a coworker, two independent projects and persistent files. It is the same workflow for package and source installations.

## Development databases

Install a database toolchain on the host as operator (`sudo apt install postgresql`). The example below uses version 16 on Ubuntu 24.04; use `/usr/lib/postgresql/18/bin` on Ubuntu 26.04. In each workspace's terminal, use its own data and socket directory, not the control-plane PostgreSQL database:

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

For source upgrades, rebuild both repositories and reinstall their source assets. `native/install.sh` invokes setup, which backs up and migrates when the installed release version changes; use `sudo rawpair setup` to resume an interrupted upgrade. If you rebuild the same release version with schema changes, run `sudo rawpair migrate` followed by `sudo rawpair setup` explicitly. Manual migration also backs up first and leaves controls stopped until setup completes. For package upgrades, use the coordinated bootstrap flow in [PACKAGES.md](PACKAGES.md). Keep `/etc/{rawpair,orqos}`, `/var/lib/orqos/host`, PostgreSQL, workspace homes, and `/var/lib/rawpair-collaboration` in backups; the latter contains unsaved collaborative document copies. Do not remove inventory accounts or change their user/home/project/index mappings while registrations exist. After removal, an operator may archive/delete the preserved home and remove the account. Uninstalling services/files is an explicit operator operation; installers do not destroy data.

Expired login/preview credentials can be pruned in PostgreSQL with `DELETE FROM user_sessions WHERE expires_at < now(); DELETE FROM preview_credentials WHERE expires_at < now();`. Logout immediately revokes the originating login and dependent private-preview/collaboration checks. Established proxy WebSockets are authorized at handshake; visibility/membership changes apply on their next connection. Yjs connections additionally recheck authorization every 15 seconds. Stop a workspace to terminate its existing terminal/application connections immediately.

The collaboration reset endpoint is local and service-authenticated: `DELETE http://127.0.0.1:1234/internal/workspaces/<database-id>/documents`, with `Authorization: Bearer <RAWPAIR_COLLABORATION_TOKEN>`. Close affected editors first. It clears that workspace's collaborative snapshots so the next editor connection initializes from project files. Project-file deletion/removal invokes this cleanup automatically. If collaboration was unavailable during deletion, stale snapshots remain inaccessible through the incremented document generation and may be purged when service access recovers.

## Scope and available checks

This is a trusted-collaborator MVP on one Linux host, not hardened isolation for arbitrary untrusted tenants. There is no automatic language/database provisioning, production app supervision, generic TCP/UDP publication, IPv6 workspace egress, enterprise SSO, or Rezn integration. Workspace resource ceilings are enforced; file sizes/number, synchronous collaboration snapshots, and basic file selection are deliberate initial limits. Only HTTP development applications are registered internally; browser ingress is HTTPS and WebSocket-capable. See [HANDOFF.md](HANDOFF.md) for exact checks run and live paths still unverified.
