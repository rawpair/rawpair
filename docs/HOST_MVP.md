# Native host workspace MVP

## Delivery status

Implemented on 2026-10-11. This document preserves the agreed design brief; use [PACKAGES.md](PACKAGES.md) or [NATIVE_SETUP.md](NATIVE_SETUP.md) for executable operator instructions and [HANDOFF.md](HANDOFF.md) for the final implementation, checks and limitations. The actual Orqos contract is [HOST_API.md](https://github.com/orqos-project/orqos/blob/main/docs/HOST_API.md).

RawPair supports collaborative development directly on a Linux host through Orqos. A user can work on several projects, build and run them with native toolchains, and expose HTTP applications through controlled URLs. Docker remains an optional RawPair backend; Orqos also retains its Kubernetes API. Neither is a prerequisite for the host workflow.

The brief was recorded on 2026-10-10 and implemented on 2026-10-11. [goal.txt](../goal.txt) defines delivery and completion. [The handoff](HANDOFF.md) records delivered behavior, operator commands, check results and unverified live paths.

## Product scope

Target one Linux machine running systemd and a trusted group of collaborators. Default to one project per workspace. A user may belong to several workspaces, and several users may share a workspace. Participants in a shared workspace intentionally use the same runtime Unix identity, files, processes, and terminal. A workspace is the separation boundary; it is not the same as a browser session or a RawPair user account.

The first release includes:

- Authentication, workspace membership, and a backend choice when configuring a workspace.
- Persistent project files and collaborative editing, scoped by workspace and file.
- A persistent shared terminal and ordinary Git, build, and execution commands.
- Start, reconnect, stop, and removal operations with observable failures.
- Separate workspace Unix accounts, resource limits, and network namespaces.
- Named HTTP/WebSocket applications with private HTTPS previews and deliberate public sharing.
- Native setup instructions and service/configuration assets for the full application.

Users can run development databases in their workspace using installed software and a workspace data directory. Automatic database provisioning and managed production deployments are deferred. Browser disconnection keeps processes running; explicit workspace stop stops them and preserves project files. Removing a runtime preserves files by default; deleting files is a separate destructive action.

## Repository responsibilities

| Repository | Responsibility for this milestone |
| --- | --- |
| RawPair | User authentication, membership, collaboration, workspace and application UI, access policy, Orqos integration, native setup. |
| Orqos | Native execution, systemd supervision, resource controls, workspace identities, filesystem operations, network setup, protected internal forwarding, status and cleanup. |
| stacks | Existing Docker image catalog. Host mode does not fetch or require these images. |
| Rezn and rezn-dsl | No implementation changes for this milestone. Native workspaces do not pass through signed container intent. |
| rawpair.dev | Public product claims can be updated after implementation; the native implementation is delivered in these two repositories; the public site was not changed. |

Keep ttyd and tmux. ttyd provides browser terminal transport and tmux provides the shared persistent session. Orqos supervises their execution; RawPair controls who can connect. Do not build a second terminal emulator or put a Rezn controller between the user and the workspace.

## Workspace execution

RawPair needs a workspace interface covering lifecycle, status, file operations, and terminal/application connection information. The existing Docker implementation remains available. The native implementation calls Orqos and does not duplicate privileged process management in Phoenix.

Each host workspace has a stable ID, dedicated Unix account, persistent home and project directories, clean environment, runtime directory, and dedicated tmux socket. Preconfigured accounts are acceptable for the MVP. The operator controls the permitted account/root mappings; an API caller must not select arbitrary host users or directories. Protect control-plane secrets and state from workspace processes.

Run ttyd and its dedicated tmux server inside the workspace's systemd service, so their children remain in the same managed cgroup. Reusing an unrelated tmux server outside that service would break lifecycle and resource accounting. Configure CPU, memory, and task limits, plus suitable filesystem and privilege restrictions. Native toolchains may be shared read-only, while package caches and project dependencies live under the workspace account.

Orqos records ownership and runtime identity rather than trusting a PID or unit-name prefix alone. Start and stop are idempotent. Startup failures leave a recoverable state and clean up partial runtime/network resources. An Orqos or RawPair restart rediscovers owned services without creating duplicate sessions. Status distinguishes stopped, starting, running, failed, and unavailable observations. A host reboot may leave workspaces stopped; document that policy and make explicit start recover the runtime.

A user can build and run several processes within a workspace, or run several workspaces concurrently. Normal commands remain the interface for development processes. Automatic restart of each user-launched application is not required in the MVP; distinguish a surviving tmux session from a managed production service.

## Native networking

Per-workspace network namespaces are the target networking model for this MVP. They let two workspaces independently use `localhost:3000` for a web server or `localhost:5432` for a database. Separate Unix accounts and cgroups alone do not provide this network separation.

Orqos creates virtual Ethernet links and configures private addresses, routing, firewall policy, DNS, and outbound connectivity. Internet traffic shares the host's existing physical interface, typically using NAT. No additional physical interfaces, router VLAN support, or special external router configuration are needed for workspace networking. External HTTPS ingress is the ordinary server deployment concern.

Namespace creation alone provides no usable internet connection. Package downloads, Git access, DNS, reply traffic, and application forwarding all require configuration. DNS resolver addresses on the host's loopback are not automatically reachable inside a workspace. Define cross-workspace access deliberately and keep management endpoints out of workspace reach by default. Scope firewall changes to deployment-owned rules and never flush unrelated host rules or alter global defaults as a shortcut.

One practical design is a persistent namespace handle per running workspace, a routed virtual link, scoped NAT/filter rules, and a systemd service using `NetworkNamespacePath`. Other small implementations are acceptable if they preserve the same behavior and ownership. Native programs still use the host kernel and installed software; network namespaces do not supply filesystem or privilege isolation.

The ordinary developer experience should not require changing every framework to a globally unique port. A temporary implementation using shared host ports does not complete the namespace requirement.

## Application previews

An application belongs to a workspace and has a name, an internal listening port, an HTTP protocol configuration, and a visibility setting. A workspace can register several applications, such as a frontend and an API. RawPair displays their URLs, readiness or connection errors, visibility, and removal controls.

Use separate application origins, such as `frontend-project-a.apps.example.test`, rather than serving arbitrary application JavaScript under the RawPair management origin. Keep management session credentials out of application requests. The concrete local hostname/certificate scheme is an implementation choice; deliver one that an operator can actually configure and trust in a browser.

Private previews check workspace membership; public visibility requires an explicit authorized action. Sharing an application never shares the terminal, editor, Orqos API, or other applications. Support HTTP and WebSocket upgrades, including common development-server live reload. Generic TCP/UDP forwarding is outside the first release.

The host cannot reach a workspace's `127.0.0.1` simply by proxying to the same address outside the namespace. Orqos must provide a namespace-local forwarder or an equivalent way to reach localhost-only development servers. Expose only registered application ports through protected internal endpoints. A caller cannot turn the preview proxy into an arbitrary connector to host services, other workspaces, or external URLs.

RawPair decides whether a browser request is authorized; Orqos resolves the registered workspace and internal endpoint. Nginx or another existing reverse proxy handles TLS and HTTP/WebSocket forwarding. Do not write a general ingress controller. Removing a publication closes its route without destroying project files. Failed or stopped applications report connection failure rather than routing to another workspace or a reused address.

Public internet access may use normal DNS plus inbound HTTPS or an optional tunnel. A local development setup must also work without buying a domain, changing router capabilities, or requiring an external tunnel provider.

## Authentication and file access

The original chosen-username entry was not authentication. Deliver a verifiable login and explicit workspace membership; operator-created accounts are sufficient. The exact credential mechanism may follow the simplest suitable Phoenix implementation, without adding enterprise SSO to this milestone.

Apply the same authorization to LiveViews, file HTTP endpoints, terminal HTTP/WebSocket connections, alternative Phoenix terminal channels, Yjs connections, and private previews. Protect the RawPair-to-Orqos control API with an authenticated local connection. Loopback binding alone does not authenticate another host process. Keep privileged operations behind a narrow validated interface; neither Phoenix nor workspace shells should have unrestricted root access.

File operations run with workspace permissions and remain under the configured project root. Lexical prefix checks or a check-then-open realpath comparison are insufficient against symlinks and concurrent path replacement. Use directory-relative operations with enforced resolution rules or an equivalently sound implementation. Define supported paths and errors explicitly; rejecting symlink traversal is acceptable for the MVP.

Collaborative documents must be keyed by workspace and file. Loading or changing one file must not overwrite the collaborative contents of another. Preserve the relationship between the shared document and the file being saved. The current generic Yjs server and slug-only document need authentication and file scoping before being reused for the host workflow.

## Setup without Docker

Deliver native setup for Phoenix/BEAM, PostgreSQL, Orqos, the collaboration transport, ttyd, tmux, and the reverse proxy. A single documented Linux distribution, preferably Ubuntu 24.04 or Debian with a suitable systemd, is sufficient initially. State the actual supported versions and prerequisites when implementation is delivered.

Include build commands, migrations, environment/configuration examples, service units or install scripts, Unix account/directory provisioning, privileged-helper installation if needed, login bootstrap, local DNS/hostnames, TLS trust, logs, shutdown, restart, and cleanup. Native PostgreSQL or an existing PostgreSQL service is acceptable; changing database engines is unnecessary.

Host mode must avoid the Docker image selector and remote stack-catalog dependency, Docker-required service units, container bootstrap scripts, and Docker-dependent stop commands. Update the CLI/setup path or clearly provide a separate native setup path. Keep the existing container setup available. Host language runtimes are operator-installed or user-local; building a native replacement for every stack image is deferred.

## Delivery and operator use

The user asked for a delivered MVP, followed by their own local build, deployment, and use. Passing tests, CI, smoke checks, a live deployment, or browser acceptance are not prerequisites for this goal's completion. Available checks are useful evidence and should inform fixes; record their actual results and unverified paths honestly. Missing validation infrastructure must not become a reason to leave otherwise delivered work unfinished.

The implementation must still contain the integrated functionality, setup assets, and usable operator instructions above. Documentation, skeleton routes, mocked behavior, or a known blocker in a core workflow do not meet that bar. The final handoff must explain remaining limitations and how the user starts using the delivered system.

The user's first trial can follow this sequence, without making its execution a completion gate:

1. Build both repositories and install the native services on a disposable or chosen development host.
2. Log in, configure two project workspaces, and start both.
3. Clone or create projects, edit and save files, install dependencies, and build them.
4. Join one workspace from a second authorized browser session; share the editor and terminal.
5. Run a development server on port 3000 in each workspace and register separate preview URLs.
6. Check private access, deliberate public sharing, and WebSocket live reload where used.
7. Disconnect and reconnect, restart the control processes, then stop one workspace while continuing to use the other.

## Implementation references

- [Orqos host backend plan](../../orqos/docs/HOST_BACKEND.md).
- [ttyd command and proxy options](https://github.com/tsl0922/ttyd#usage).
- [Linux network namespaces](https://www.man7.org/linux/man-pages/man7/network_namespaces.7.html) and [ip netns](https://www.man7.org/linux/man-pages/man8/ip-netns.8.html).
- [systemd execution configuration](https://github.com/systemd/systemd/blob/main/man/systemd.exec.xml) and [resource controls](https://github.com/systemd/systemd/blob/main/man/systemd.resource-control.xml).
- [JupyterHub systemdspawner](https://github.com/jupyterhub/systemdspawner), an existing example of native user environments managed with systemd. Its privilege model need not be copied into Orqos.
