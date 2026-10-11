import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'packaging'))
import build
import release


class ReleaseTests(unittest.TestCase):
    def test_semver_required_and_debian_prerelease_ordering(self):
        self.assertEqual(build.version('v2.3.4-rc.1'), '2.3.4~rc.1')
        for value in ('', 'latest', '2.3.4', 'v2.3', 'v2.3.4/../bad'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                build.version(value)

    def test_checksum_parser_refuses_paths_and_duplicates(self):
        line = 'a' * 64 + '  orqos-host_0.2.3_amd64.deb'
        self.assertEqual(release.checksums(line)['orqos-host_0.2.3_amd64.deb'], 'a' * 64)
        for text in (line + '\n' + line, 'a' * 64 + '  ../outside', 'malformed'):
            with self.assertRaises(ValueError):
                release.checksums(text)

    def test_pinned_download_checksum_failure_prevents_provenance_or_use(self):
        with tempfile.TemporaryDirectory() as directory:
            calls = []
            def fetch(url):
                calls.append(url)
                if url.endswith('SHA256SUMS'):
                    return ('0' * 64 + '  orqos-host_0.2.3_arm64.deb\n').encode()
                return b'changed'
            with patch.object(release, 'fetch', side_effect=fetch), patch.object(release.subprocess, 'run') as command:
                with self.assertRaisesRegex(ValueError, 'checksum mismatch'):
                    release.orqos('arm64', Path(directory))
                command.assert_not_called()
            self.assertEqual(len(calls), 2)
            self.assertTrue(all('/download/v0.2.3/' in url for url in calls))
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_complete_manifest_and_checksums_cover_all_assets(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            names = ['rawpair_1.2.3_amd64.deb', 'rawpair_1.2.3_arm64.deb', 'rawpair-native_1.2.3_all.deb',
                     'orqos-host_0.2.3_amd64.deb', 'orqos-host_0.2.3_arm64.deb']
            for name in names:
                (root / name).write_bytes(name.encode())
            with patch.object(release, 'validate_deb') as validate:
                release.assemble('v1.2.3', root)
            self.assertEqual(validate.call_count, 6)
            manifest = json.loads((root / 'manifest.json').read_text())
            self.assertEqual(manifest['ubuntu'], '24.04')
            self.assertEqual(manifest['ubuntu_versions'], ['24.04', '26.04'])
            self.assertEqual(manifest['orqos_tag'], 'v0.2.3')
            self.assertEqual(manifest['packages']['arm64'], ['rawpair_1.2.3_arm64.deb', 'orqos-host_0.2.3_arm64.deb', 'rawpair-native_1.2.3_all.deb'])
            sums = release.checksums((root / 'SHA256SUMS').read_text())
            self.assertEqual(set(sums), {*names, 'install.sh', 'manifest.json'})
            for name, digest in sums.items():
                self.assertEqual(digest, hashlib.sha256((root / name).read_bytes()).hexdigest())
