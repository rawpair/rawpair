# RawPair administration CLI

The native packages install `rawpair` and its `rawpair-cli` alias. Use these commands on the Ubuntu host; collaborators use their browser and do not need the CLI.

| Command | Purpose |
| --- | --- |
| `sudo rawpair setup` | Configure the installation, resume an interruption or finish an upgrade |
| `sudo rawpair setup --config FILE` | Unattended setup with a protected JSON file (`0600`); passwords belong in that file |
| `sudo rawpair doctor` | Read-only checks and actionable errors; exits nonzero if a check fails |
| `sudo rawpair doctor --json` | The same diagnostic results as JSON |
| `sudo rawpair user add` | Prompt securely for a new person's login |
| `sudo rawpair workspace add NAME` | Provision a dedicated account and inventory slot with the next network index |
| `sudo rawpair migrate` | Back up and migrate the database, leaving controls stopped until setup completes |
| `rawpair --version` | Show the installed CLI version |

Adding a login does not grant workspace access: an owner adds the username under **Workspace members**. Adding a slot does not launch a workspace: select it when creating a workspace in the UI, then start it.

Start with [package installation](../docs/PACKAGES.md), then follow [Your first shared workspace](../docs/FIRST_WORKSPACE.md). The package guide also covers TLS, protected JSON fields, retries, diagnostics, backups and upgrade recovery. The source installation supplies an administration wrapper with the same setup/user/workspace/doctor/migrate operations.

## Legacy commands and developer artifacts

`quickStart` and `ensureDeps` are legacy source/Docker helpers. They do not configure the native services. The Go package release derives its version from the RawPair tag; standalone CLI artifact generation is separate from the native three-package installation.

Developers can inspect standalone artifact generation with:

```sh
goreleaser release --snapshot --clean
```
