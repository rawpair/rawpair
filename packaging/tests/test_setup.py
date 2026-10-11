import importlib.util
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'native'))
import setup
import configure


class SetupValidation(unittest.TestCase):
    def test_browser_discovery_handles_firefox_only_chromium_only_both_and_neither(self):
        firefox = '.mozilla/firefox/only-profile'
        chromium = '.local/share/pki/nssdb'
        for paths, labels in [([], []), ([firefox], ['Firefox']), ([chromium], ['Chromium']),
                              ([firefox, chromium], ['Chromium', 'Firefox'])]:
            with self.subTest(paths=paths), tempfile.TemporaryDirectory() as directory:
                home = Path(directory)
                for relative in paths:
                    database = home / relative
                    database.mkdir(parents=True)
                    (database / 'cert9.db').touch()
                self.assertEqual([label for label, _ in setup.browser_trust_stores(home)], labels)
        with tempfile.TemporaryDirectory() as directory, patch.object(setup, 'run') as run:
            self.assertEqual(setup.trust_local_browsers([], directory, '/unused-certificate'), [])
            run.assert_not_called()
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_local_ca_consent_explains_scope_defaults_no_and_requires_yes(self):
        for answers, expected in [([''], False), (['no'], False), (['yes'], True), (['maybe', 'yes'], True)]:
            output = io.StringIO()
            with self.subTest(answers=answers), patch('builtins.input', side_effect=answers), contextlib.redirect_stdout(output):
                self.assertEqual(setup.local_ca_consent(), expected)
            self.assertIn('any hostname', output.getvalue())
            self.assertIn('system trust', output.getvalue())
            self.assertIn('browser trust', output.getvalue())
            self.assertIn('manually', output.getvalue())

    def test_unattended_ca_consent_requires_local_boolean(self):
        for value in (True, False):
            config = setup.validate_config({'mode': 'local', 'trust_local_ca': value}, need_login=False)
            self.assertIs(config['trust_local_ca'], value)
        for value in ('yes', 'false', 1, None):
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, 'true or false'):
                setup.validate_config({'mode': 'local', 'trust_local_ca': value}, need_login=False)
        with self.assertRaisesRegex(ValueError, 'only to local mode'):
            setup.validate_config({'mode': 'remote', 'trust_local_ca': True}, need_login=False)

    def test_local_tls_does_not_install_trust_without_approval(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'tls').mkdir()
            for name in ('cert.pem', 'key.pem'):
                (root / 'tls' / name).write_text('existing leaf')
            with patch.object(setup, 'ETC', root), patch.dict(os.environ, {'SUDO_UID': str(os.getuid())}), \
                 patch.object(setup, 'run', return_value=str(root)) as run, \
                 patch.object(setup, 'trust_local_browsers') as browser_trust, contextlib.redirect_stdout(io.StringIO()):
                setup.local_tls({})
            self.assertFalse(any('-install' in call.args[0] for call in run.call_args_list))
            browser_trust.assert_not_called()

    def test_approved_ca_install_scopes_system_trust_and_handles_no_browsers(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'tls').mkdir()
            for name in ('cert.pem', 'key.pem', 'rootCA.pem'):
                (root / 'tls' / name).write_text('fixture certificate')
            user = SimpleNamespace(pw_name='fixture-user', pw_dir=str(root))
            output = io.StringIO()
            with patch.object(setup, 'ETC', root), patch.dict(os.environ, {'SUDO_UID': '1000'}), \
                 patch.object(setup.pwd, 'getpwuid', return_value=user), \
                 patch.object(setup, 'run', return_value=str(root)) as run, contextlib.redirect_stdout(output):
                setup.local_tls({}, trust_local_ca=True)
            install = [call.args[0] for call in run.call_args_list if '-install' in call.args[0]]
            self.assertEqual(len(install), 1)
            self.assertEqual(install[0][-4:], ['env', 'TRUST_STORES=system', 'mkcert', '-install'])
            self.assertFalse(any('certutil' in call.args[0] for call in run.call_args_list))
            self.assertIn('No browser stores found', output.getvalue())

    def test_browser_nss_stores_trust_local_ca_and_repeat_preserves_other_cas(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            paths = ['.local/share/pki/nssdb', '.pki/nssdb', 'snap/chromium/current/.pki/nssdb',
                     '.mozilla/firefox/default', 'snap/firefox/common/.mozilla/firefox/default',
                     '.var/app/org.mozilla.firefox/.mozilla/firefox/default']
            for path in paths:
                database = home / path
                database.mkdir(parents=True)
                setup.run(['certutil', '-N', '-d', 'sql:' + str(database), '--empty-password'])
            def certificate(name):
                pem, key = home / (name + '.pem'), home / (name + '.key')
                setup.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '2',
                           '-subj', '/CN=' + name, '-addext', 'basicConstraints=critical,CA:TRUE',
                           '-keyout', str(key), '-out', str(pem)])
                return pem
            other, local = certificate('existing-ca'), certificate('rawpair-local-ca')
            for path in paths:
                setup.run(['certutil', '-A', '-d', 'sql:' + str(home / path), '-n', 'Existing CA', '-t', 'C,,', '-i', str(other)])
            self.assertEqual(len(setup.trust_local_browsers([], home, local)), len(paths))
            setup.trust_local_browsers([], home, local)
            for path in paths:
                database = home / path
                listing = setup.run(['certutil', '-L', '-d', 'sql:' + str(database)])
                self.assertEqual(listing.count('RawPair local CA '), 1)
                self.assertIn('Existing CA', listing)
                nickname = 'RawPair local CA ' + setup.hashlib.sha256(local.read_bytes()).hexdigest()[:16]
                exported = setup.run(['certutil', '-L', '-d', 'sql:' + str(database), '-n', nickname, '-a'])
                self.assertEqual(exported, local.read_text().strip())
                setup.run(['certutil', '-V', '-d', 'sql:' + str(database), '-n', nickname, '-u', 'L'])

    def test_system_checks_accept_both_ubuntu_releases_and_require_declared_compatibility(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            compatibility = root / 'compatibility.json'
            metadata = {'ubuntu': '24.04', 'ubuntu_versions': ['24.04', '26.04'], 'orqos_version': '0.2.3'}
            compatibility.write_text(json.dumps(metadata))
            with patch.object(setup, 'HERE', root), patch.object(setup, 'STATE', root), \
                 patch.object(setup, 'installed_version', return_value='0.0.3'), \
                 patch.object(setup, 'run', side_effect=lambda args: '0.0.3' if args[-1] == 'rawpair' else '0.2.3') as run, \
                 patch.object(setup.shutil, 'which', return_value='/bin/fixture'), \
                 patch.object(Path, 'is_dir', return_value=True), \
                 patch.object(Path, 'exists', autospec=True, side_effect=lambda path: str(path) == '/sys/fs/cgroup/cgroup.controllers'), \
                 patch.object(setup.platform, 'release', return_value='7.0.0'), \
                 patch.object(setup.platform, 'machine', return_value='x86_64'), \
                 patch.object(setup, 'values') as values:
                for ubuntu in ('24.04', '26.04'):
                    values.return_value = {'ID': 'ubuntu', 'VERSION_ID': ubuntu}
                    setup.system_checks()
                self.assertEqual(run.call_count, 4)
                run.reset_mock()
                del metadata['ubuntu_versions']
                compatibility.write_text(json.dumps(metadata))
                with self.assertRaisesRegex(ValueError, 'Installed release does not support'):
                    setup.system_checks()
                run.assert_not_called()
                for distro, ubuntu in [('ubuntu', '22.04'), ('ubuntu', '25.10'), ('debian', '26.04')]:
                    values.return_value = {'ID': distro, 'VERSION_ID': ubuntu}
                    with self.subTest(distro=distro, ubuntu=ubuntu), self.assertRaisesRegex(ValueError, 'Supported OS'):
                        setup.system_checks()

    def test_accepts_documented_local_defaults(self):
        config = setup.validate_config({'mode': 'local', 'first_user': {'username': 'owner', 'password': 'abcdefghijkl'}})
        self.assertEqual(config['management_host'], 'rawpair.localhost')
        self.assertEqual(config['preview_domain'], 'apps.rawpair.localhost')

    def test_rejects_nested_custom_and_remote_origins(self):
        for mode, management, preview in [('local', 'pair.example.com', 'apps.pair.example.com'),
                                          ('remote', 'pair.example.com', 'apps.pair.example.com'),
                                          ('remote', 'rawpair.localhost', 'apps.rawpair.localhost')]:
            with self.subTest(mode=mode, management=management), self.assertRaises(ValueError):
                setup.validate_config({'mode': mode, 'management_host': management, 'preview_domain': preview,
                                       'certificate': '/cert.pem', 'private_key': '/key.pem',
                                       'first_user': {'username': 'owner', 'password': 'abcdefghijkl'}})

    def test_rejects_injection_conflicting_origins_and_credentials(self):
        for changes in ({'management_host': "foo;evil.test"}, {'preview_domain': 'rawpair.localhost'},
                        {'management_host': 'x.apps.rawpair.localhost'}, {'subnet': '8.8.0.0/16'},
                        {'database_url': 'ecto://a:b@db/db\nFOO=bar'}, {'unknown': True},
                        {'first_user': {'username': 'ok', 'password': 'abcdefghijkl'}}):
            with self.subTest(changes=changes), self.assertRaises((ValueError, TypeError)):
                setup.validate_config({'mode': 'local', 'first_user': {'username': 'owner', 'password': 'abcdefghijkl'}, **changes})

    def test_config_requires_protected_regular_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config.json'
            path.write_text('{}')
            path.chmod(0o644)
            with patch.dict(os.environ, {'SUDO_UID': str(os.getuid())}), self.assertRaises(ValueError):
                setup.protected_json(path)
            path.chmod(0o600)
            with patch.dict(os.environ, {'SUDO_UID': str(os.getuid())}):
                self.assertEqual(setup.protected_json(path), {})
            link = Path(directory) / 'link'
            link.symlink_to(path)
            with self.assertRaises(OSError):
                setup.protected_json(link)

    def test_database_credentials_never_appear_in_arguments(self):
        env = setup.database('ecto://owner:secret%21@db.example/db?sslmode=require')
        self.assertEqual(env['PGPASSWORD'], 'secret!')
        self.assertEqual(env['PGDATABASE'], 'db')
        self.assertEqual(env['PGHOST'], 'db.example')
        self.assertEqual(env['PGUSER'], 'owner')
        self.assertEqual(env['PGSSLMODE'], 'require')
        with patch.object(subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', 'password=secret!')):
            with self.assertRaisesRegex(RuntimeError, '^psql failed') as context:
                setup.run(['psql'], env=env)
        self.assertNotIn('secret!', str(context.exception))

    def test_database_tls_options_and_ambiguous_options(self):
        env = setup.database('postgresql://owner:secret@db.example:5433/db?sslmode=verify-full&sslrootcert=%2Fetc%2Fprivate-ca.pem')
        self.assertEqual(env['PGPORT'], '5433')
        self.assertEqual(env['PGSSLMODE'], 'verify-full')
        self.assertEqual(env['PGSSLROOTCERT'], '/etc/private-ca.pem')
        for options in ('sslmode=require&sslmode=disable', 'unknown=value', 'ssl=maybe'):
            with self.subTest(options=options), self.assertRaises(ValueError):
                setup.database('ecto://owner:secret@db.example/db?' + options)

    def test_render_is_loopback_for_local_and_keeps_remote_cert_paths(self):
        environment = {'RAWPAIR_COLLABORATION_TOKEN': 'b' * 64, 'RAWPAIR_GATEWAY_TOKEN': 'c' * 64, 'ORQOS_HOST_TOKEN': 'd' * 64}
        with patch.object(configure, 'values', return_value=environment), patch.object(configure, 'environment'), patch.object(configure, 'write'):
            local = configure.render('/etc/rawpair', ROOT / 'native/nginx.conf.template', 'rawpair.localhost', 'apps.rawpair.localhost', '/cert.pem', '/key.pem', True)
            remote = configure.render('/etc/rawpair', ROOT / 'native/nginx.conf.template', 'pair.example.com', 'apps.example.com', '/etc/letsencrypt/live/pair/fullchain.pem', '/etc/letsencrypt/live/pair/privkey.pem', False)
        self.assertNotIn('listen 443 ssl;', local)
        self.assertIn('listen 127.0.0.1:443 ssl;', local)
        self.assertIn('listen [::1]:443 ssl;', local)
        self.assertIn('ssl_certificate /etc/letsencrypt/live/pair/fullchain.pem;', remote)

    def test_tls_hostname_check_requires_positive_result_even_with_zero_exit(self):
        with tempfile.TemporaryDirectory() as directory:
            key = Path(directory) / 'key.pem'
            key.write_text('not reached: hostname validation must fail first')
            key.chmod(0o600)
            for output in ('Hostname missing.example.com does NOT match certificate', '', 'unexpected output'):
                with self.subTest(output=output), patch.object(setup, 'run', return_value=output):
                    with self.assertRaisesRegex(ValueError, 'does not cover management hostname'):
                        setup.tls_validate('/cert.pem', str(key), 'missing.example.com', 'apps.example.com')

    def test_tls_checks_mismatch_wildcard_expiry_and_key_permissions(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def cert(name, sans, days='2'):
                key, pem = root / (name + '.key'), root / (name + '.pem')
                subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', days,
                                '-subj', '/CN=rawpair.localhost', '-addext', 'subjectAltName=' + sans,
                                '-keyout', str(key), '-out', str(pem)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                key.chmod(0o600)
                return str(pem), str(key)
            pem, key = cert('valid', 'DNS:rawpair.localhost,DNS:*.apps.rawpair.localhost')
            setup.tls_validate(pem, key, 'rawpair.localhost', 'apps.rawpair.localhost')
            other, other_key = cert('other', 'DNS:rawpair.localhost,DNS:a.apps.rawpair.localhost')
            for certificate, private_key, management in [(pem, other_key, 'rawpair.localhost'), (other, other_key, 'rawpair.localhost'),
                                                         (pem, key, 'missing.example.com')]:
                with self.subTest(certificate=certificate, management=management), self.assertRaises((ValueError, RuntimeError)):
                    setup.tls_validate(certificate, private_key, management, 'apps.rawpair.localhost')
            with patch.object(setup, 'run', side_effect=RuntimeError('expiry')):
                with self.assertRaises(ValueError):
                    setup.tls_validate(pem, key, 'rawpair.localhost', 'apps.rawpair.localhost')
            Path(key).chmod(0o644)
            with self.assertRaises(ValueError):
                setup.tls_validate(pem, key, 'rawpair.localhost', 'apps.rawpair.localhost')


class SetupRecovery(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        self.etc, self.state = root / 'etc', root / 'state'
        self.etc.mkdir()
        self.state.mkdir()
        (self.state / 'package-owner').write_text('managed')
        self.progress = self.state / 'setup.json'
        self.config = {'mode': 'remote', 'management_host': 'pair.example.com', 'preview_domain': 'apps.example.com',
                       'certificate': '/cert.pem', 'private_key': '/key.pem', 'subnet': '10.231.0.0/16',
                       'database_url': 'ecto://user:pass@db/db', 'first_user': {'username': 'owner', 'password': 'long-random-password'}}
        self.config_file = root / 'input.json'
        self.config_file.write_text(json.dumps(self.config))
        self.config_file.chmod(0o600)
        self.mocks = {}
        for name in ('root', 'system_checks', 'installed_version', 'stop_controls', 'run', 'check_ports', 'tls_validate',
                     'configure_database', 'service_config', 'release', 'diagnostics', 'backup', 'wait_ready', 'local_tls'):
            patcher = patch.object(setup, name)
            self.mocks[name] = patcher.start()
            self.addCleanup(patcher.stop)
        self.mocks['installed_version'].return_value = '1.0.0'
        self.mocks['diagnostics'].return_value = []
        for name, value in [('ETC', self.etc), ('STATE', self.state), ('PROGRESS', self.progress), ('REQUIRED', self.state / 'setup-required')]:
            patcher = patch.object(setup, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        patcher = patch.dict(os.environ, {'SUDO_UID': str(os.getuid())})
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_unattended_setup_repeat_preserves_login_and_migration(self):
        setup.setup(str(self.config_file))
        state = json.loads(self.progress.read_text())
        self.assertEqual(state['steps'], ['migrated', 'login'])
        self.assertNotIn('first_user', state['config'])
        setup.setup(str(self.config_file))
        self.assertEqual(self.mocks['release'].call_count, 2)
        self.assertEqual(json.loads(self.progress.read_text())['completed_version'], '1.0.0')

    def test_explicit_ca_approval_is_not_saved_or_reused_on_noninteractive_resume(self):
        self.config.update(mode='local', trust_local_ca=True)
        self.config_file.write_text(json.dumps(self.config))
        with patch.dict(os.environ, {'SUDO_UID': str(os.getuid() or 1)}), \
             patch.object(setup, 'protected_json', side_effect=lambda path: json.loads(Path(path).read_text())), \
             patch.object(setup.sys.stdin, 'isatty', return_value=False):
            setup.setup(str(self.config_file))
            self.assertTrue(self.mocks['local_tls'].call_args.kwargs['trust_local_ca'])
            self.assertNotIn('trust_local_ca', json.loads(self.progress.read_text())['config'])
            setup.setup(None)
            self.assertFalse(self.mocks['local_tls'].call_args.kwargs['trust_local_ca'])

    def test_interactive_ca_choice_precedes_control_and_trust_changes(self):
        self.config['mode'] = 'local'
        self.config_file.write_text(json.dumps(self.config))
        setup.setup(str(self.config_file))
        order = []
        self.mocks['stop_controls'].side_effect = lambda: order.append('stop')
        with patch.object(setup.sys.stdin, 'isatty', return_value=True), \
             patch.object(setup, 'local_ca_consent', side_effect=lambda: order.append('choice') or False):
            setup.setup(None)
        self.assertEqual(order[:2], ['choice', 'stop'])
        self.assertFalse(self.mocks['local_tls'].call_args.kwargs['trust_local_ca'])

    def test_interruption_resumes_without_second_migration(self):
        self.mocks['release'].side_effect = [None, RuntimeError('interrupted')]
        with self.assertRaises(RuntimeError):
            setup.setup(str(self.config_file))
        state = json.loads(self.progress.read_text())
        self.assertEqual(state['steps'], ['migrated'])
        self.assertIn('first_user', state['config'])
        self.mocks['release'].reset_mock(side_effect=True)
        setup.setup(None)
        self.mocks['release'].assert_called_once_with('bootstrap_user', self.config['first_user'])

    def test_upgrade_backup_failure_prevents_migration_and_start(self):
        setup.setup(str(self.config_file))
        self.mocks['release'].reset_mock()
        self.mocks['run'].reset_mock()
        self.mocks['installed_version'].return_value = '1.1.0'
        self.mocks['backup'].side_effect = RuntimeError('backup failed')
        with self.assertRaises(RuntimeError):
            setup.setup(None)
        self.mocks['release'].assert_not_called()
        self.assertFalse(any('enable' in call.args[0] for call in self.mocks['run'].call_args_list))
        self.assertEqual(json.loads(self.progress.read_text())['completed_version'], '1.0.0')

    def test_unmanaged_installation_refused_before_mutation(self):
        (self.state / 'package-owner').unlink()
        with self.assertRaisesRegex(ValueError, 'not managed'):
            setup.setup(str(self.config_file))
        self.mocks['run'].assert_not_called()
        self.mocks['stop_controls'].assert_not_called()

    def test_migration_failure_leaves_completed_version_and_backup_intact(self):
        setup.setup(str(self.config_file))
        self.mocks['installed_version'].return_value = '1.1.0'
        self.mocks['release'].side_effect = RuntimeError('migration failed')
        with self.assertRaises(RuntimeError):
            setup.setup(None)
        self.assertEqual(json.loads(self.progress.read_text())['completed_version'], '1.0.0')
        self.mocks['backup'].assert_called_once()
