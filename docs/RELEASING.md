# Release native RawPair packages

1. Follow the [Orqos release procedure](https://github.com/orqos-project/orqos/blob/main/docs/PACKAGES.md#releases) and release Orqos `v0.2.2` first. Its pipeline checks Cargo/tag/lock versions, builds both native architectures and packages helpers alongside the retained binary downloads, validates packages and uploads a draft. Review and publish that release.
2. Update [`packaging/compatibility.json`](../packaging/compatibility.json) deliberately whenever changing Orqos compatibility. Never substitute its latest release. Set a RawPair `vMAJOR.MINOR.PATCH` tag. The tag supplies the Phoenix, CLI and Debian versions; inconsistent or missing metadata fails packaging.
3. RawPair's workflow builds on fixed GitHub-hosted `ubuntu-24.04` and `ubuntu-24.04-arm` runners with Go 1.24.2, Elixir 1.18.3, OTP 27.3.2 and Node 22.14.0. These are standard public-repository runners; no self-hosted runner is needed. See [GitHub runner documentation](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
4. CI verifies unit tests, package payloads/metadata/permissions, dependency resolution, fresh/repeated unattended setup, two installed workspaces, shared files/editor/terminal, private previews, independent stop, control restarts, coordinated upgrades and data-preserving removal/purge on disposable architecture runners. `packaging/host-smoke.py` and `lifecycle-smoke.py` refuse ordinary hosts. Privileged browser/network acceptance is a CI check, not something package builds silently deploy on the operator's workstation.
5. After both architecture jobs pass, CI assembles the package sets, metapackage, version/artifact manifest, `SHA256SUMS`, bootstrap and GitHub build-provenance attestations, then creates a draft release. It uses repository-scoped `github.token` permissions; no PAT/signing-key service is needed. Review and publish manually. It refuses to overwrite an already-published release.

## Triggering and reviewing the release

The [native package workflow](../.github/workflows/build-and-release-deb.yml) runs when a `v*` tag is pushed. From a reviewed checkout, choose an unused RawPair version and run:

```sh
RAWPAIR_TAG=vX.Y.Z  # replace with the version you are releasing
git tag "$RAWPAIR_TAG"
git push origin "$RAWPAIR_TAG"
```

The tag must contain the reviewed implementation and compatibility manifest. To retry an existing tag, open **Actions → Native Ubuntu packages (draft release) → Run workflow**, select the intended workflow branch, and enter that exact existing tag. The workflow checks out the tag's contents.

Wait for both architecture builds and the release job. Review the draft in [RawPair Releases](https://github.com/rawpair/rawpair/releases):

- Both `amd64` and `arm64` sets contain `rawpair` and the unchanged pinned `orqos-host` packages, plus the `rawpair-native` `all` metapackage.
- `manifest.json` names the intended RawPair and Orqos versions and package filenames; `SHA256SUMS` covers the published assets.
- `install.sh` is present, and package build attestations can be verified through GitHub. Verify Orqos against its original repository.
- Installed acceptance logs cover shared editing/terminal, private previews, independent stop, upgrades and data-preserving removal. Review [validation limits](PACKAGE_HANDOFF.md#validation-limits-and-next-release) and perform the remaining interactive browser/wizard checks before inviting users.

Edit the draft notes for users, including the real tag, a link to its version of [PACKAGES.md](PACKAGES.md), any known release-specific limits and a link to [FIRST_WORKSPACE.md](FIRST_WORKSPACE.md). Remove the draft-review paragraph from the release-notes template when publishing. Publishing is a separate manual action; the workflow leaves the release as a draft and refuses to modify a published release.

## Local packaging

Run from the repository root after installing the [source build prerequisites](NATIVE_SETUP.md#host-prerequisites):

```sh
make RAW_VERSION=vX.Y.Z ARCH=amd64
python3 packaging/validate.py dist/*.deb
python3 -m unittest discover -s packaging/tests -v
```

Build each CPU natively on Ubuntu 24.04 for supported runtime ABI compatibility. Local payload validation on another OS does not establish that its binaries run on Ubuntu 24.04. APT hosting, other distributions, automatic ACME and automatic legacy migration remain deferred. See [PACKAGE_HANDOFF.md](PACKAGE_HANDOFF.md) for checks actually run for this implementation.
