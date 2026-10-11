# RawPair administration CLI

The native Ubuntu packages install `rawpair` and the `rawpair-cli` alias. Start with `sudo rawpair setup`, or `sudo rawpair setup --config FILE` for protected JSON input. Use `sudo rawpair doctor [--json]`, `sudo rawpair workspace add NAME`, `sudo rawpair user add` and `sudo rawpair migrate`. See [package setup](../docs/PACKAGES.md) for configuration, TLS, retries, backups and upgrade recovery.

The commands below are legacy source/Docker helpers. They do not configure the current native packages.

### Test artifact generation through goreleaser

`goreleaser release --snapshot --clean`