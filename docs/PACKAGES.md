# Install native RawPair packages

The native release pipeline produces Ubuntu 24.04 packages for amd64 and arm64. Installation uses prebuilt Phoenix/ERTS, browser assets, collaboration dependencies and Orqos; users need no source checkout, Go, Rust, Erlang, Elixir or build toolchains. The first native Orqos partner is pinned to `v0.2.0` in [compatibility.json](../packaging/compatibility.json). These changes prepare the release pipeline; binaries become available after the operator builds, reviews and publishes the corresponding releases.

Use a normal Ubuntu 24.04 host booted with systemd and cgroup v2. Workspace networking needs a nonconflicting private IPv4 /16 and IPv4 forwarding. Local mode is intended for a browser on the deployment machine. Remote mode needs management DNS and wildcard preview DNS resolving to the server, plus an existing matching certificate/key. The separate [Docker recipe](CONTAINER_SETUP.md) remains available.

## Bootstrap

From a published RawPair release, download its `install.sh`, inspect it, and run it as your ordinary browser user:

```sh
bash install.sh --version vX.Y.Z
```

It detects Ubuntu/CPU, downloads the three matching packages from that immutable tag, verifies SHA256 checksums, invokes `apt-get` to resolve runtime dependencies, and runs `sudo rawpair setup`. Omitting `--version` resolves the latest published stable RawPair tag once; every subsequent asset download uses that tag. Orqos is always selected from the pinned compatibility manifest, never its latest release.

Options:

```sh
bash install.sh --version vX.Y.Z --download-only --output ./downloads
bash install.sh --version vX.Y.Z --no-setup
sudo rawpair setup
sudo rawpair doctor
sudo rawpair doctor --json
sudo rawpair workspace add project-c
sudo rawpair user add
sudo rawpair migrate
```

`--download-only` verifies and saves assets without apt, sudo or setup. Each invocation creates a private download directory and prints its path. `--no-setup` installs the packages and leaves controls stopped. Re-running with a newer RawPair version upgrades the exact tested pair together, then resumes setup from saved configuration. `rawpair-cli` aliases the installed Go `rawpair` command; `quickStart` and `ensureDeps` are legacy source/Docker helpers.

## Manual equivalent

Download `manifest.json`, `SHA256SUMS`, `rawpair_VERSION_ARCH.deb`, `orqos-host_ORQOS_VERSION_ARCH.deb`, and `rawpair-native_VERSION_all.deb` from one RawPair release. Use the versions/architecture named in its manifest. In a directory containing only that matching package set:

```sh
sha256sum --check --ignore-missing SHA256SUMS
sudo apt update
sudo apt install ./rawpair_VERSION_ARCH.deb ./orqos-host_ORQOS_VERSION_ARCH.deb ./rawpair-native_VERSION_all.deb
sudo rawpair setup
```

All downloaded package entries must report `OK`. This is checksum verification, not signature verification. The installer trusts checksums delivered by HTTPS from the same GitHub release. Optional GitHub build-provenance verification is separate:

```sh
gh attestation verify rawpair_VERSION_ARCH.deb --repo rawpair/rawpair
gh attestation verify orqos-host_ORQOS_VERSION_ARCH.deb --repo orqos-project/orqos
```

RawPair redistributes Orqos packages unchanged and verifies their original Orqos repository attestations when assembling a release.

## Interactive setup and TLS

`sudo rawpair setup` offers local or remote installation, PostgreSQL defaults or an existing database URL, private subnet selection and a secure first-login prompt. It checks the platform, dependencies, protected installation ownership, port conflicts, routing overlap, certificate expiry/hostname/wildcard/key agreement, nginx syntax and service readiness. Overlapping routes are refused; choose another private /16 in the wizard. Two dedicated slots, `project-a` and `project-b`, receive separate accounts, project homes, network indexes and inventory resource ceilings. A slot is available for creating a workspace in the UI; provisioning alone does not launch a workspace.

Local defaults are `https://rawpair.localhost` and `*.apps.rawpair.localhost`. nginx binds HTTPS only to `127.0.0.1` and `::1` in local mode. Setup runs `mkcert -install` and certificate generation as the invoking ordinary user, retaining that user's local CA. Trust installation may ask for the user's sudo password. It copies only the leaf certificate/key to root-owned `/etc/rawpair/tls`; it never copies the CA private key into service configuration. Repeated setup preserves the leaf certificate and service secrets.

For root-only/headless invocation, setup prints the CA path and leaves browser trust to the client operator. Copy only `rootCA.pem` to each client and import it into the OS/browser's trusted CAs, or run `CAROOT=/path/containing/rootCA.pem mkcert -install` there. Never distribute `rootCA-key.pem`. For a local server on another machine, use remote mode and names resolving to that machine rather than `.localhost`, which resolves to the client. If a local browser/resolver does not resolve nested `.localhost` names, add the displayed management/preview hosts to `/etc/hosts` or configure a local wildcard resolver.

Remote setup references the supplied certificate and private-key paths directly. The certificate needs the management hostname and wildcard SAN `*.PREVIEW_DOMAIN`, with more than 24 hours remaining validity; use an unencrypted key protected from group/other access. Management and preview names must be distinct and non-nested. Example: `pair.example.com` and `apps.example.com`. Keep the renewal paths stable and reload nginx after renewal:

```sh
sudo nginx -t && sudo systemctl reload nginx
```

Free public certificates are available from [Let's Encrypt](https://letsencrypt.org/getting-started/). A wildcard certificate requires [DNS-01 validation](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge); an ACME client such as Certbot can obtain one for the management name and wildcard preview name before setup. Configure its successful renewal deploy hook to run `nginx -t && systemctl reload nginx`. The installer does not issue public ACME certificates automatically. Do not use a local mkcert CA for public visitors.

## Unattended configuration

Create a regular JSON file owned by root or the invoking sudo user, mode `0600`. Passwords go in this file, never command-line flags. For example, local mode:

```json
{
  "mode": "local",
  "management_host": "rawpair.localhost",
  "preview_domain": "apps.rawpair.localhost",
  "subnet": "10.231.0.0/16",
  "first_user": {
    "username": "operator",
    "password": "REPLACE_WITH_A_PRIVATE_RANDOM_PASSWORD"
  }
}
```

For remote mode, set `"mode": "remote"`, supply real management/preview domains and add absolute `"certificate"` and `"private_key"` paths. Optional `"database_url": "ecto://USER:PASSWORD@HOST:5432/DATABASE?sslmode=require"` selects a pre-existing database/role instead of creating the local `rawpair` database. Percent-encode URL credentials. Supplied database credentials must permit migrations and `pg_dump`; TLS options are used for backup/connectivity, and `sslmode=require` or `sslmode=verify-full` enables TLS for Phoenix. Use `sslmode=verify-full` to verify the database certificate/hostname, optionally with `sslrootcert=/absolute/path` for a private CA readable by the service account; `require` enables encryption without peer verification. There are no command-line password options. Unknown configuration fields are rejected.

```sh
chmod 600 ./rawpair-setup.json
sudo rawpair setup --config ./rawpair-setup.json
```

Passwords need 12..1024 UTF-8 bytes and usernames 3..40 letters, digits, underscores or hyphens. Repeating unattended setup validates against saved configuration. The first password is retained in the root-only progress file until account creation completes, then removed from that progress file; protect or remove the original input file yourself. Setup configuration and secrets contain database access and need backups and restricted permissions.

## Packages, state and upgrades

| Package | Contents |
| --- | --- |
| `orqos-host` | `/usr/bin/orqos`, `/usr/lib/orqos` helpers, `orqos-host-admin`, systemd unit |
| `rawpair` | Phoenix/ERTS in `/opt/rawpair`, production collaboration in `/opt/rawpair-collaboration`, Go CLI and setup helpers, systemd units |
| `rawpair-native` | Architecture-independent exact RawPair/Orqos dependency pair and supporting services |

Runtime dependencies include PostgreSQL/client, nginx, Node, Python, tmux, ttyd, networking/certificate tools and shared libraries. Package installation creates service identities and installs code; fresh controls stay unconfigured/stopped. Hooks are noninteractive and perform no source builds, image downloads or Docker group changes. Configuration is root owned in `/etc/{rawpair,orqos}`. Setup progress, backups, Orqos ownership and collaboration state live under `/var/lib`, outside payloads; workspace homes remain under `/srv/rawpair`.

Setup uses durable progress and per-installer locks. An interrupted account/database operation resumes using its recorded intent and saved credentials. A retry preserves service secrets, account mappings and network indexes. An existing unrelated account, installation, nginx site or local database/role is refused rather than adopted. For an existing database, select the advanced URL option explicitly.

On upgrade RawPair controls stop, and `/var/lib/rawpair/setup-required` prevents their restart across a reboot. Before migrations, setup saves `/etc/rawpair`, `/etc/orqos`, certificates and a `pg_dump` backup under root-only `/var/lib/rawpair/backups`. Failure to back up or migrate leaves RawPair controls stopped, prints the backup path and asks the operator to fix the cause and rerun setup. Inspect `/var/lib/rawpair/migration.log` for migration failures; it is root-only and may contain database diagnostics. Keep the original backup until the upgrade is accepted. Recovery means restoring appropriate configuration and restoring the database with `pg_restore` after reviewing the failure; automatic database rollback is not promised. `rawpair migrate` uses the same backup-before-migrate behavior and leaves controls stopped until `rawpair setup` validates and starts them.

Orqos upgrades stop only its control daemon while replacing code; existing workspace services remain running. Explicit Orqos package removal stops its daemon and all persisted, ownership-verified workspace services before deleting execution assets, aborting if safe stopping fails. Package removal and purge preserve configuration, databases, homes, collaboration snapshots, dedicated accounts, provisioning journals and workspace ownership records. An operator must deliberately archive/delete data later. Never delete runtime ownership records to silence a package-removal error.

## Legacy migration

Older RawPair packages, manual installs and accounts without the new package's ownership marker are detected before unpacking over their files. Automatic migration is deferred. Back up PostgreSQL, `/etc/{rawpair,orqos}`, `/var/lib/{rawpair,orqos,rawpair-collaboration}` and `/srv/rawpair`. Stop the old deployment and its workspaces explicitly. Prefer a fresh Ubuntu 24.04 host for package setup and a planned restoration of compatible data. For a same-host migration, archive the old service units, code/config paths and identities under an operator-reviewed procedure; keep ownership records with their data. Older uninstall hooks may delete configuration/accounts, so inspect them before removing a legacy package. Do not create new ownership markers to bypass checks. Retain your backups and old binaries until the new installation is verified.

Source installation remains documented in [NATIVE_SETUP.md](NATIVE_SETUP.md) and uses these shared configuration/provisioning helpers with distinct source ownership. Conversion to package management requires an explicit migration.

## Build and release

1. Release Orqos `v0.2.0` first. Its pipeline checks Cargo/tag/lock versions, builds both native architectures and packages helpers alongside the retained binary downloads, validates packages and uploads a draft. Review and publish that release.
2. Update `packaging/compatibility.json` deliberately whenever changing Orqos compatibility. Never substitute its latest release. Set a RawPair `vMAJOR.MINOR.PATCH` tag. The tag supplies the Phoenix, CLI and Debian versions; inconsistent or missing metadata fails packaging.
3. RawPair's workflow builds on fixed GitHub-hosted `ubuntu-24.04` and `ubuntu-24.04-arm` runners with Go 1.24.2, Elixir 1.18.3, OTP 27.3.2 and Node 22.14.0. These are standard public-repository runners; no self-hosted runner is needed. See [GitHub runner documentation](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
4. CI verifies unit tests, package payloads/metadata/permissions, dependency resolution, fresh/repeated unattended setup, two installed workspaces, shared files/editor/terminal, private previews, independent stop, control restarts, coordinated upgrades and data-preserving removal/purge on disposable architecture runners. `packaging/host-smoke.py` and `lifecycle-smoke.py` refuse ordinary hosts. Privileged browser/network acceptance is a CI check, not something package builds silently deploy on the operator's workstation.
5. After both architecture jobs pass, CI assembles the package sets, metapackage, version/artifact manifest, `SHA256SUMS`, bootstrap and GitHub build-provenance attestations, then creates a draft release. It uses repository-scoped `github.token` permissions; no PAT/signing-key service is needed. Review and publish manually. It refuses to overwrite an already-published release.

Local packaging, after the required build toolchains are installed:

```sh
make RAW_VERSION=vX.Y.Z ARCH=amd64
python3 packaging/validate.py dist/*.deb
python3 -m unittest discover -s packaging/tests -v
```

Build each CPU natively on Ubuntu 24.04 for supported runtime ABI compatibility. Local payload validation on another OS does not establish that its binaries run on Ubuntu 24.04. APT hosting, other distributions, automatic ACME and automatic legacy migration remain deferred. See [PACKAGE_HANDOFF.md](PACKAGE_HANDOFF.md) for checks actually run for this implementation.
