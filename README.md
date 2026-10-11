# RawPair™

[![Status: Pre-alpha](https://img.shields.io/badge/status-pre--alpha-orange)](#project-status)
[![License: MPL-2.0](https://img.shields.io/github/license/rawpair/rawpair)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/rawpair/rawpair?style=social)](https://github.com/rawpair/rawpair/stargazers)

**A shared editor, a shared terminal, and a place to build together. On your own server.**

RawPair is a self-hosted development environment for pair and mob programming. Open a project in your browser, bring a coworker into the workspace, and work on the same files and terminal session. Run the app you are building and open its HTTPS preview beside the editor.

Use it to work through a bug together, show a teammate around a codebase, or build a small project with friends. Everyone works in the same environment, and the workspace keeps running when a browser disconnects.

[Try RawPair](docs/PACKAGES.md) · [Walk through your first workspace](docs/FIRST_WORKSPACE.md) · [Source installation](docs/NATIVE_SETUP.md)

![RawPair browser workspace](https://github.com/user-attachments/assets/f4c790d9-6db7-47ec-9778-39687755ea93)

## What you can do

- **Edit together.** Share a file in the browser and see each other's changes. Save it to the project's actual filesystem.
- **Use one terminal session.** Run Git commands, tests and development servers together through ttyd and tmux.
- **Keep projects independent.** Native workspaces have separate Unix accounts, resource limits and networks. Two projects can both use port 3000.
- **Show what you are building.** Register an HTTP application and get its own HTTPS preview URL. Keep it private to workspace members or deliberately share that application publicly.
- **Come back to your work.** Disconnecting leaves processes running. Stopping a workspace stops its processes and keeps its files.

Native workspaces run on Linux through [Orqos](https://github.com/orqos-project/orqos). Docker remains a separate backend option.

## Try it

Start with a fresh **Ubuntu 24.04 or 26.04, amd64 or arm64** machine and an ordinary user with sudo access. The package installer installs the runtime dependencies and a matching RawPair/Orqos pair; you do not need a source checkout or build toolchains.

| You want to… | Start here |
| --- | --- |
| Try it in a browser on the same machine | [Local package installation](docs/PACKAGES.md#install-and-open-rawpair) |
| Work with someone on another computer | [Remote setup: DNS and certificates](docs/PACKAGES.md#remote-setup-dns-and-certificates), then the same installer |
| Build from source | [Native source setup](docs/NATIVE_SETUP.md) |
| Use Docker workspaces | [Separate Docker recipe](docs/CONTAINER_SETUP.md) |

**Native release availability:** use a [published release](https://github.com/rawpair/rawpair/releases) containing `install.sh`, `manifest.json`, `SHA256SUMS` and the native `.deb` packages. The package pipeline is implemented; its assets require a reviewed, published release. If those assets are absent, use the source guide. Older CLI-only releases do not provide this installation path.

Ubuntu 26.04 support starts with RawPair **v0.0.3**, paired with Orqos **v0.2.3**. Earlier native releases support Ubuntu 24.04 only. The same packages run on both supported Ubuntu versions.

The [package guide](docs/PACKAGES.md) takes you through downloading the installer, answering the setup prompts, trusting local TLS and opening the login page. RawPair configures Orqos for you.

## Your first session

The [first-workspace walkthrough](docs/FIRST_WORKSPACE.md) gives you a small working demo using the Python already installed with RawPair:

1. Log in and create a workspace in one of the two prepared account slots.
2. Start it, open the shared terminal, and serve a small page on port 3000.
3. Open its private HTTPS preview and edit the page in the browser.
4. Add a teammate, make a change together, and refresh the preview.
5. Try a second workspace on the same port. Stop either one and watch the other keep running.

Once that works, bring your own repository and its development tools. The operator installs host toolchains, or you install tools in the workspace's home; native mode does not download stack images.

## Bring someone along

An operator creates each person's login with `sudo rawpair user add`. A workspace owner adds that username under **Workspace members**, then sends the workspace's management URL. Your teammate opens it in their browser, signs in, and joins the same editor and terminal. There is no client application to install.

Local mode is a first try on one machine. For a coworker on another computer, choose remote setup with server-resolving names and certificates trusted by both browsers. The walkthrough explains [sharing a workspace or just a preview](docs/FIRST_WORKSPACE.md#bring-a-friend-or-coworker).

If RawPair would help your next pairing session, send your teammate this README or the first-workspace guide and pick a small task to try together. [Tell us what worked and what got in your way](https://github.com/rawpair/rawpair/issues).

## Project status

RawPair is **pre-alpha**, intended for one Linux host and people you trust with the workspace. Native execution, collaboration, authentication and previews are implemented. Available automated checks and the remaining live installation/browser checks are recorded in the [package handoff](docs/PACKAGE_HANDOFF.md). Start with a small project you can restore from backup.

Workspace members share a Unix identity, files and processes within that workspace. Native execution shares the host kernel; this is not an isolation service for arbitrary untrusted users. Language installers, automatic public certificate issuance, automatic legacy migration and managed production application hosting are outside the current release.

## Documentation

| Guide | What it covers |
| --- | --- |
| [Install packages](docs/PACKAGES.md) | Download, local/remote setup, TLS, unattended installation, diagnostics, backups and upgrades |
| [First workspace](docs/FIRST_WORKSPACE.md) | A working preview, shared editing and terminal, inviting collaborators, two independent projects |
| [Build from source](docs/NATIVE_SETUP.md) | Toolchains, sibling checkouts, native installation and operating instructions |
| [Docker option](docs/CONTAINER_SETUP.md) | The retained container backend and its authenticated gateway |
| [Administration CLI](cli/README.md) | Installed commands and when to use them |
| [Release procedure](docs/RELEASING.md) | Building the pinned pair, reviewing draft assets and publishing |
| [Delivery evidence](docs/PACKAGE_HANDOFF.md) | Checks actually run and behavior awaiting live validation |

The CLI `quickStart`/`ensureDeps` commands, older compose files and Ansible recipes are legacy container helpers. Start new installations from one of the guides above. Native configuration is generated by setup; [rawpair.env.example](native/rawpair.env.example) is an operator reference.

## Built with

[Phoenix](https://www.phoenixframework.org/) and PostgreSQL provide the application and persistent metadata. [Monaco](https://github.com/microsoft/monaco-editor) and [Yjs](https://github.com/yjs/yjs) provide collaborative editing; [ttyd](https://github.com/tsl0922/ttyd) and [tmux](https://github.com/tmux/tmux) provide the shared terminal. Orqos supervises native execution through systemd, cgroups and network namespaces, with nginx serving the browser gateway.

## License

This project is licensed under the **Mozilla Public License 2.0 (MPL-2.0)**.
If you modify any source files covered by this license, you must make those files available under the same license, but you may combine them with proprietary code in separate files.

See [`LICENSE`](LICENSE) for details.

The RawPair™ name and logo are trademarks of Andrea Mancuso.  
See [TRADEMARK.md](./TRADEMARK.md) for details.

---

## Legal and Ethical Use

RawPair is intended strictly for **authorized, collaborative development** and **educational** purposes.  
Any use of this software to perform unauthorized access, surveillance, or exploitation of remote systems is **forbidden** and may violate applicable laws.

You are solely responsible for how you use this software.

By using RawPair, you agree to comply with all relevant laws and to use the software **only in environments where you have explicit permission**.

This project is licensed under the [Mozilla Public License 2.0](https://www.mozilla.org/MPL/2.0/), which ensures that **any modifications to MPL-licensed files must remain open-source**, while still allowing broader integration with proprietary systems.

---

## Contributing

Try a small project, invite someone to work with you, and share what you learn. [Bug reports, setup feedback and pull requests](https://github.com/rawpair/rawpair/issues) are welcome. Include the RawPair version, installation method and relevant diagnostics, with passwords and tokens removed.
