# Install RawPair and open your first workspace

This guide takes a fresh Ubuntu host from package download to the login page. Then try a small working page and invite someone into the same editor and terminal with the [first-workspace walkthrough](FIRST_WORKSPACE.md).

The native packages include Phoenix/ERTS, browser assets, collaboration dependencies and a matching Orqos. You do not need a source checkout, Go, Rust, Erlang, Elixir or build toolchains, and you do not need to install Orqos separately.

Jump to [installation](#install-and-open-rawpair), [remote access](#remote-setup-dns-and-certificates), [troubleshooting](#if-something-does-not-work), [unattended setup](#unattended-configuration) or [upgrades and recovery](#packages-state-and-upgrades).

**Choose a published native release.** Open [RawPair Releases](https://github.com/rawpair/rawpair/releases) and look for `install.sh`, `manifest.json`, `SHA256SUMS` and Ubuntu `.deb` assets. The package pipeline is implemented; these assets become available when the corresponding releases are built, reviewed and published. If they are absent, use [source setup](NATIVE_SETUP.md). Older CLI-only releases are not compatible with this guide.

## What you need

- A fresh Ubuntu **24.04 or 26.04** host, **amd64** or **arm64**, booted with systemd and cgroup v2. A normal Ubuntu installation or VM is the intended host.
- An ordinary user with sudo access, internet access to GitHub and Ubuntu package repositories, and a browser.
- Available TCP ports **443, 4000, 1234 and 9080**. Setup refuses conflicting listeners; use a fresh host if you already run another deployment.
- A private IPv4 `/16` that does not overlap LAN/VPN routes. Setup defaults to `10.231.0.0/16`, checks it, and enables IPv4 forwarding. Existing forwarding firewalls may need an outbound/reply rule for this range; setup preserves them.

| Installation mode | Use it for | Prepare before setup |
| --- | --- | --- |
| **Local** | A first try in a browser on the deployment machine | No domain purchase or supplied certificate; setup generates local TLS with mkcert |
| **Remote** | Friends/coworkers on other computers, including a LAN server | Management DNS, wildcard preview DNS, reachable HTTPS and a matching certificate/key; [details below](#remote-setup-dns-and-certificates) |

The current release is for people you trust with a shared workspace. Use [the Docker recipe](CONTAINER_SETUP.md) if you want the separate container backend. Existing manual/legacy installations need the [migration procedure](#legacy-migration).

Ubuntu 26.04 requires RawPair **v0.0.3 or later** with explicit `ubuntu_versions` compatibility metadata. The installer checks the selected release before downloading packages or invoking apt. Legacy manifests declare only their `ubuntu` version; older releases remain Ubuntu 24.04-only. Packages are built on Ubuntu 24.04 and the exact same files are tested on both Ubuntu versions for each CPU.

## Install and open RawPair

Run the following in your ordinary user's terminal on the Ubuntu host. Install the small bootstrap prerequisites first:

```sh
sudo apt update
sudo apt install -y ca-certificates curl python3
```

Ubuntu supplies Bash, `dpkg` and `sha256sum`. The installer gets the remaining runtime dependencies through apt. In a new directory, replace `vX.Y.Z` with the exact native release tag you chose:

```sh
mkdir -p ~/rawpair-install
cd ~/rawpair-install
RAWPAIR_TAG=vX.Y.Z
curl --fail --show-error --location --proto '=https' \
  --output install.sh \
  "https://github.com/rawpair/rawpair/releases/download/$RAWPAIR_TAG/install.sh"
less install.sh
bash install.sh --version "$RAWPAIR_TAG"
```

`less` lets you inspect the script before running it; press `q` to exit. If it is not installed, open the file in your text editor. The installer detects Ubuntu/CPU, downloads the three matching packages from that tag, verifies SHA256 checksums, installs them together through apt and runs `sudo rawpair setup`. Your sudo password may be requested.

For a first local installation, answer the wizard as follows:

| Prompt | First local try |
| --- | --- |
| Installation mode | `local` |
| Management hostname | Accept `rawpair.localhost` |
| Preview domain | Accept `apps.rawpair.localhost` |
| Private subnet | Accept `10.231.0.0/16` if the check passes; choose another private `/16` if it overlaps |
| Database | `local` |
| First login | Choose your own username and a password of at least 12 bytes; the password is entered without echo |
| Install local CA trust | Read the trust explanation. Enter `yes` to approve system/browser trust changes, or accept `no` and import the CA manually before browsing |

Setup generates local TLS as the invoking ordinary user, creates the database and service secrets, prepares `project-a` and `project-b`, runs migrations and starts the services after validation. Installing the local CA into system/browser trust requires your separate approval; sudo authentication alone does not approve it. A slot is a dedicated account/project directory available to a workspace; it does not launch a workspace until you create and start one in the UI.

When setup prints **Login: https://rawpair.localhost**, open it in a browser on this machine and sign in with the account you just created. Run `sudo rawpair doctor` to check the installation, then follow [Your first shared workspace](FIRST_WORKSPACE.md) to run a page, open its private preview and edit it together.

If setup is interrupted, run `sudo rawpair setup` to resume using saved configuration. It preserves service secrets and completed provisioning. For errors, use [troubleshooting](#if-something-does-not-work).

## Installer options and daily commands

Use the same downloaded installer and chosen tag:

```sh
bash install.sh --version "$RAWPAIR_TAG" --download-only --output ./downloads
bash install.sh --version "$RAWPAIR_TAG" --no-setup
```

`--download-only` verifies and saves assets without apt, sudo or setup; each invocation prints its private download directory. `--no-setup` installs packages and leaves RawPair controls stopped until setup completes. Omitting `--version` resolves the latest published stable RawPair tag once, then uses that tag for all asset downloads; choose an explicit native tag when older stable releases lack packages. Orqos always comes from the pinned compatibility manifest, never its latest release.

| Command | When to use it |
| --- | --- |
| `sudo rawpair setup` | Finish/resume setup, validate an existing installation, or complete a package upgrade |
| `sudo rawpair doctor` | Run read-only checks with actionable errors; failures give a nonzero exit status |
| `sudo rawpair doctor --json` | Get the same diagnostics as JSON |
| `sudo rawpair user add` | Create an individual login, with a secure password prompt; owners then grant workspace membership |
| `sudo rawpair workspace add project-c` | Add a dedicated account slot; create a workspace using it in the UI |
| `sudo rawpair migrate` | Back up and run database migrations; controls stay stopped until `rawpair setup` validates and starts them |

`rawpair-cli` is an alias for the installed `rawpair` command. `quickStart` and `ensureDeps` are legacy source/Docker helpers.

To upgrade, download `install.sh` from the desired newer native release and rerun the install command with its tag. This upgrades the exact pair together and reruns setup with preserved configuration. Read [backup and recovery behavior](#packages-state-and-upgrades) before upgrading; avoid upgrading Orqos independently of the tested pair.

## Manual equivalent

Here `VERSION`, `ORQOS_VERSION` and `ARCH` are placeholders: use the literal filenames from the chosen release (`amd64` or `arm64` for the CPU and `all` for the metapackage). You can check your CPU with `dpkg --print-architecture`.

Download `manifest.json`, `SHA256SUMS`, `rawpair_VERSION_ARCH.deb`, `orqos-host_ORQOS_VERSION_ARCH.deb`, and `rawpair-native_VERSION_all.deb` from one RawPair release. Use the versions/architecture named in its manifest. In a directory containing only that matching package set:

```sh
sha256sum --check --ignore-missing SHA256SUMS &&
  sudo apt update &&
  sudo apt install ./rawpair_VERSION_ARCH.deb ./orqos-host_ORQOS_VERSION_ARCH.deb ./rawpair-native_VERSION_all.deb &&
  sudo rawpair setup
```

All downloaded package entries must report `OK`. This is checksum verification, not signature verification. The installer trusts checksums delivered by HTTPS from the same GitHub release. Optional GitHub build-provenance verification is separate:

```sh
gh attestation verify rawpair_VERSION_ARCH.deb --repo rawpair/rawpair
gh attestation verify orqos-host_ORQOS_VERSION_ARCH.deb --repo orqos-project/orqos
```

RawPair redistributes Orqos packages unchanged and verifies their original Orqos repository attestations when assembling a release.

## Local TLS and browser trust

`sudo rawpair setup` offers local or remote installation, PostgreSQL defaults or an existing database URL, private subnet selection and a secure first-login prompt. It checks the platform, dependencies, protected installation ownership, port conflicts, routing overlap, certificate expiry/hostname/wildcard/key agreement, nginx syntax and service readiness. Overlapping routes are refused; choose another private /16 in the wizard. Two dedicated slots, `project-a` and `project-b`, receive separate accounts, project homes, network indexes and inventory resource ceilings. A slot is available for creating a workspace in the UI; provisioning alone does not launch a workspace.

Local defaults are `https://rawpair.localhost` and `*.apps.rawpair.localhost`. nginx binds HTTPS only to `127.0.0.1` and `::1` in local mode. Setup generates certificates as the invoking ordinary user, retaining that user's local CA. Before changing trust stores, interactive setup explains that installing a CA changes system and available browser trust and that the CA can certify any hostname, not just RawPair. Keep its private key protected. The prompt defaults to **no**: setup leaves trust stores unchanged and prints the CA path for manual import. Enter **yes** to approve `mkcert -install` and the current Chromium-store import. Trust installation may also ask for your sudo password; that authentication is separate from this decision.

Approval applies only to the current setup invocation and is not stored as permanent consent. Interactive retries ask again; declining does not remove trust you previously approved or imported yourself. Noninteractive setup leaves trust unchanged unless its protected config explicitly requests installation. Setup copies only the leaf certificate/key to root-owned `/etc/rawpair/tls`; it never copies the CA private key into service configuration. Repeated setup preserves the leaf certificate and service secrets.

Restart Chrome/Chromium after an approved trust installation so it reloads certificate trust. Recent Chromium versions use `~/.local/share/pki/nssdb`; with your approval, setup imports the local CA there when that database exists, because Ubuntu's mkcert 1.4.4 searches the older `~/.pki/nssdb` location. If the browser has never been opened, open it once and rerun setup, or import the printed `rootCA.pem` through the browser's certificate settings. See [Chromium's Linux certificate documentation](https://chromium.googlesource.com/chromium/src/+/main/docs/linux/cert_management.md). Do not bypass certificate warnings for each preview hostname.

For root-only/headless invocation, setup prints the CA path and leaves browser trust to the client operator. Copy only `rootCA.pem` to each client and import it into the OS/browser's trusted CAs, or run `CAROOT=/path/containing/rootCA.pem mkcert -install` there. Never distribute `rootCA-key.pem`. For a local server on another machine, use remote mode and names resolving to that machine rather than `.localhost`, which resolves to the client. If a local browser/resolver does not resolve nested `.localhost` names, add the displayed management/preview hosts to `/etc/hosts` or configure a local wildcard resolver.

## Remote setup: DNS and certificates

For a friend or coworker to join from another computer, prepare these before running the installer and choose `remote` in the wizard:

1. Choose separate, non-nested domains, for example `pair.example.com` for management and `apps.example.com` for previews.
2. Point `pair.example.com` and `*.apps.example.com` at the server's reachable address using your public or LAN DNS. Each generated preview hostname must resolve there. Add IPv6 DNS only if the server is reachable over IPv6.
3. Allow inbound TCP **443** to this host through the relevant firewall/router. Keep Orqos/Phoenix/collaboration ports **9080, 4000 and 1234** private. Existing firewall forwarding policy must also allow workspace outbound traffic and established replies.
4. Obtain a PEM certificate/full chain covering `pair.example.com` and `*.apps.example.com`, plus its matching unencrypted private key. Keep the key protected from group/other access (`0600`) and provide absolute paths on the server. For a private LAN CA, trust it on every participant's client first.
5. Run setup, enter the management domain and preview **base domain** (`apps.example.com`, without `*.`), then the certificate/key paths. Keep the local database default unless you have a pre-existing database to supply.

Setup prints your management login URL. Open it from both computers, then [create a workspace and add your collaborator](FIRST_WORKSPACE.md#bring-a-friend-or-coworker). Remote mode makes nginx listen on the host's HTTPS interfaces; DNS/firewall access remains the operator's responsibility.

Remote setup references the supplied certificate and private-key paths directly. The certificate needs the management hostname and wildcard SAN `*.PREVIEW_DOMAIN`, with more than 24 hours remaining validity; use an unencrypted key protected from group/other access. Management and preview names must be distinct and non-nested. Example: `pair.example.com` and `apps.example.com`. Keep the renewal paths stable and reload nginx after renewal:

```sh
sudo nginx -t && sudo systemctl reload nginx
```

Free public certificates are available from [Let's Encrypt](https://letsencrypt.org/getting-started/). A wildcard certificate requires [DNS-01 validation](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge); an ACME client such as Certbot can obtain one for the management name and wildcard preview name before setup. Configure its successful renewal deploy hook to run `nginx -t && systemctl reload nginx`. The installer does not issue public ACME certificates automatically. Do not use a local mkcert CA for public visitors.

## If something does not work

Start with these read-only checks on the host:

```sh
sudo rawpair doctor
sudo systemctl status rawpair-host rawpair-collaboration orqos-host nginx --no-pager
sudo journalctl -u rawpair-host -u rawpair-collaboration -u orqos-host -n 100 --no-pager
```

| Symptom | Next step |
| --- | --- |
| Release download returns 404 | Check the tag and native assets on [Releases](https://github.com/rawpair/rawpair/releases). A draft, unpublished partner or older CLI-only release cannot supply this package set. |
| Browser cannot reach `.localhost` from another computer | Use remote mode with server-resolving DNS; `.localhost` refers to that client's machine and local mode listens only on loopback. |
| Local certificate warning | Read [local TLS trust](#local-tls-and-browser-trust). Import only the printed `rootCA.pem` on the affected client; restart the browser if needed. |
| Setup reports a port or subnet conflict | Stop/reconfigure the conflicting service before retrying, or choose another non-overlapping private `/16` when prompted. Keep existing firewall/VPN rules. |
| Setup reports an unmanaged installation/account | Follow [legacy migration](#legacy-migration); do not delete ownership records or create markers to bypass the check. |
| Preview returns an upstream error | Start the workspace and its development server; confirm the registered port, choose **Check connection**, and inspect the workspace's error/unit logs. |
| Files created in the terminal are missing in the editor | Choose **Refresh files**. For an already shared file changed by Git/terminal, use confirmed **Reload from disk**; editor files must be supported UTF-8 text. |
| Workspace cannot reach the internet | Check public IPv4 DNS and the host's forwarding firewall rules for the configured subnet. Never flush a shared firewall. |
| Upgrade/migration fails and controls stay stopped | Retain the backup, inspect the protected migration log, fix the cause and rerun setup; see [recovery](#packages-state-and-upgrades). |

For a failed workspace start, its management page shows the runtime error. The unit name in Orqos's observation selects `sudo journalctl -u UNIT_NAME` for that workspace. A reboot leaves workspaces stopped; use **Start / reconnect** and rerun development servers.

If you need help, [open an issue](https://github.com/rawpair/rawpair/issues) with `rawpair --version`, your Ubuntu/CPU, installation method and relevant diagnostics. Remove passwords, tokens, database URLs and private keys before sharing logs or configuration.

## Unattended configuration

Create a regular JSON file owned by root or the invoking sudo user, mode `0600`. Passwords go in this file, never command-line flags. For example, local mode:

```json
{
  "mode": "local",
  "trust_local_ca": false,
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

`trust_local_ca` is a local-mode boolean and defaults to `false` when omitted. Set it to `true` only to deliberately approve changing system/browser CA trust for this invocation, and run setup with sudo from the ordinary browser user. It is removed before configuration is saved, so a later resume without that config does not silently reuse approval. Omit this local-only field from remote configs. Root-only/headless setup prints the CA path for client-side manual import.

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

Orqos upgrades stop only its control daemon while replacing code; existing workspace services remain running. The RawPair package supplies `/etc/needrestart/conf.d/rawpair.conf` so Ubuntu's `needrestart` lists affected workspace services for maintenance without automatically restarting them. Plan a workspace stop/start yourself when applying runtime or system-library changes; an operator restart or host reboot still ends running processes. Explicit Orqos package removal stops its daemon and all persisted, ownership-verified workspace services before deleting execution assets, aborting if safe stopping fails. Package removal and purge preserve configuration, databases, homes, collaboration snapshots, dedicated accounts, provisioning journals and workspace ownership records. An operator must deliberately archive/delete data later. Never delete runtime ownership records to silence a package-removal error.

## Legacy migration

Older RawPair packages, manual installs and accounts without the new package's ownership marker are detected before unpacking over their files. Automatic migration is deferred. Back up PostgreSQL, `/etc/{rawpair,orqos}`, `/var/lib/{rawpair,orqos,rawpair-collaboration}` and `/srv/rawpair`. Stop the old deployment and its workspaces explicitly. Prefer a fresh Ubuntu 24.04 or 26.04 host for package setup and a planned restoration of compatible data. For a same-host migration, archive the old service units, code/config paths and identities under an operator-reviewed procedure; keep ownership records with their data. Older uninstall hooks may delete configuration/accounts, so inspect them before removing a legacy package. Do not create new ownership markers to bypass checks. Retain your backups and old binaries until the new installation is verified.

Source installation remains documented in [NATIVE_SETUP.md](NATIVE_SETUP.md) and uses these shared configuration/provisioning helpers with distinct source ownership. Conversion to package management requires an explicit migration.

## For maintainers

Package users do not need to build either repository. Maintainers should follow [RELEASING.md](RELEASING.md) for the pinned Orqos release order, tag/workflow commands, draft review and publication. [PACKAGE_HANDOFF.md](PACKAGE_HANDOFF.md) records which checks have actually run.
