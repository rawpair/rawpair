#!/usr/bin/python3
"""Validate binary packages without installing or executing their payloads."""
import argparse
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile


def validate(path):
    fields = subprocess.check_output(['dpkg-deb', '-f', str(path), 'Package', 'Version', 'Architecture', 'Depends'], text=True)
    metadata = dict(line.split(': ', 1) for line in fields.splitlines())
    name, arch = metadata['Package'], metadata['Architecture']
    assert name in ('rawpair', 'orqos-host', 'rawpair-native')
    assert arch == 'all' if name == 'rawpair-native' else arch in ('amd64', 'arm64')
    assert re.fullmatch(r'\d+\.\d+\.\d+(?:~[a-zA-Z0-9.]+)?', metadata['Version'])
    depends = metadata['Depends']
    assert 'docker' not in depends and 'cargo' not in depends and 'elixir' not in depends
    if name == 'rawpair-native':
        assert re.search(r'rawpair \(= [^)]+\)', depends)
        assert re.search(r'orqos-host \(= [^)]+\)', depends)
    if name == 'rawpair':
        assert all(x in depends for x in ('nodejs', 'python3', 'nginx', 'postgresql-client', 'libssl3t64'))
    if name == 'orqos-host':
        assert all(x in depends for x in ('systemd', 'nftables', 'iproute2', 'tmux', 'ttyd'))
    with tempfile.TemporaryDirectory() as temporary:
        target = Path(temporary)
        data = target / 'payload.tar'
        with data.open('wb') as stream:
            subprocess.run(['dpkg-deb', '--fsys-tarfile', str(path)], stdout=stream, check=True)
        with tarfile.open(data) as archive:
            members = archive.getmembers()
            files = {x.name.removeprefix('./'): x for x in members if not x.isdir()}
            for member in members:
                assert member.uid == member.gid == 0, member.name
                if not member.issym():
                    assert not member.mode & 0o022, member.name
                assert not member.name.startswith(('./var/', './srv/')), member.name
                assert Path(member.name).name not in ('rawpair.env', 'host.env', '.env', 'rootCA-key.pem', 'COOKIE')
            if name == 'rawpair':
                assert all(x in files for x in ('usr/bin/rawpair', 'usr/bin/rawpair-cli', 'usr/lib/rawpair/setup.py',
                                               'usr/lib/rawpair/configure.py', 'usr/lib/rawpair/compatibility.json',
                                               'usr/lib/systemd/system/rawpair-host.service',
                                               'etc/needrestart/conf.d/rawpair.conf',
                                               'opt/rawpair-collaboration/server.mjs'))
                assert any(re.fullmatch(r'opt/rawpair/erts-[^/]+/bin/beam.smp', x) for x in files)
                assert any(x.endswith('/priv/static/cache_manifest.json') for x in files)
                assert any(x.startswith('opt/rawpair-collaboration/node_modules/ws/') for x in files)
            if name == 'orqos-host':
                assert all(x in files for x in ('usr/bin/orqos', 'usr/bin/orqos-host-admin', 'usr/lib/orqos/admin.py',
                                               'usr/lib/orqos/host.py', 'usr/lib/orqos/files.py', 'usr/lib/orqos/workspace.py'))
            executable = 'usr/bin/rawpair' if name == 'rawpair' else 'usr/bin/orqos'
            if name != 'rawpair-native':
                header = archive.extractfile(files[executable]).read(20)
                assert header[:6] == b'\x7fELF\x02\x01'
                assert int.from_bytes(header[18:20], 'little') == {'amd64': 62, 'arm64': 183}[arch]
        subprocess.run(['dpkg-deb', '-e', str(path), str(target / 'control')], check=True)
        for script in ('preinst', 'postinst', 'prerm', 'postrm'):
            source = target / 'control' / script
            if source.exists():
                subprocess.run(['sh', '-n', str(source)], check=True)
                assert not re.search(r'\b(cargo|mix|npm|docker|curl|wget|git)\s', source.read_text())
    print(f'Validated {path.name}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('packages', nargs='+', type=Path)
    for path in parser.parse_args().packages:
        validate(path)
