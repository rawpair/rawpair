"""Exercise libpq environment handling against an isolated scratch database."""
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'native'))
import setup


class DatabaseConnection(unittest.TestCase):
    def test_url_connects_and_backs_up_with_encoded_credentials_and_names(self):
        binaries = sorted(Path('/usr/lib/postgresql').glob('*/bin/initdb'),
                          key=lambda path: int(path.parents[1].name))
        if not binaries or os.geteuid() == 0:
            self.skipTest('Requires PostgreSQL server tools and an ordinary test user')
        binary = binaries[-1].parent
        with tempfile.TemporaryDirectory(prefix='rawpair-database-test-') as directory:
            root = Path(directory)
            password = root / 'password'
            password.write_text('fixture secret!\n')
            password.chmod(0o600)
            with socket.socket() as listener:
                listener.bind(('127.0.0.1', 0))
                port = listener.getsockname()[1]
            subprocess.run([str(binary / 'initdb'), '-D', str(root / 'data'), '-U', 'probe user',
                            '--auth-local', 'trust', '--auth-host', 'scram-sha-256',
                            '--pwfile', str(password), '--no-locale', '-E', 'UTF8'],
                           check=True, stdout=subprocess.DEVNULL)
            subprocess.run([str(binary / 'pg_ctl'), '-D', str(root / 'data'), '-l', str(root / 'server.log'),
                            '-o', f'-h 127.0.0.1 -p {port} -k {root}', 'start'],
                           check=True, stdout=subprocess.DEVNULL)
            try:
                subprocess.run([str(binary / 'createdb'), '-h', str(root), '-p', str(port),
                                '-U', 'probe user', 'probe db'], check=True)
                # Unrelated inherited defaults must not redirect the requested URL.
                with patch.dict(os.environ, {'PGHOST': 'unrelated.invalid', 'PGSERVICE': 'missing'}):
                    env = setup.database(f'ecto://probe%20user:fixture%20secret%21@127.0.0.1:{port}/probe%20db?ssl=false&connect_timeout=3')
                result = subprocess.check_output([str(binary / 'psql'), '-XAtc', 'SELECT current_user, current_database()'],
                                                 env=env, text=True)
                self.assertEqual(result.strip(), 'probe user|probe db')
                backup = subprocess.check_output([str(binary / 'pg_dump'), '--format=custom'], env=env)
                self.assertTrue(backup.startswith(b'PGDMP'))
                with patch.dict(env, {'PGPASSWORD': 'wrong password'}):
                    denied = subprocess.run([str(binary / 'psql'), '-wXAtc', 'SELECT 1'], env=env,
                                            capture_output=True, text=True)
                self.assertNotEqual(denied.returncode, 0)
            finally:
                subprocess.run([str(binary / 'pg_ctl'), '-D', str(root / 'data'), '-m', 'fast', 'stop'],
                               check=True, stdout=subprocess.DEVNULL)
