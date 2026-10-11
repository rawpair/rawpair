# Native host MVP delivery handoff

Native package/bootstrap/setup follow-on: [PACKAGE_HANDOFF.md](PACKAGE_HANDOFF.md) records the 2026-10-11 implementation and available checks; [PACKAGES.md](PACKAGES.md) is the package operator guide.

Updated: 2026-10-11. The implementation and operator assets for [goal.txt](../goal.txt) are delivered across `~/dev/rawpair` and `~/dev/orqos`. The native runtime and package implementations were committed separately in both repositories at the user's request. Release publication, system installation and live deployment remain operator steps; the recorded checks below do not establish a live deployment. Builds and automated checks provide evidence; the complete privileged-host/browser workflow remains unverified.

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
| Native install, build, start and operations | RawPair `native/`, [NATIVE_SETUP.md](NATIVE_SETUP.md); Orqos `packaging/` and [HOST_API.md](https://github.com/orqos-project/orqos/blob/main/docs/HOST_API.md). |
| Retained container option and APIs | RawPair Docker adapter/client/manager, `compose.container.example.yml`, protected `nginx.conf`, [CONTAINER_SETUP.md](CONTAINER_SETUP.md); existing Orqos Docker/Kubernetes routes and backend choices retained. |

RawPair owns policy, users, membership, collaboration and presentation. Orqos owns execution, files, networking and observation. Rezn, rezn-dsl, stacks and rawpair.dev received no implementation changes. The stacks repository remains the Docker image catalog. Preexisting worktree changes, including the user's dependency lockfile changes, were retained. Original scope/design documents remain available in [HOST_MVP.md](HOST_MVP.md) and Orqos `docs/HOST_BACKEND.md`.

## Current operator path

Use [PACKAGES.md](PACKAGES.md) for the complete prebuilt Ubuntu 24.04 installation path, including download commands, local/remote setup, first login, TLS, diagnostics, upgrades and recovery. The paired native assets require reviewed, published releases; [RELEASING.md](RELEASING.md) describes that maintainer step. For a source build, use [NATIVE_SETUP.md](NATIVE_SETUP.md), which installs the same setup helpers under distinct source ownership.

The former `native/install.sh CERT KEY [HOST PREVIEW]` interface and manual configuration bootstrap have been replaced. The current source installer is `sudo native/install.sh [PROTECTED_JSON]`; it launches the setup wizard or consumes protected JSON. The wizard configures the database, certificates, secrets, first login and default account slots, then migrates and starts validated services. Do not bypass setup with hand-edited credentials or manually start gated services.

After setup, run `sudo rawpair doctor`, then [create your first shared workspace](FIRST_WORKSPACE.md). Add collaborators with `sudo rawpair user add`; workspace owners grant membership through the UI. For a source upgrade, rebuild/reinstall the assets and complete `sudo rawpair setup`; package users upgrade the matching pair through the bootstrap.

RawPair and collaboration run under separate unprivileged accounts; Orqos performs constrained privileged operations. Keep loopback controls 9080, 4000 and 1234 private. Provisioned workspace accounts have locked passwords, expired account dates, nologin shells, dedicated primary groups and no supplementary groups. Do not loosen those restrictions to make host SSH access work.

For retained Docker deployments, use [CONTAINER_SETUP.md](CONTAINER_SETUP.md), including its documented operator action for previously ownerless records. Legacy CLI/Ansible/compose helpers do not configure the native services or current authenticated gateway.

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
