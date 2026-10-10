#!/usr/bin/python3
"""Generate native service secrets and nginx configuration; run only by install.sh."""
import base64
import grp
import os
from pathlib import Path
import secrets
import subprocess
import sys

management, preview = sys.argv[1:]
configuration = Path('/etc/rawpair')
env_path = configuration / 'rawpair.env'


def write(path, text, group=None):
    path.write_text(text)
    path.chmod(0o640 if group else 0o600)
    if group:
        os.chown(path, 0, grp.getgrnam(group).gr_gid)


def values(path):
    return dict(line.split('=', 1) for line in path.read_text().splitlines() if line and not line.startswith('#'))


if not env_path.exists():
    role = subprocess.check_output(['runuser', '-u', 'postgres', '--', 'psql', '-Atc', "SELECT 1 FROM pg_roles WHERE rolname='rawpair'"], text=True).strip()
    if role:
        raise SystemExit('PostgreSQL role rawpair already exists. Create /etc/rawpair/rawpair.env using native/rawpair.env.example and its existing credentials, then rerun install.')
    password = secrets.token_hex(32)
    subprocess.run(['runuser', '-u', 'postgres', '--', 'psql', '-v', 'ON_ERROR_STOP=1', '-c', f"CREATE ROLE rawpair LOGIN PASSWORD '{password}'"], check=True)
    subprocess.run(['runuser', '-u', 'postgres', '--', 'createdb', '-O', 'rawpair', 'rawpair'], check=True)
    token = values(Path('/etc/orqos/host.env'))['ORQOS_HOST_TOKEN']
    write(env_path, '\n'.join([
        'PHX_SERVER=true', f'PHX_HOST={management}', f'CHECK_ORIGIN=https://{management}',
        f'DATABASE_URL=ecto://rawpair:{password}@127.0.0.1/rawpair',
        'SECRET_KEY_BASE=' + base64.b64encode(secrets.token_bytes(64)).decode(),
        'RAWPAIR_BACKENDS=host', 'ORQOS_URL=http://127.0.0.1:9080', f'ORQOS_HOST_TOKEN={token}',
        'RAWPAIR_GATEWAY_TOKEN=' + secrets.token_hex(32),
        'RAWPAIR_COLLABORATION_TOKEN=' + secrets.token_hex(32), f'RAWPAIR_PREVIEW_DOMAIN={preview}',
        'RELEASE_TMP=/var/lib/rawpair/tmp', 'RELEASE_COOKIE=' + secrets.token_hex(32),
    ]) + '\n', 'rawpair')
env = values(env_path)
if env['PHX_HOST'] != management or env['RAWPAIR_PREVIEW_DOMAIN'] != preview:
    raise SystemExit('Hostname change requires updating /etc/rawpair/rawpair.env before rerunning install.')
write(configuration / 'collaboration.env', '\n'.join([
    'RAWPAIR_AUTH_URL=http://127.0.0.1:4000/internal/collaboration/authorize',
    'RAWPAIR_COLLABORATION_TOKEN=' + env['RAWPAIR_COLLABORATION_TOKEN'],
    'RAWPAIR_COLLABORATION_DIR=/var/lib/rawpair-collaboration', f'RAWPAIR_ORIGIN=https://{management}',
]) + '\n', 'rawpair-collab')
write(configuration / 'nginx-secrets.conf',
      f"set $rawpair_gateway_token '{env['RAWPAIR_GATEWAY_TOKEN']}';\nset $orqos_host_token '{env['ORQOS_HOST_TOKEN']}';\n")
template = Path('native/nginx.conf.template').read_text()
rendered = template.replace('__MANAGEMENT_HOST__', management).replace('__PREVIEW_DOMAIN__', preview)
site = Path('/etc/nginx/sites-available/rawpair-native')
site.write_text(rendered)
site.chmod(0o644)
enabled = Path('/etc/nginx/sites-enabled/rawpair-native')
if not enabled.exists():
    enabled.symlink_to(site)
print('Generated service configuration and nginx site; secrets were not printed.')
