#!/usr/bin/python3
"""Exercise coordinated upgrades and data preservation on the disposable CI host."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

sys.path.insert(0, '/usr/lib/rawpair')
import setup


def run(*args):
    subprocess.run(args, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--dist', type=Path, required=True)
    args = parser.parse_args()
    assert os.geteuid() == 0 and os.environ.get('GITHUB_ACTIONS') == 'true', 'Disposable CI host only'
    original = Path('/etc/rawpair/rawpair.env').read_bytes()
    inventory = Path('/etc/orqos/host.json').read_bytes()
    records = {p.name: json.loads(p.read_text()) for p in Path('/var/lib/orqos/host').glob('*.json')}
    running = next(record for record in records.values() if record['slot'] == 'project-b')
    workspace_pid = subprocess.check_output(['systemctl', 'show', '-p', 'MainPID', '--value', running['unit']], text=True).strip()
    assert int(workspace_pid) > 0
    orqos_version = json.loads(Path('/usr/lib/rawpair/compatibility.json').read_text())['orqos_version']
    current = args.tag[1:].replace('-', '~')
    upgrade = current + '+ci1'
    # Repack the exact binaries at a later Debian version to exercise dpkg upgrade,
    # preserved config, backup-before-migrate, and the setup-required reboot gate.
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        packages = []
        for source in args.dist.glob('*.deb'):
            destination = root / source.stem
            run('dpkg-deb', '-R', str(source), str(destination))
            control = destination / 'DEBIAN/control'
            text = control.read_text()
            name = subprocess.check_output(['dpkg-deb', '-f', str(source), 'Package'], text=True).strip()
            if name in ('rawpair', 'rawpair-native'):
                text = text.replace('Version: ' + current, 'Version: ' + upgrade).replace('rawpair (= ' + current + ')', 'rawpair (= ' + upgrade + ')')
            else:
                # Upgrade execution assets too; pair metadata pins the repacked version.
                text = text.replace('Version: ' + orqos_version, 'Version: ' + orqos_version + '+ci1')
            if name == 'rawpair-native':
                text = text.replace('orqos-host (= ' + orqos_version + ')', 'orqos-host (= ' + orqos_version + '+ci1)')
            control.write_text(text)
            if name == 'rawpair':
                (destination / 'usr/lib/rawpair/version').write_text(upgrade + '\n')
                compatibility = destination / 'usr/lib/rawpair/compatibility.json'
                manifest = json.loads(compatibility.read_text())
                manifest['orqos_version'] += '+ci1'
                compatibility.write_text(json.dumps(manifest))
            target = root / source.name
            run('dpkg-deb', '--root-owner-group', '--build', str(destination), str(target))
            packages.append(str(target))
        run('apt-get', 'install', '-y', *packages)
    assert Path('/var/lib/rawpair/setup-required').exists()
    assert subprocess.run(['systemctl', 'is-active', '--quiet', 'rawpair-host']).returncode != 0
    assert subprocess.run(['systemctl', 'is-active', '--quiet', running['unit']]).returncode == 0
    assert subprocess.check_output(['systemctl', 'show', '-p', 'MainPID', '--value', running['unit']], text=True).strip() == workspace_pid, 'Package upgrade restarted the workspace'
    assert Path('/etc/rawpair/rawpair.env').read_bytes() == original
    run('rawpair', 'setup')
    assert Path('/etc/rawpair/rawpair.env').read_bytes() == original
    assert Path('/etc/orqos/host.json').read_bytes() == inventory
    saved = json.loads(Path('/var/lib/rawpair/setup.json').read_text())
    assert Path(saved['backup'], 'database.dump').stat().st_size > 0
    # Upgrade must preserve every ownership token and independent workspace unit.
    assert json.loads(Path('/var/lib/orqos/host', running['id'] + '.json').read_text())['token'] == running['token']
    assert subprocess.run(['systemctl', 'is-active', '--quiet', running['unit']]).returncode == 0
    assert subprocess.check_output(['systemctl', 'show', '-p', 'MainPID', '--value', running['unit']], text=True).strip() == workspace_pid, 'Setup restarted the workspace'
    run('rawpair', 'doctor', '--json')
    run('apt-get', 'remove', '-y', 'rawpair-native', 'rawpair', 'orqos-host')
    for record in records.values():
        assert subprocess.run(['systemctl', 'is-active', '--quiet', record['unit']]).returncode != 0
        assert Path(record['home'], 'project/smoke.txt').exists()
        assert Path('/var/lib/orqos/host', record['id'] + '.json').exists()
    # A removed metapackage has no files/configuration left, so apt no longer
    # knows its locally installed name. dpkg handles that state and purges the
    # remaining package hooks/configuration without needing an APT repository.
    run('dpkg', '--purge', 'rawpair-native', 'rawpair', 'orqos-host')
    assert Path('/etc/rawpair/rawpair.env').read_bytes() == original
    assert Path('/etc/orqos/host.json').read_bytes() == inventory
    assert Path('/var/lib/rawpair-collaboration').is_dir()
    assert Path('/var/lib/orqos/provisioning.json').exists()
    print('Coordinated package upgrade, database backup, control gating, running workspace preservation, removal and purge passed')


if __name__ == '__main__':
    main()
