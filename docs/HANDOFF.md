# Native host MVP delivery handoff

Updated: 2026-10-11. The implementation and operator assets for [goal.txt](../goal.txt) are delivered across `~/dev/rawpair` and `~/dev/orqos`. No commits, pushes, merges, publication, system installation or live deployment were performed. The user owns those next steps. Builds and automated checks provide evidence; the complete privileged-host/browser workflow remains unverified.

## Implemented behavior

RawPair supports password login with operator-created accounts, database-backed expiring sessions, explicit workspace membership, and owner/member roles. Each account can access multiple projects. Members can edit, use the terminal, start/stop runtimes and open private previews. Owners additionally configure limits, manage members, register/publish applications, remove registrations and separately delete project contents. Role changes cannot remove the last owner. The old chosen-username entry no longer authenticates.

The backend interface selects native Orqos or the retained Docker implementation. Native mode avoids Docker/Kubernetes probing, the remote stacks catalog, image selection and container startup/shutdown scripts. Workspace creation, configuration, observed status, start/reconnect, stop and removal are implemented in the LiveViews and session-authenticated REST API. Creation retains a recoverable database record if initial Orqos registration fails; Start retries registration. Runtime IDs and native account slots remain fixed after creation.

Orqos implements host-only startup and an authenticated, constrained `/host` API. Root-owned inventory maps each slot to one dedicated Unix identity, home/project directory, network index and resource ceiling. It launches a transient systemd service containing the unprivileged supervisor, ttyd, dedicated tmux server, shells and descendants. CPUQuota, MemoryMax/no swap and TasksMax apply to that entire cgroup. Browser disconnection leaves it running. Explicit Stop kills its descendants and cleans its owned networking. Removing the registration preserves account/home/project files; Delete Project Contents is a separate stopped-workspace operation requiring the exact runtime ID.

Persistent ownership tokens, unit properties, namespace identity, interface aliases and firewall comments prevent adoption or cleanup of unrelated host resources. A creation-intent journal handles interrupted namespace creation. Reconciliation cleans stopped/failed networking. Control-service restarts leave independently supervised workspace services running. A host reboot leaves transient services stopped; explicit Start reconstructs runtime/network resources from registration and persistent files.

Each native workspace has its own namespace and loopback, /30 addresses in an operator-selected private /16, virtual link, default route, public DNS and outbound IPv4 NAT. Owned nftables rules block host inputs, private/reserved destinations, other workspaces, unsolicited inbound traffic and direct host-origin access into workspace interfaces. Existing firewall tables/default policies are preserved. A namespace-local Unix-socket bridge reaches registered applications bound only to that workspace's `127.0.0.1`, supporting HTTP and WebSocket upgrades without host-port collisions.

The native files API permanently drops supplementary groups/GID/UID before opening the project root. Linux `openat2` resolution rejects traversal, symlinks and project submount crossings. The editor lists, reads and saves actual project files with the same permissions as the terminal. Yjs rooms are keyed by workspace, file and document generation, require short-lived session-bound tickets, recheck membership/session access every 15 seconds and persist shared document snapshots. Per-file Monaco models survive switching/reconnection. Save writes the selected shared document to the project filesystem. Confirmed Reload from disk replaces that file's shared contents for every participant after Git/terminal changes.

Native named applications have validated internal HTTP ports and independent HTTPS preview origins. Private previews exchange a single-use grant for an application-scoped, host-only cookie tied to the original login; logout/membership changes deny subsequent requests. Owners explicitly confirm public sharing. Public preview access grants no editor, terminal or management access. The proxy accepts only registered workspace/application targets, strips management/preview credentials and Orqos's bearer secret before application delivery, and preserves application cookies, Authorization headers and encoded paths.

## Implementation map and scope audit

Paths are relative to their repository.

| Goal area | Delivered source/assets |
| --- | --- |
| Runtime interface, lifecycle, multiple projects | RawPair `lib/rawpair/runtime*.ex`, `lib/rawpair/runtime/`, `lib/rawpair/workspaces.ex`, workspace schemas/migration, workspace LiveViews and `WorkspaceController` under `phoenix-app/`. |
| Dedicated accounts, cgroups, persistence, ownership/recovery | Orqos `src/host.rs`, `host/host.py`, `host/workspace.py`, `packaging/provision-workspace.sh`, `packaging/host.example.json`. |
| Safe native files and real collaborative editing | Orqos `host/files.py`; RawPair `FileController`, `CollaborationController`, editor hooks/components and `yjs-server/server.mjs`. |
| Namespace routing/DNS/firewall and localhost forwarding | Orqos `host/host.py`, `host/workspace.py`, ingress HTTP/WebSocket bridge in `src/host.rs`. |
| Authentication and authorization on each access path | RawPair `Accounts`, `Auth`, authenticated router, `UserSocket`/`TerminalChannel`, file/collaboration/gateway/preview controllers. Native access through the alternative Docker terminal channel is rejected. |
| Private/public applications and separate origins | RawPair `Applications`, application schema, owner UI/API, `PreviewController`, `native/nginx.conf.template`. |
| Native install, build, start and operations | RawPair `native/`, [NATIVE_SETUP.md](NATIVE_SETUP.md); Orqos `packaging/` and [HOST_API.md](../../orqos/docs/HOST_API.md). |
| Retained container option and APIs | RawPair Docker adapter/client/manager, `compose.container.example.yml`, protected `nginx.conf`, [CONTAINER_SETUP.md](CONTAINER_SETUP.md); existing Orqos Docker/Kubernetes routes and backend choices retained. |

RawPair owns policy, users, membership, collaboration and presentation. Orqos owns execution, files, networking and observation. Rezn, rezn-dsl, stacks and rawpair.dev received no implementation changes. The stacks repository remains the Docker image catalog. Preexisting worktree changes, including the user's dependency lockfile changes, were retained. Original scope/design documents remain available in [HOST_MVP.md](HOST_MVP.md) and Orqos `docs/HOST_BACKEND.md`.

## Exact operator path

Use a Linux systemd host with cgroup v2, kernel 5.6+ and x86_64/aarch64 for native files. Ubuntu 24.04 is the initial recipe. Install OS prerequisites:

```sh
sudo apt update
sudo apt install -y build-essential pkg-config libssl-dev git curl unzip python3 \
  postgresql postgresql-client nginx iproute2 nftables tmux ttyd nodejs npm \
  mkcert libnss3-tools
sudo systemctl enable --now postgresql nginx
```

Install Erlang/OTP 27, Elixir 1.18 and Rust stable using your usual package source/version manager. Ubuntu's stock Elixir is too old for the locked dependencies; Elixir must be at least 1.16. Use Node 18+ and ttyd with Unix socket, writable and base-path support. [NATIVE_SETUP.md](NATIVE_SETUP.md) explains version checks, public IPv4 DNS, firewall integration and toolchain provisioning.

Build and install Orqos, provision the two example slots, and review the nonconflicting subnet and account mapping:

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

Provisioned workspace accounts have locked passwords, expired account dates, nologin shells, dedicated primary groups and no supplementary groups. Systemd launches Bash explicitly without PAM login. Keep these restrictions; they prevent SSH sessions/forwarding outside the workspace namespace. The example inventory permits 2 CPU cores, 2048 MiB RAM and 512 tasks per slot. The installer enables IPv4 forwarding, preserves inventory/secrets and never launches a workspace automatically.

As the ordinary browser user, generate and trust local TLS, then build/install RawPair and bootstrap logins:

```sh
mkcert -install
mkcert -cert-file /tmp/rawpair-local.pem -key-file /tmp/rawpair-local-key.pem \
  rawpair.localhost '*.apps.rawpair.localhost'
cd ~/dev/rawpair
native/build.sh
sudo native/install.sh /tmp/rawpair-local.pem /tmp/rawpair-local-key.pem
sudo native/admin.sh migrate
sudo native/admin.sh create-user
sudo native/admin.sh create-user
sudo systemctl enable --now rawpair-host rawpair-collaboration
sudo systemctl reload nginx
```

`create-user` prompts for username and a 12..1024-byte password without echoing it. Installation generates secrets, an ordinary PostgreSQL role/database, nginx configuration and environment files on a fresh host. Existing environments are preserved. If PostgreSQL already has a `rawpair` role, populate `/etc/rawpair/rawpair.env` using `native/rawpair.env.example` and its actual credentials, then rerun installation. See NATIVE_SETUP for exact ownership/modes and custom domains. RawPair/Node run as separate unprivileged accounts; Orqos alone performs the constrained privileged work. Never publish loopback control ports 9080, 4000 or 1234.

Open `https://rawpair.localhost` on the deployment host. Nested `.localhost` names normally resolve to browser-local loopback; NATIVE_SETUP includes `/etc/hosts`/resolver fallbacks. For remote collaborators use real server-resolving management/application names, certificates trusted by every browser, and the install script's hostname arguments. Public access uses ordinary DNS/inbound HTTPS or a tunnel supporting both hostnames and WebSockets.

Create two workspaces in separate slots, Start each, add the second login as a member, and open the editor/terminal from both accounts. Run both development servers on localhost:3000, register `web` on port 3000 in each workspace, and open their distinct preview URLs. Owners can deliberately publish either application. Stop either workspace to stop its processes while the other remains independent. The setup guide also includes per-workspace PostgreSQL data/socket commands, logs, upgrade, restart, backups and cleanup.

For existing Docker workspace records, first create a login, then use `sudo native/admin.sh adopt-legacy` in a host/mixed installation or `Rawpair.Release.adopt_legacy()` through the container release with `RAWPAIR_USERNAME`. This assigns only previously ownerless records. Old chosen-username sessions are invalid. The separate Docker deployment recipe is [CONTAINER_SETUP.md](CONTAINER_SETUP.md); legacy CLI/Ansible/compose helpers do not install the new native services or authenticated gateway.

## Checks actually run

| Check | Result |
| --- | --- |
| Orqos `cargo check --locked`, `cargo test --locked`, `cargo fmt --check` in the prepared source tree | Passed; 16 Rust tests. The reviewed source was applied to the actual Orqos checkout. Subsequent changes concerned Python/provisioning/docs only. |
| Orqos `python3 -m unittest discover -s host -p 'test_*.py' -v` | Passed; 3 real filesystem boundary tests covering traversal, symlinks, hardlinks, directory replacement, read/write/list and size limits. |
| Python helper/configuration compilation and shell syntax checks | Passed for native assets and Orqos helpers/provisioning. |
| RawPair `PGHOST=127.0.0.1 PGPORT=55432 PGUSER=rawpairtest RAWPAIR_BACKENDS=host mix test` | Passed; 15 tests, 0 failures against an isolated local PostgreSQL 18 cluster. Covers password/session access, membership/owner roles, alternative terminal denial, scoped tickets/revocation and private/public preview policy. |
| `npm --prefix yjs-server test` | Passed; real HTTP/WebSocket integration for two editors, independent files, reconnect persistence, denied access, confirmed shared reload and reset cleanup. The test supplies an authorization fixture; production uses the Phoenix callback. |
| Editor TypeScript `tsc --noEmit --module esnext --moduleResolution bundler` | Passed. |
| Phoenix compilation, development asset build, production `mix assets.deploy` and `mix release --overwrite` | Passed. Final release generated at `phoenix-app/_build/prod/rel/rawpair`. Production build log: `/tmp/rawpair-prod-build.log`. |
| Git whitespace checks | Passed for delivered changes. |

Delivery tools: OTP 27, Elixir 1.18.3, Node 24.21.0, Rust 1.99.0 and PostgreSQL 18. Compilation retains warnings from the preexisting unused `RawPair.MintUnixHTTP1` module and dependency code. The temporary PostgreSQL test service was stopped after checks; it is not a deployment database.

## Unverified live paths and concrete limits

No full installation was run on a privileged systemd host. Live cgroup enforcement, namespace creation/NAT/DNS/firewall coexistence, ttyd/tmux browser attachment, control restart/reboot recovery, nginx/TLS/browser preview redirects and end-to-end app WebSocket/HMR behavior are implemented but not live-verified here. Docker/Kubernetes source contracts were retained; Docker builds, live container workflows and Kubernetes smoke checks were not run in this delivery. These are validation gaps, not stubbed runtime paths.

The MVP targets one host and trusted collaborators. It does not isolate arbitrary hostile tenants, provision language/database tools automatically, supervise individual production applications, expose generic TCP/UDP, provide IPv6 workspace egress, reach private LAN dependencies, add enterprise SSO or integrate Rezn. Workspace disk quotas are not provided. Dedicated accounts and resource/network controls do not turn the shared host kernel into a hostile-tenant boundary.

Editor files are UTF-8 text without NULs, at most 2 MiB and with one hard link. Listings skip common dependency/build directories and cap at 20,000 files/depth 32. Use the terminal for directories/binaries. Native saves retain permissions and fsync in place; they are not crash-atomic. Shared Yjs edits persist separately until Save; Git/terminal changes require confirmed Reload from disk. Automatic external-change reconciliation, a richer file browser and asynchronous/compacted collaboration persistence are remaining polish.

Terminal/application WebSockets are authorized at handshake; membership/visibility changes take effect on their next connection. Yjs also rechecks every 15 seconds. Stop the workspace to terminate its existing terminal/application connections immediately. Existing external forwarding firewalls may require an explicit allow rule for outbound/reply traffic; Orqos does not flush or override them. Framework Host validation and HMR external-origin settings remain ordinary project configuration.

Control-service shutdown preserves running workspace services. Stop workspaces explicitly before shutting down the whole deployment. Removal preserves home/project data and frees the slot for intentional reuse. Back up PostgreSQL, `/etc/{rawpair,orqos}`, `/var/lib/orqos/host`, workspace homes and `/var/lib/rawpair-collaboration`. If collaboration cleanup is temporarily unavailable during project deletion, the incremented document generation makes old snapshots inaccessible; the authenticated local reset endpoint can purge them later. Detailed operations are in NATIVE_SETUP and HOST_API.
