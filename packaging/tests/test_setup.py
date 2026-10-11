import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'native'))
import setup
import configure


class SetupValidation(unittest.TestCase):
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
        self.assertTrue(env['PGDATABASE'].startswith('postgresql://'))
        with patch.object(subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', 'password=secret!')):
            with self.assertRaisesRegex(RuntimeError, '^psql failed') as context:
                setup.run(['psql'], env=env)
        self.assertNotIn('secret!', str(context.exception))

    def test_render_is_loopback_for_local_and_keeps_remote_cert_paths(self):
        environment = {'RAWPAIR_COLLABORATION_TOKEN': 'b' * 64, 'RAWPAIR_GATEWAY_TOKEN': 'c' * 64, 'ORQOS_HOST_TOKEN': 'd' * 64}
        with patch.object(configure, 'values', return_value=environment), patch.object(configure, 'environment'), patch.object(configure, 'write'):
            local = configure.render('/etc/rawpair', ROOT / 'native/nginx.conf.template', 'rawpair.localhost', 'apps.rawpair.localhost', '/cert.pem', '/key.pem', True)
            remote = configure.render('/etc/rawpair', ROOT / 'native/nginx.conf.template', 'pair.example.com', 'apps.example.com', '/etc/letsencrypt/live/pair/fullchain.pem', '/etc/letsencrypt/live/pair/privkey.pem', False)
        self.assertNotIn('listen 443 ssl;', local)
        self.assertIn('listen 127.0.0.1:443 ssl;', local)
        self.assertIn('listen [::1]:443 ssl;', local)
        self.assertIn('ssl_certificate /etc/letsencrypt/live/pair/fullchain.pem;', remote)

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
                     'configure_database', 'service_config', 'release', 'diagnostics', 'backup', 'wait_ready'):
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
