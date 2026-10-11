#!/usr/bin/python3
"""Fetch a pinned Orqos package or assemble a verified release asset set."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
from urllib.request import Request, urlopen

from build import ROOT, version


def fetch(url):
    with urlopen(Request(url, headers={'User-Agent': 'RawPair-release-builder'}), timeout=120) as response:
        return response.read()


def checksums(text):
    result = {}
    for line in text.splitlines():
        match = re.fullmatch(r'([0-9a-f]{64})  ([a-zA-Z0-9_.~-]+)', line)
        if not match or match[2] in result:
            raise ValueError('Invalid SHA256SUMS')
        result[match[2]] = match[1]
    return result


def validate_deb(path, name, ver, arch):
    for field, expected in [('Package', name), ('Version', ver), ('Architecture', arch)]:
        actual = subprocess.check_output(['dpkg-deb', '-f', str(path), field], text=True).strip()
        if actual != expected:
            raise ValueError(f'{path.name}: {field} expected {expected}, got {actual}')


def orqos(arch, output):
    compatibility = json.loads((ROOT / 'packaging/compatibility.json').read_text())
    tag, ver = compatibility['orqos_tag'], compatibility['orqos_version']
    if version(tag) != ver:
        raise ValueError('Orqos tag/version mismatch in compatibility manifest')
    repository = compatibility['orqos_repository']
    base = f'https://github.com/{repository}/releases/download/{tag}'
    sums = checksums(fetch(base + '/SHA256SUMS').decode())
    name = f'orqos-host_{ver}_{arch}.deb'
    payload = fetch(base + '/' + name)
    if hashlib.sha256(payload).hexdigest() != sums.get(name):
        raise ValueError('Orqos checksum mismatch')
    output.mkdir(parents=True, exist_ok=True)
    target = output / name
    target.write_bytes(payload)
    validate_deb(target, 'orqos-host', ver, arch)
    # Verify the original repository's build provenance as well as its checksum.
    subprocess.run(['gh', 'attestation', 'verify', str(target), '--repo', repository], check=True)


def assemble(tag, output):
    ver = version(tag)
    compatibility = json.loads((ROOT / 'packaging/compatibility.json').read_text())
    packages = {}
    for arch in compatibility['architectures']:
        names = [f'rawpair_{ver}_{arch}.deb', f'orqos-host_{compatibility["orqos_version"]}_{arch}.deb', f'rawpair-native_{ver}_all.deb']
        for name, package, expected_version, expected_arch in zip(names, ['rawpair', 'orqos-host', 'rawpair-native'],
                                                               [ver, compatibility['orqos_version'], ver], [arch, arch, 'all']):
            validate_deb(output / name, package, expected_version, expected_arch)
        packages[arch] = names
    shutil.copy2(ROOT / 'install.sh', output / 'install.sh')
    artifacts = [*sorted(output.glob('*.deb')), output / 'install.sh']
    manifest = dict(compatibility, rawpair_tag=tag, rawpair_version=ver, packages=packages,
                    artifacts=[{'name': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()} for path in artifacts])
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    files = sorted([*output.glob('*.deb'), output / 'manifest.json', output / 'install.sh'])
    (output / 'SHA256SUMS').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.name + '\n' for p in files))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    download = commands.add_parser('orqos')
    download.add_argument('--arch', required=True, choices=['amd64', 'arm64'])
    download.add_argument('--output', type=Path, required=True)
    release = commands.add_parser('assemble')
    release.add_argument('--tag', required=True)
    release.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.command == 'orqos':
        orqos(args.arch, args.output)
    else:
        assemble(args.tag, args.output)
