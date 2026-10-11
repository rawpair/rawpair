# Native installation delivery handoff

Updated 2026-10-11. The package implementation was committed at the user's request as RawPair `242ffc0` and Orqos `45bda13`. No push, release creation/publication or service deployment was performed during that delivery. Use [PACKAGES.md](PACKAGES.md) for installation, [FIRST_WORKSPACE.md](FIRST_WORKSPACE.md) for the first shared session and [RELEASING.md](RELEASING.md) for the maintainer release procedure.

## Delivered

The new package builders produce `rawpair`, `orqos-host` and the architecture-independent `rawpair-native` exact-pair metapackage. They include Phoenix/ERTS/assets, the versioned Go CLI and alias, production collaboration dependencies, Orqos execution helpers and native systemd units. They declare runtime dependencies, reject wrong binary architecture and inconsistent release metadata, omit generated secrets/cookies and keep configuration/state outside package payloads. The old Docker-dependent package hooks/unit have been replaced.

`rawpair setup` and protected JSON input share the installed Python setup helpers with source installation. Setup covers platform/prerequisite/ownership/port/subnet checks, ordinary-user mkcert trust and local loopback TLS, supplied remote certificates, local/existing PostgreSQL, preserved secrets, two default account slots, migration and first-login bootstrap, durable retries and validated service startup. `doctor [--json]`, `workspace add`, `user add` and `migrate` are installed commands. Orqos has standalone local initialization/provisioning/diagnostic/owned-stop commands, with no new HTTP endpoints.

RawPair upgrade hooks stop controls and set a reboot-persistent setup gate. Upgrade setup backs up configuration/certificates and the configured database before migration; failures retain stopped controls and recovery information. Migration output is retained only in a root-only log. Orqos upgrades preserve independent workspace services; explicit removal verifies/stops owned workspaces before assets disappear. Removal/purge preserve databases, accounts, homes, inventory, journals, snapshots and ownership. Setup/progress/configuration ownership stays with root; only runtime subdirectories are service-owned.

Both repositories now use native `ubuntu-24.04`/`ubuntu-24.04-arm` release jobs and pinned build toolchains. Orqos publishes packages alongside retained binaries to a draft. RawPair pins Orqos `v0.2.2`, downloads its unchanged packages, checks SHA256 and original GitHub provenance, tests both architecture sets, assembles manifests/checksums/bootstrap, attests assets and uploads a draft for operator review. No PAT or signing-key service is required. Checksums are documented separately from provenance verification.

The bootstrap resolves one immutable RawPair release, verifies matching downloads, supports explicit versions, download-only and no-setup, installs all three packages together through apt and invokes setup by default. The documentation covers unattended input, certificate renewal, database TLS, manual installation, legacy refusal/migration, backups, recovery, source installation, Docker separation and the release order.

## Onboarding documentation follow-on

The repository READMEs now lead to installation and a first working session. [FIRST_WORKSPACE.md](FIRST_WORKSPACE.md) covers a Python-served page, saved/shared edits, terminal access, a private preview, adding a coworker and two independent projects. The package guide includes actual download commands, local wizard choices, remote prerequisites and troubleshooting; [RELEASING.md](RELEASING.md) holds the maintainer procedure. Stale native-status claims and removed installer invocations have been corrected or explicitly marked as historical.

Checking the documented configuration exposed a validator that rejected its own local `rawpair.localhost` / `apps.rawpair.localhost` pair. That exact local-only pair is now accepted; custom and remote nested domains remain refused. Two regression tests cover acceptance and retained rejection rules. The RawPair Python suite was rerun with 22 passing tests. Changed Markdown links/anchors and shell/JSON/embedded-Python examples were checked. The walkthrough's page/server commands served a page and reflected a saved edit on a temporary localhost port; this was not a full workspace, browser or package installation check. No additional live deployment or release validation was performed.

## Checks actually run

| Check | Result |
| --- | --- |
| RawPair Python installer/setup/release suite | Rerun during the documentation follow-on: 22 tests passed, including the documented local defaults and custom/remote origin rejection, architecture selection, immutable downloads, checksum refusal, unsupported OS/tag, no-setup/download-only/default setup, protected input, TLS key/hostname/wildcard/expiry checks, secret-free arguments, retry/interruption handling, backup/migration failure behavior, unmanaged refusal and release manifests |
| Orqos administrator suite | 8 tests passed: private subnet validation, conflicting routes, owned-route exception, unrelated account/group refusal, interrupted group creation and repeated provisioning |
| RawPair Phoenix suite on isolated PostgreSQL 18 | 16 tests passed, including new first-login retry/password-preservation regression |
| Orqos Rust suite | `cargo test --locked`: 16 passed; existing Docker/Kubernetes/native contracts retained |
| Collaboration suite | `npm --prefix yjs-server test`: 1 passed |
| Go | Go 1.24.2 `go test ./cli/...` and `go vet ./cli/...` passed; these packages currently contain no Go test cases. Built amd64 CLI, checked version/help, and cross-compiled the arm64 CLI |
| Phoenix production release | `MIX_ENV=prod RAWPAIR_BACKENDS=host RAWPAIR_VERSION=0.0.1 mix release --overwrite` passed with pre-existing Finch behaviour/@impl warnings |
| Package structure | Assembled amd64 `rawpair_0.0.1`, `rawpair-native_0.0.1_all` and `orqos-host_0.2.0` smoke packages; validated metadata, dependencies, architecture, payload paths, ERTS/assets/modules, root ownership, permissions, absence of generated secret/config/state files and absence of build/image/network-fetch commands in install hooks |
| Wrong-architecture guard | Attempt to label the amd64 RawPair inputs as arm64 failed before packaging, as intended |
| Workflows/scripts | actionlint 1.7.7 passed all four workflows; YAML, shell/JavaScript/Python syntax and `git diff --check` passed in both repositories |
| Diagnostics failure mode | Source helper `doctor --json` emitted structured actionable failed checks and returned 1 on this unsupported/unconfigured host |

The temporary PostgreSQL test service was stopped. It was a scratch database under `/tmp/rawpair-easy-install`, not a deployment database. No host packages were installed or control/workspace services deployed.

## Original delivery validation limits and next release

This workstation is Ubuntu 26.04 amd64. Locally assembled `.deb` files validate packaging structure; they are not supported Ubuntu 24.04 release binaries. The Orqos packaging smoke check used a pre-existing native debug binary, not a release build. Native Ubuntu 24.04 builds, arm64 Phoenix/Orqos packaging, apt dependency resolution, real package hooks/install/upgrade/removal, mkcert client trust, privileged systemd/cgroup/network behavior and the installed end-to-end workspace flow have not run here. The release workflows have been linted, not executed on GitHub.

The hosted jobs are configured to exercise fresh/repeated unattended setup, two workspaces, collaborative files/Yjs, two authenticated ttyd WebSockets sharing tmux, private TLS previews, independent stopping, control restart, a coordinated later-version package fixture, backup-before-migrate, service startup gates and data-preserving remove/purge. These are implemented acceptance scripts, not passing live evidence. Full visual browser/Monaco and interactive operator wizard acceptance remain to be performed as well.

The first release needs the operator to review, build and publish Orqos `v0.2.2` before RawPair can fetch that pinned package set. Then build the desired RawPair tag, review both hosted architecture jobs and the draft's assets/attestations, and publish manually. The checked-in compatibility pin intentionally does not resolve an unpublished partner through `latest`.

Automatic legacy migration, ACME issuance, APT hosting, additional distributions, database rollback and host language-toolchain installation remain deferred. Existing native runtime MVP limits in [HANDOFF.md](HANDOFF.md) still apply.

## First hosted release follow-up

The Orqos `v0.2.0` hosted builds and installation lifecycle checks passed on both architectures, and its downloads/checksums/provenance were verified before publication. RawPair’s first hosted build passed its unit suites and built both native packages, then exposed a provisioning timeout: hosted runners can have an 816 MB `/etc/skel`, which `useradd --create-home` copied into each workspace. Orqos `v0.2.1` provisions only the owned directories and checks that host skeleton files are not copied. RawPair now pins that patch. TLS hostname validation also requires OpenSSL’s explicit positive result, because Ubuntu’s supported OpenSSL can exit zero on a mismatch. Database URLs now populate separate libpq environment fields; putting a URI in `PGDATABASE` failed to select the requested server/user. An isolated PostgreSQL integration test covers encoded credentials/names, connection, password rejection and `pg_dump`. Hosted RawPair installation/lifecycle evidence is recorded in the published release notes; the table above remains the earlier workstation snapshot.

The first installed workspace check also exposed a Phoenix controller handler named `action/2`, which overrode the framework dispatcher. The handler is now `transition/2`, preserving the public URL, with route regression tests. Orqos `v0.2.2` makes the root-owned workspace parent traversable under its restrictive umask and explicitly applies/verifies interface ownership labels. A focused hosted runtime check passed two workspaces, terminal pages, shared files, HTTP proxies, independent stop, control restart and data-preserving removal before the patch package build. Those checks now run in Orqos’s release pipeline as well. RawPair pins `v0.2.2`.

## Ubuntu 26.04 support follow-up

RawPair v0.0.3 pins Orqos v0.2.3 and supports Ubuntu 24.04 and 26.04 on amd64 and arm64. Both release pipelines keep the Ubuntu 24.04 build baseline and run the exact resulting packages on Ubuntu 26.04 runners of each architecture before creating a draft. RawPair repeats installed setup, collaboration, terminal/preview, coordinated upgrade and data-preserving removal checks on all four OS/CPU combinations. No workstation services are installed by these checks.

The schema-1 manifests retain `ubuntu: "24.04"` for the build baseline and declare runtime support in `ubuntu_versions: ["24.04", "26.04"]`. The bootstrap and installed setup both enforce the selected package's platform support. Legacy manifests without the list remain 24.04-only. Do not replace or relabel older published assets.

Local follow-up validation passed 29 RawPair Python tests, including both OS/CPU selections, invalid compatibility metadata, legacy release refusal on 26.04 and installed setup checks. Orqos's 3 file-boundary and 9 administration/release tests passed. Published release notes record the hosted workflow results; the earlier delivery table and limits above describe their original point in time. Full visual Monaco and interactive wizard acceptance remain hands-on checks.

## Private-directory setup recovery

Local dogfooding exposed an Erlang startup failure when a release task inherited an operator's private working directory. The unprivileged `rawpair` account cannot traverse a mode-0700 installer folder or a mode-0750 user home. Release migrations and account tasks now explicitly start from `/opt/rawpair`. The installed acceptance script runs fresh and repeated setup from a root-only temporary directory on all four Ubuntu/CPU runners to cover this case.

On v0.0.3, an affected setup can be resumed without reinstalling or changing directory permissions: run `cd /opt/rawpair` followed by `sudo rawpair setup`. Saved configuration and the initial account credentials are reused. The permanent fix is included starting with v0.0.4. The local Python regression suite still passes all 29 tests.

## Current Chromium local trust

Workstation dogfooding also found that Ubuntu's mkcert 1.4.4 does not discover Chromium's newer `~/.local/share/pki/nssdb` certificate store. Starting with v0.0.5, setup explains system/browser CA trust and asks for separate approval before installing it, defaulting to no. Manual trust remains available. Approval is per invocation and never persisted; unattended setup requires explicit `trust_local_ca: true` in protected local-mode input. Approved installation includes the existing Chromium store and requests a browser restart. Setup does not disable certificate checks or copy the CA private key. The 35-test Python suite covers consent/defaults, noninteractive retries and a real NSS database check for repeated import and preservation of unrelated certificates. See [local TLS and browser trust](PACKAGES.md#local-tls-and-browser-trust).
