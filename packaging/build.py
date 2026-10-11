#!/usr/bin/python3
"""Assemble prebuilt native packages. Never invoked by apt or package hooks."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def version(tag):
    if not re.fullmatch(r'v\d+\.\d+\.\d+(?:-[a-zA-Z0-9.]+)?', tag):
        raise ValueError('Use an explicit release tag: vMAJOR.MINOR.PATCH[-prerelease]')
    return tag[1:].replace('-', '~')


def copy(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.is_dir():
        shutil.copytree(source, target)
    else:
        shutil.copy2(source, target)


def package(stage, name, ver, arch, depends, output):
    metadata = stage / 'DEBIAN'
    metadata.mkdir(parents=True, exist_ok=True)
    stage.chmod(0o755)
    metadata.chmod(0o755)
    (metadata / 'control').write_text(
        f'Package: {name}\nVersion: {ver}\nArchitecture: {arch}\n'
        f'Maintainer: RawPair <support@rawpair.com>\nDepends: {depends}\n'
        'Section: devel\nPriority: optional\nHomepage: https://github.com/rawpair/rawpair\n'
        f'Description: RawPair native {"installation" if name.endswith("native") else "collaborative development server"}\n')
    environment = os.environ.copy()
    environment.setdefault('SOURCE_DATE_EPOCH', subprocess.check_output(['git', '-C', str(ROOT), 'log', '-1', '--format=%ct'], text=True).strip())
    subprocess.run(['dpkg-deb', '--root-owner-group', '--build', str(stage),
                    str(output / f'{name}_{ver}_{arch}.deb')], check=True, env=environment)


def build(tag, arch, output, release, cli, collaboration):
    ver = version(tag)
    compatibility = json.loads((ROOT / 'packaging/compatibility.json').read_text())
    if arch not in compatibility['architectures']:
        raise ValueError('Unsupported architecture')
    release_versions = list((release / 'releases').glob('*/rawpair.rel'))
    if len(release_versions) != 1 or f'"{tag[1:]}"' not in release_versions[0].read_text():
        raise ValueError('Phoenix release version differs from the tag; rebuild with RAWPAIR_VERSION')
    for required in [release / 'bin/rawpair', release / 'lib', cli,
                     collaboration / 'node_modules/ws', collaboration / 'node_modules/yjs']:
        if not required.exists():
            raise ValueError(f'Missing build input: {required}')
    for binary in [cli, *release.glob('erts-*/bin/beam.smp')]:
        header = binary.read_bytes()[:20]
        if header[:6] != b'\x7fELF\x02\x01' or int.from_bytes(header[18:20], 'little') != {'amd64': 62, 'arm64': 183}[arch]:
            raise ValueError(f'{binary}: binary architecture differs from package architecture')
    if not list(release.glob('erts-*/bin/beam.smp')) or not list(release.glob('lib/rawpair-*/priv/static/cache_manifest.json')):
        raise ValueError('Release must include ERTS and compiled browser assets')
    cli_version = subprocess.check_output([str(cli.resolve()), '--version'], text=True).strip()
    if cli_version != f'rawpair version {tag[1:]}':
        raise ValueError(f'CLI version differs from tag: {cli_version}')
    output.mkdir(parents=True, exist_ok=True)
    stage = output / f'stage-{arch}'
    if stage.exists():
        shutil.rmtree(stage)
    copy(release, stage / 'opt/rawpair')
    # Releases generate a build-time distribution cookie. Setup supplies a fresh
    # per-installation RELEASE_COOKIE, so never ship the build-generated secret.
    (stage / 'opt/rawpair/releases/COOKIE').unlink(missing_ok=True)
    for name in ('server.mjs', 'package.json', 'package-lock.json', 'node_modules'):
        copy(collaboration / name, stage / 'opt/rawpair-collaboration' / name)
    copy(cli, stage / 'usr/bin/rawpair')
    (stage / 'usr/bin/rawpair-cli').symlink_to('rawpair')
    for name in ('setup.py', 'configure.py', 'nginx.conf.template'):
        copy(ROOT / 'native' / name, stage / 'usr/lib/rawpair' / name)
    copy(ROOT / 'packaging/compatibility.json', stage / 'usr/lib/rawpair/compatibility.json')
    (stage / 'usr/lib/rawpair/version').write_text(tag[1:] + '\n')
    for name in ('rawpair-host.service', 'rawpair-collaboration.service'):
        copy(ROOT / 'native' / name, stage / 'usr/lib/systemd/system' / name)
    for name in ('preinst', 'postinst', 'prerm', 'postrm'):
        copy(ROOT / 'packaging' / (name + '.sh'), stage / 'DEBIAN' / name)
        (stage / 'DEBIAN' / name).chmod(0o755)
    for path in stage.rglob('*'):
        if path.is_symlink():
            continue
        if path.name in ('.env', 'rawpair.env', 'host.env', 'rootCA-key.pem', 'COOKIE'):
            raise ValueError(f'Secret file in payload: {path}')
        path.chmod(path.stat().st_mode & ~0o022)
    package(stage, 'rawpair', ver, arch,
            'nodejs (>= 18), python3, postgresql-client, nginx, openssl, ca-certificates, '
            'libc6 (>= 2.39), libssl3t64, libstdc++6, libgcc-s1, libtinfo6, libncurses6, zlib1g, '
            'adduser, util-linux, curl', output)
    meta = output / 'stage-meta'
    if meta.exists():
        shutil.rmtree(meta)
    package(meta, 'rawpair-native', ver, 'all',
            f'rawpair (= {ver}), orqos-host (= {compatibility["orqos_version"]}), '
            'postgresql, nginx, mkcert, libnss3-tools, git', output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--arch', required=True, choices=['amd64', 'arm64'])
    parser.add_argument('--output', type=Path, default=ROOT / 'dist')
    parser.add_argument('--release', type=Path, default=ROOT / 'phoenix-app/_build/prod/rel/rawpair')
    parser.add_argument('--cli', type=Path, default=ROOT / 'dist/rawpair')
    parser.add_argument('--collaboration', type=Path, default=ROOT / 'yjs-server')
    args = parser.parse_args()
    build(args.tag, args.arch, args.output, args.release, args.cli, args.collaboration)
