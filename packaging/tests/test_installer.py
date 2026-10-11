import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Installer(unittest.TestCase):
    def run_installer(self, arch='amd64', tag='v1.2.3', corrupt=False, os_release='ubuntu:24.04', flags=('--download-only',), latest=False):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            assets = directory / 'assets'
            assets.mkdir()
            packages = {a: [f'rawpair_1.2.3_{a}.deb', f'orqos-host_0.2.0_{a}.deb', 'rawpair-native_1.2.3_all.deb'] for a in ['amd64', 'arm64']}
            manifest = {'schema': 1, 'ubuntu': '24.04', 'rawpair_tag': tag, 'orqos_version': '0.2.0', 'packages': packages}
            (assets / 'manifest.json').write_text(json.dumps(manifest))
            for name in set(sum(packages.values(), [])):
                (assets / name).write_bytes(name.encode())
            (assets / 'SHA256SUMS').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.name + '\n' for p in sorted(assets.iterdir())))
            if corrupt:
                (assets / packages.get(arch, packages['amd64'])[0]).write_text('changed')
            bin_dir = directory / 'bin'
            bin_dir.mkdir()
            real_python = subprocess.check_output(['which', 'python3'], text=True).strip()
            stubs = {
                'python3': f'#!/bin/sh\nif [ "$1" = -c ] && [ "$2" != "import json,sys; r=json.load(sys.stdin); assert not r[\\"draft\\"] and not r[\\"prerelease\\"]; print(r[\\"tag_name\\"])" ]; then\n case "$2" in *os-release*) echo "$TEST_OS"; exit 0;; esac\nfi\nexec {real_python} "$@"\n',
                'dpkg': '#!/bin/sh\necho "$TEST_ARCH"\n',
                'apt-get': '#!/bin/sh\necho "$*" >> "$TEST_APT"\n',
                'sudo': '#!/bin/sh\nexec "$@"\n',
                'rawpair': '#!/bin/sh\necho "$*" >> "$TEST_SETUP"\n',
                'curl': f'''#!{real_python}
import json, os, pathlib, shutil, sys
args = sys.argv[1:]
url = args[-1]
with open(os.environ['TEST_URLS'], 'a') as f: f.write(url+'\\n')
if url.endswith('/releases/latest'):
    print(json.dumps({{'tag_name': 'v1.2.3', 'draft': False, 'prerelease': False}}))
else:
    shutil.copyfile(pathlib.Path(os.environ['TEST_ASSETS']) / url.rsplit('/',1)[1], args[args.index('--output')+1])
'''}
            for name, text in stubs.items():
                path = bin_dir / name
                path.write_text(text)
                path.chmod(0o755)
            env = dict(os.environ, PATH=str(bin_dir) + ':' + os.environ['PATH'], TEST_OS=os_release, TEST_ARCH=arch,
                       TEST_ASSETS=str(assets), TEST_URLS=str(directory / 'urls'), TEST_APT=str(directory / 'apt'), TEST_SETUP=str(directory / 'setup'))
            command = ['bash', str(ROOT / 'install.sh'), '--output', str(directory / 'output'), *flags]
            if not latest:
                command += ['--version', tag]
            result = subprocess.run(command, env=env, text=True, capture_output=True)
            read = lambda name: (directory / name).read_text() if (directory / name).exists() else ''
            return result, read('urls'), read('apt'), read('setup')

    def test_download_only_selects_native_arch_and_exact_tag(self):
        for arch in ('amd64', 'arm64'):
            result, urls, apt, setup = self.run_installer(arch=arch)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(f'rawpair_1.2.3_{arch}.deb', urls)
            self.assertNotIn('/latest', urls)
            self.assertEqual(apt + setup, '')

    def test_latest_is_resolved_once_then_all_assets_are_tag_pinned(self):
        result, urls, _, _ = self.run_installer(latest=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(urls.count('/releases/latest'), 1)
        self.assertTrue(all('/download/v1.2.3/' in line for line in urls.splitlines()[1:]))

    def test_checksum_failure_prevents_apt(self):
        result, _, apt, setup = self.run_installer(corrupt=True, flags=())
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('checksum mismatch', result.stderr)
        self.assertEqual(apt + setup, '')

    def test_unsupported_systems_and_invalid_tags_do_not_download(self):
        for kwargs in ({'arch': 'riscv64'}, {'os_release': 'debian:12'}, {'tag': 'latest'}, {'tag': 'v1.2.3/../../bad'}):
            result, urls, apt, setup = self.run_installer(**kwargs)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(urls + apt + setup, '')

    def test_no_setup_still_installs_one_coordinated_transaction(self):
        result, _, apt, setup = self.run_installer(flags=('--no-setup',))
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = apt.splitlines()
        self.assertEqual(lines[0], 'update')
        self.assertTrue(all(x in lines[1] for x in ('rawpair_', 'orqos-host_', 'rawpair-native_')))
        self.assertEqual(setup, '')

    def test_install_runs_setup_by_default(self):
        result, _, _, setup = self.run_installer(flags=())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(setup.strip(), 'setup')
