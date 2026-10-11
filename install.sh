#!/usr/bin/env bash
# Download one immutable RawPair release; installation never builds source.
set -euo pipefail
version=''
download_only=false
no_setup=false
output=$PWD
usage() { echo 'Usage: install.sh [--version vX.Y.Z] [--download-only] [--no-setup] [--output DIR]'; }
while (($#)); do
  case "$1" in
    --version) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; version=$2; shift 2 ;;
    --output) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; output=$2; shift 2 ;;
    --download-only) download_only=true; shift ;;
    --no-setup) no_setup=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
for command in curl python3 sha256sum dpkg; do
  command -v "$command" >/dev/null || { echo "Install prerequisite: $command" >&2; exit 1; }
done
# Reading this file does not execute its shell contents.
os=$(python3 -c 'import shlex; d=dict(line.rstrip().split("=",1) for line in open("/etc/os-release") if "=" in line); print(shlex.split(d.get("ID", ""))[0]+":"+shlex.split(d.get("VERSION_ID", ""))[0])')
[[ $os == ubuntu:24.04 ]] || { echo 'Supported OS: Ubuntu 24.04' >&2; exit 1; }
arch=$(dpkg --print-architecture)
[[ $arch == amd64 || $arch == arm64 ]] || { echo "Unsupported architecture: $arch" >&2; exit 1; }
repository=rawpair/rawpair
# Resolve latest once. Every asset URL below uses the resolved immutable tag.
if [[ -z $version ]]; then
  version=$(curl --fail --silent --show-error --location --proto '=https' "https://api.github.com/repos/$repository/releases/latest" |
    python3 -c 'import json,sys; r=json.load(sys.stdin); assert not r["draft"] and not r["prerelease"]; print(r["tag_name"])')
fi
[[ $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]] || { echo 'Invalid release version' >&2; exit 1; }
mkdir -p -- "$output"
# Keep download verification in a private directory, even when invoked as root.
download=$(mktemp -d -- "$output/rawpair-$version-$arch.XXXXXX")
base="https://github.com/$repository/releases/download/$version"
fetch() { curl --fail --silent --show-error --location --proto '=https' --output "$download/$1" "$base/$1"; }
fetch SHA256SUMS
fetch manifest.json
# Parse only strict sha256 entries, then verify the manifest before trusting its filenames.
python3 - "$download" <<'PY'
from pathlib import Path
import hashlib, re, sys
root = Path(sys.argv[1])
sums = {}
for line in (root / 'SHA256SUMS').read_text().splitlines():
    match = re.fullmatch(r'([0-9a-f]{64})  ([a-zA-Z0-9_.~-]+)', line)
    if not match or match[2] in sums:
        raise SystemExit('Invalid or duplicate checksum entry')
    sums[match[2]] = match[1]
if hashlib.sha256((root / 'manifest.json').read_bytes()).hexdigest() != sums.get('manifest.json'):
    raise SystemExit('Manifest checksum mismatch')
PY
mapfile -t packages < <(python3 - "$download/manifest.json" "$version" "$arch" <<'PY'
import json, re, sys
manifest = json.load(open(sys.argv[1]))
tag, arch = sys.argv[2:]
assert manifest['schema'] == 1 and manifest['rawpair_tag'] == tag and manifest['ubuntu'] == '24.04'
ver = tag[1:].replace('-', '~')
expected = [f'rawpair_{ver}_{arch}.deb', f'orqos-host_{manifest["orqos_version"]}_{arch}.deb', f'rawpair-native_{ver}_all.deb']
assert all(re.fullmatch(r'[a-zA-Z0-9_.~-]+', name) for name in expected)
assert manifest['packages'][arch] == expected
print('\n'.join(expected))
PY
)
[[ ${#packages[@]} == 3 ]] || { echo 'Invalid or incompatible release manifest' >&2; exit 1; }
for package in "${packages[@]}"; do fetch "$package"; done
python3 - "$download" "${packages[@]}" <<'PY'
from pathlib import Path
import hashlib, sys
root = Path(sys.argv[1])
sums = dict((line.split('  ')[1], line.split('  ')[0]) for line in (root / 'SHA256SUMS').read_text().splitlines())
for name in sys.argv[2:]:
    digest = hashlib.sha256((root / name).read_bytes()).hexdigest()
    if digest != sums.get(name):
        raise SystemExit('Package checksum mismatch: ' + name)
PY
printf 'Verified %s (%s), downloaded to %s\n' "$version" "$arch" "$download"
if $download_only; then exit 0; fi
privileged=()
if [[ $EUID != 0 ]]; then privileged=(sudo); fi
paths=()
for package in "${packages[@]}"; do paths+=("$(realpath -- "$download/$package")"); done
# Refresh the dependency index, then resolve all three packages as one transaction.
"${privileged[@]}" apt-get update
"${privileged[@]}" apt-get install -y "${paths[@]}"
if ! $no_setup; then "${privileged[@]}" rawpair setup; fi
