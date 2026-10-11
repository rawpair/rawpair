#!/usr/bin/python3
"""RawPair native installation and diagnostics. Root-only writes, no HTTP admin API."""
import argparse
import base64
import fcntl
import getpass
import grp
import ipaddress
import json
import os
from pathlib import Path
import platform
import pwd
import re
import shutil
import socket
import stat
import subprocess
import sys
import tempfile
import time
from urllib.parse import urlsplit, unquote, parse_qsl, urlencode, urlunsplit

from configure import environment, render, values, write

ETC = Path('/etc/rawpair')
STATE = Path('/var/lib/rawpair')
PROGRESS = STATE / 'setup.json'
REQUIRED = STATE / 'setup-required'
HERE = Path(__file__).resolve().parent
UNITS = ['rawpair-host', 'rawpair-collaboration']


def run(args, *, env=None, input=None, visible=False):
    result = subprocess.run(args, input=input, env=env, text=True, capture_output=True)
    if result.returncode:
        # Neither database URLs nor supplied passwords belong in error output.
        detail = ': ' + result.stderr.strip() if Path(args[0]).name in ('orqos-host-admin', 'nginx') else ''
        raise RuntimeError(f'{Path(args[0]).name} failed{detail}. Check its configuration and service journal, then rerun setup.')
    if visible:
        print(result.stdout.strip())
    return result.stdout.strip()


def root():
    if os.geteuid() != 0:
        raise ValueError('Run with sudo; configuration contains protected service credentials')


def save(state):
    write(PROGRESS, json.dumps(state, indent=2) + '\n')


def protected_json(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(descriptor) as stream:
        info = os.fstat(stream.fileno())
        allowed = {0, int(os.environ.get('SUDO_UID', '0'))}
        if not stat.S_ISREG(info.st_mode) or info.st_uid not in allowed or info.st_mode & 0o077:
            raise ValueError('Config must be a regular file owned by root or the invoking user, mode 0600')
        if info.st_size > 65536:
            raise ValueError('Config is too large')
        return json.load(stream)


def validate_config(config, need_login=True):
    if not isinstance(config, dict):
        raise ValueError('Setup configuration must be a JSON object')
    allowed = {'mode', 'management_host', 'preview_domain', 'certificate', 'private_key', 'subnet', 'database_url', 'first_user'}
    if set(config) - allowed:
        raise ValueError('Unknown setup fields: ' + ', '.join(sorted(set(config) - allowed)))
    if config.get('mode') not in ('local', 'remote'):
        raise ValueError('mode must be local or remote')
    config.setdefault('management_host', 'rawpair.localhost')
    config.setdefault('preview_domain', 'apps.rawpair.localhost')
    config.setdefault('subnet', '10.231.0.0/16')
    hostname = re.compile(r'(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z][a-z0-9-]{0,62}$')
    management, preview = config['management_host'], config['preview_domain']
    if not all(isinstance(x, str) and hostname.fullmatch(x) for x in (management, preview)):
        raise ValueError('Use lowercase DNS hostnames without schemes, ports or trailing dots')
    if management == preview or management.endswith('.' + preview) or preview.endswith('.' + management):
        raise ValueError('Management and preview domains must be separate, non-nested origins')
    if config['mode'] == 'remote':
        if management.endswith('.localhost') or preview.endswith('.localhost'):
            raise ValueError('Remote mode requires domains resolving to this server')
        for field in ('certificate', 'private_key'):
            if not re.fullmatch(r'/[a-zA-Z0-9_./-]+', config.get(field, '')):
                raise ValueError(f'{field} must be an absolute nginx-safe path')
    network = ipaddress.ip_network(config['subnet'])
    ranges = map(ipaddress.ip_network, ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16'))
    if network.version != 4 or network.prefixlen != 16 or not any(network.subnet_of(x) for x in ranges):
        raise ValueError('subnet must be a private IPv4 /16')
    if config.get('database_url'):
        database(config['database_url'])
    login = config.get('first_user')
    if need_login and not login:
        raise ValueError('first_user is required for a fresh installation')
    if login:
        if not isinstance(login, dict) or not isinstance(login.get('username'), str) or not isinstance(login.get('password'), str) or set(login) != {'username', 'password'} or not re.fullmatch(r'[a-zA-Z0-9_-]{3,40}', login.get('username', '')):
            raise ValueError('first_user requires username (3..40 letters, digits, underscores or hyphens) and password')
        if not 12 <= len(login['password'].encode()) <= 1024:
            raise ValueError('Password must be 12..1024 UTF-8 bytes')
    return config


def prompt(label, default=None):
    value = input(label + (f' [{default}]' if default else '') + ': ').strip()
    return value or default


def credentials():
    username = prompt('First login username')
    password = getpass.getpass('Password (12+ bytes): ')
    if password != getpass.getpass('Repeat password: '):
        raise ValueError('Passwords differ')
    return {'username': username, 'password': password}


def wizard():
    mode = prompt('Installation mode: local or remote', 'local')
    config = {'mode': mode, 'management_host': prompt('Management hostname', 'rawpair.localhost' if mode == 'local' else None),
              'preview_domain': prompt('Preview domain (certificate must cover its wildcard)', 'apps.rawpair.localhost' if mode == 'local' else None),
              'subnet': prompt('Private workspace /16 subnet', '10.231.0.0/16')}
    if mode == 'remote':
        config.update(certificate=prompt('Certificate PEM path'), private_key=prompt('Private key PEM path'))
    if prompt('Database: local or existing', 'local') == 'existing':
        config['database_url'] = getpass.getpass('Existing database URL (hidden): ')
    while True:
        try:
            run(['orqos-host-admin', 'check-subnet', config['subnet']])
            break
        except RuntimeError as error:
            print(str(error), file=sys.stderr)
            config['subnet'] = prompt('Choose another private /16 subnet')
    config['first_user'] = credentials()
    return validate_config(config)


def system_checks():
    os_release = values('/etc/os-release')
    if os_release.get('ID') != 'ubuntu' or os_release.get('VERSION_ID') != '24.04':
        raise ValueError('Supported OS: Ubuntu 24.04')
    if platform.machine() not in ('x86_64', 'aarch64'):
        raise ValueError('Supported CPUs: amd64 and arm64')
    if not Path('/run/systemd/system').is_dir() or not Path('/sys/fs/cgroup/cgroup.controllers').exists():
        raise ValueError('Boot with systemd and cgroup v2')
    kernel = tuple(map(int, platform.release().split('-', 1)[0].split('.')[:2]))
    if kernel < (5, 6):
        raise ValueError('Linux 5.6+ is required for openat2')
    for command in ('systemctl', 'systemd-run', 'ip', 'nft', 'node', 'python3', 'psql', 'pg_dump',
                    'nginx', 'tmux', 'ttyd', 'openssl', 'mkcert', 'runuser', 'orqos-host-admin'):
        if not shutil.which(command):
            raise ValueError(f'Missing {command}; install rawpair-native and its dependencies')
    if (STATE / 'source-owner').exists():
        return
    compatibility = json.loads((HERE / 'compatibility.json').read_text())
    for package, expected in [('rawpair', installed_version().replace('-', '~')), ('orqos-host', compatibility['orqos_version'])]:
        actual = run(['dpkg-query', '-W', '-f=${Version}', package])
        if actual != expected:
            raise ValueError(f'{package} must be version {expected}; install the matching release package set')


def installed_version():
    return (HERE / 'version').read_text().strip()


def check_ports(config):
    # Preserve existing, package-owned nginx listeners. All other listeners fail.
    result = run(['ss', '-H', '-ltnp'])
    managed = (ETC / 'nginx-owned').exists()
    for line in result.splitlines():
        columns = line.split()
        if len(columns) < 4:
            continue
        port = columns[3].rsplit(':', 1)[-1]
        if port in ('4000', '1234', '9080', '443'):
            if port == '443' and managed and '"nginx"' in line:
                continue
            raise ValueError(f'Port {port} is in use. Stop or reconfigure its existing service before setup')


def tls_validate(cert, key, management, preview):
    info = Path(key).stat()
    if info.st_mode & 0o077:
        raise ValueError('TLS private key must not be accessible to group/other (chmod 600)')
    try:
        run(['openssl', 'x509', '-in', cert, '-noout', '-checkend', '86400'])
    except RuntimeError as error:
        raise ValueError('Certificate is unreadable, expired or expires within 24 hours; renew it') from error
    try:
        run(['openssl', 'x509', '-in', cert, '-noout', '-checkhost', management])
    except RuntimeError as error:
        raise ValueError('Certificate does not cover management hostname ' + management) from error
    # checkhost alone would accept one explicit app name. Require wildcard SAN.
    sans = run(['openssl', 'x509', '-in', cert, '-noout', '-ext', 'subjectAltName'])
    if 'DNS:*.' + preview not in [part.strip() for part in sans.replace('\n', ',').split(',')]:
        raise ValueError('Certificate must contain wildcard SAN *.' + preview)
    public_cert = run(['openssl', 'x509', '-in', cert, '-pubkey', '-noout'])
    public_key = run(['openssl', 'pkey', '-in', key, '-passin', 'pass:', '-pubout'])
    if public_cert != public_key:
        raise ValueError('Certificate and private key do not match')


def local_tls(config):
    directory = ETC / 'tls'
    directory.mkdir(mode=0o700, exist_ok=True)
    cert, key = directory / 'cert.pem', directory / 'key.pem'
    invoking = int(os.environ.get('SUDO_UID', '0'))
    user = pwd.getpwuid(invoking)
    as_user = ['runuser', '-u', user.pw_name, '--', 'env', '-u', 'CAROOT', '-u', 'XDG_DATA_HOME', 'HOME=' + user.pw_dir] if invoking else []
    if invoking:
        # mkcert -install performs its documented sudo trust-store installation.
        # Root's sudo invocation has already authorized setup's privileged work.
        run(as_user + ['mkcert', '-install'])
    else:
        print('Headless/root setup: install the generated CA on each browser/client as described in docs/PACKAGES.md.')
    if not cert.exists() or not key.exists():
        temporary = Path(tempfile.mkdtemp(prefix='rawpair-tls-'))
        try:
            if invoking:
                os.chown(temporary, user.pw_uid, user.pw_gid)
            run(as_user + ['mkcert', '-cert-file', str(temporary / 'cert.pem'), '-key-file', str(temporary / 'key.pem'),
                          config['management_host'], '*.' + config['preview_domain']])
            write(cert, (temporary / 'cert.pem').read_text())
            write(key, (temporary / 'key.pem').read_text())
        finally:
            shutil.rmtree(temporary)
    config.update(certificate=str(cert), private_key=str(key))
    ca = run(as_user + ['mkcert', '-CAROOT'])
    print(f'Local CA: {ca}/rootCA.pem. Copy only rootCA.pem to additional clients; keep rootCA-key.pem private.')


def database(url):
    if not isinstance(url, str) or any(x in url for x in ('\n', '\r', '\x00')):
        raise ValueError('Database URL must be a single-line string')
    parsed = urlsplit(url)
    if parsed.scheme not in ('ecto', 'postgres', 'postgresql') or not parsed.hostname or not parsed.path.strip('/'):
        raise ValueError('Use ecto://USER:PASSWORD@HOST:PORT/DATABASE for an existing database')
    env = os.environ.copy()
    env['PGPASSWORD'] = unquote(parsed.password or '')
    query = dict(parse_qsl(parsed.query))
    if 'ssl' in query:
        if query['ssl'] not in ('true', 'false'):
            raise ValueError('Database ssl option must be true or false')
        query.setdefault('sslmode', 'require' if query.pop('ssl') == 'true' else 'disable')
    if query.get('sslmode', 'disable') not in ('disable', 'require', 'verify-full'):
        raise ValueError('Supported database sslmode: disable, require, verify-full')
    # libpq accepts connection URI options, including SSL settings, via PGDATABASE.
    # Password stays in the process environment; no command-line credentials.
    env['PGDATABASE'] = urlunsplit(('postgresql', parsed.netloc, parsed.path, urlencode(query), ''))
    return env


def configure_database(state):
    config = state['config']
    if config.get('database_url'):
        run(['psql', '-X', '-v', 'ON_ERROR_STOP=1', '-Atc', 'SELECT 1'], env=database(config['database_url']))
        return
    env_file = ETC / 'rawpair.env'
    if env_file.exists():
        config['database_url'] = values(env_file)['DATABASE_URL']
        save(state)
        return
    if 'database_password' not in state:
        password = run(['runuser', '-u', 'postgres', '--', 'psql', '-XAtc', "SELECT 1 FROM pg_roles WHERE rolname='rawpair'"])
        exists = run(['runuser', '-u', 'postgres', '--', 'psql', '-XAtc', "SELECT 1 FROM pg_database WHERE datname='rawpair'"])
        if password or exists:
            raise ValueError('PostgreSQL role/database rawpair already exists; supply existing database_url explicitly')
        state['database_password'] = os.urandom(32).hex()
        save(state)
    password = state['database_password']
    # A recorded intent owns this role. Reapplying the saved password is safe after interruption.
    sql = ("DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='rawpair') THEN "
           f"CREATE ROLE rawpair LOGIN PASSWORD '{password}'; END IF; END $$;\n")
    run(['runuser', '-u', 'postgres', '--', 'psql', '-X', '-v', 'ON_ERROR_STOP=1'], input=sql)
    exists = run(['runuser', '-u', 'postgres', '--', 'psql', '-XAtc', "SELECT 1 FROM pg_database WHERE datname='rawpair'"])
    if not exists:
        run(['runuser', '-u', 'postgres', '--', 'createdb', '-O', 'rawpair', 'rawpair'])
    config['database_url'] = f'ecto://rawpair:{password}@127.0.0.1/rawpair'
    save(state)
    run(['psql', '-XAtc', 'SELECT 1'], env=database(config['database_url']))


def service_config(state):
    config = state['config']
    path = ETC / 'rawpair.env'
    token = values('/etc/orqos/host.env')['ORQOS_HOST_TOKEN']
    if not re.fullmatch(r'[0-9a-f]{64}', token):
        raise ValueError('Expected the installer-generated Orqos host token')
    if path.exists():
        env = values(path)
        for name in ('RAWPAIR_GATEWAY_TOKEN', 'RAWPAIR_COLLABORATION_TOKEN'):
            if not re.fullmatch(r'[0-9a-f]{64}', env.get(name, '')):
                raise ValueError('Restore installer-generated gateway/collaboration tokens')
        if (env['PHX_HOST'] != config['management_host'] or env['RAWPAIR_PREVIEW_DOMAIN'] != config['preview_domain'] or
                env['DATABASE_URL'] != config['database_url'] or env['ORQOS_HOST_TOKEN'] != token):
            raise ValueError('Saved service configuration differs. Restore it or migrate configuration explicitly')
    else:
        environment(path, {
            'PHX_SERVER': 'true', 'PHX_HOST': config['management_host'],
            'CHECK_ORIGIN': 'https://' + config['management_host'], 'DATABASE_URL': config['database_url'],
            'SECRET_KEY_BASE': base64.b64encode(os.urandom(64)).decode(),
            'RAWPAIR_BACKENDS': 'host', 'ORQOS_URL': 'http://127.0.0.1:9080', 'ORQOS_HOST_TOKEN': token,
            'RAWPAIR_GATEWAY_TOKEN': os.urandom(32).hex(), 'RAWPAIR_COLLABORATION_TOKEN': os.urandom(32).hex(),
            'RAWPAIR_PREVIEW_DOMAIN': config['preview_domain'], 'RELEASE_TMP': '/var/lib/rawpair/tmp',
            'RELEASE_COOKIE': os.urandom(32).hex(),
        }, 'rawpair')
    site = Path('/etc/nginx/sites-available/rawpair-native')
    enabled = Path('/etc/nginx/sites-enabled/rawpair-native')
    if (site.exists() or enabled.is_symlink() or enabled.exists()) and not (ETC / 'nginx-owned').exists():
        raise ValueError('Existing nginx site is not setup-owned; refusing overwrite')
    # Journal ownership before replacing a file so retries recognize partial rendering.
    write(ETC / 'nginx-owned', 'rawpair-native-v1\n')
    write(site, render(ETC, HERE / 'nginx.conf.template', config['management_host'], config['preview_domain'],
                       config['certificate'], config['private_key'], config['mode'] == 'local'), mode=0o644)
    if enabled.exists() and not enabled.is_symlink():
        raise ValueError('nginx enabled site is not a symlink; refusing overwrite')
    if not enabled.is_symlink():
        enabled.symlink_to(site)
    elif enabled.resolve() != site:
        raise ValueError('nginx enabled site points elsewhere; refusing overwrite')
    run(['nginx', '-t'])


def release(action, login=None):
    env = os.environ.copy()
    env.update(values(ETC / 'rawpair.env'))
    env.pop('PHX_SERVER', None)
    if login:
        env.update(RAWPAIR_USERNAME=login['username'], RAWPAIR_PASSWORD=login['password'])
    args = ['runuser', '-u', 'rawpair', '--', '/opt/rawpair/bin/rawpair', 'eval',
            'Rawpair.Release.' + action + '()']
    if action == 'migrate':
        result = subprocess.run(args, env=env, text=True, capture_output=True)
        write(STATE / 'migration.log', result.stdout + result.stderr)
        if result.returncode:
            raise RuntimeError('Migration failed; inspect /var/lib/rawpair/migration.log, recover if needed and rerun setup')
        return result.stdout.strip()
    return run(args, env=env)


def backup(state):
    folder = STATE / 'backups' / (time.strftime('%Y%m%dT%H%M%S') + '-' + os.urandom(4).hex())
    folder.mkdir(parents=True, mode=0o700)
    print('Backing up configuration and database to ' + str(folder))
    shutil.copytree(ETC, folder / 'rawpair', symlinks=True)
    shutil.copytree('/etc/orqos', folder / 'orqos', symlinks=True)
    # Include certificate contents when configuration references external renewal paths.
    for field in ('certificate', 'private_key'):
        if state.get('config', {}).get(field):
            shutil.copy2(state['config'][field], folder / (field + '.pem'))
    target = folder / 'database.dump'
    with target.open('wb') as stream:
        result = subprocess.run(['pg_dump', '--format=custom', '--no-owner', '--no-acl'],
                                env=database(values(ETC / 'rawpair.env')['DATABASE_URL']), stdout=stream, stderr=subprocess.PIPE)
        stream.flush()
        os.fsync(stream.fileno())
    if result.returncode or target.stat().st_size == 0:
        raise RuntimeError('Database backup failed. Controls remain stopped; fix database access and rerun setup.')
    state['backup'] = str(folder)
    save(state)


def stop_controls():
    write(REQUIRED, 'setup required\n')
    run(['systemctl', 'stop', *UNITS])


def setup(config_file):
    root()
    system_checks()
    if not any((STATE / marker).exists() for marker in ('package-owner', 'source-owner')):
        raise ValueError('Installation is not managed by this installer; see docs/PACKAGES.md migration instructions')
    state = protected_json(PROGRESS) if PROGRESS.exists() else {'steps': []}
    if config_file:
        incoming = validate_config(protected_json(config_file), need_login=not state.get('completed_version'))
        if state.get('config'):
            old = dict(state['config'])
            supplied = dict(incoming)
            for field in ('first_user', 'certificate', 'private_key'):
                if field == 'first_user' or old.get('mode') == 'local':
                    old.pop(field, None)
                    supplied.pop(field, None)
            # Local database_url is generated after initial config; omitted on retries.
            if 'database_url' not in supplied:
                old.pop('database_url', None)
            if old != supplied:
                raise ValueError('Config differs from saved setup. Restore it or migrate configuration explicitly')
        else:
            run(['orqos-host-admin', 'check-subnet', incoming['subnet']])
            state['config'] = incoming
            state['local_database'] = not bool(incoming.get('database_url'))
            save(state)
    elif 'config' not in state:
        state['config'] = wizard()
        state['local_database'] = not bool(state['config'].get('database_url'))
        save(state)
    config = state['config']
    upgrading = bool(state.get('completed_version')) and state['completed_version'] != installed_version()
    stop_controls()
    # Stop the daemon only: existing workspace services remain independent.
    run(['systemctl', 'stop', 'orqos-host'])
    check_ports(config)
    if state.get('local_database'):
        run(['systemctl', 'start', 'postgresql'])
    if upgrading and state.get('backup_for') != installed_version():
        backup(state)
        state['backup_for'] = installed_version()
        save(state)
    try:
        if config['mode'] == 'local':
            local_tls(config)
            save(state)
        tls_validate(config['certificate'], config['private_key'], config['management_host'], config['preview_domain'])
        run(['orqos-host-admin', 'init', '--subnet', config['subnet']])
    except RuntimeError:
        raise
    # init rejects overlapping routes with an actionable message from the helper.
    for slot in ('project-a', 'project-b'):
        run(['orqos-host-admin', 'provision', slot])
    configure_database(state)
    service_config(state)
    run(['orqos-host-admin', 'validate'])
    if upgrading or 'migrated' not in state['steps']:
        release('migrate')
        if 'migrated' not in state['steps']:
            state['steps'].append('migrated')
        save(state)
    if 'login' not in state['steps']:
        release('bootstrap_user', config['first_user'])
        state['steps'].append('login')
        config.pop('first_user', None)
        state.pop('database_password', None)
        save(state)
    run(['nginx', '-t'])
    REQUIRED.unlink(missing_ok=True)
    try:
        run(['systemctl', 'enable', '--now', 'orqos-host', *UNITS, 'nginx'])
        run(['systemctl', 'reload', 'nginx'])
        wait_ready()
        errors = diagnostics()
        failed = [x for x in errors if not x['ok']]
        if failed:
            raise RuntimeError('; '.join(x['message'] for x in failed))
    except Exception:
        stop_controls()
        raise
    state['completed_version'] = installed_version()
    save(state)
    print(f'Login: https://{config["management_host"]}\nServices: orqos-host, rawpair-host, rawpair-collaboration and nginx active.\n'
          'Add collaborators: sudo rawpair user add\nAdd workspaces: sudo rawpair workspace add NAME')


def wait_ready():
    deadline = time.monotonic() + 45
    for port in (9080, 4000, 1234):
        while True:
            try:
                with socket.create_connection(('127.0.0.1', port), timeout=1):
                    break
            except OSError:
                if time.monotonic() >= deadline:
                    raise RuntimeError(f'Loopback listener {port} did not become ready; inspect service logs')
                time.sleep(0.5)


def diagnostics():
    checks = []
    def check(name, operation, message):
        try:
            operation()
            checks.append({'check': name, 'ok': True, 'message': 'ok'})
        except Exception:
            checks.append({'check': name, 'ok': False, 'message': message})
    check('platform and packages', system_checks, 'Install the matching package set on Ubuntu 24.04 with systemd/cgroup v2')
    def permissions():
        for path, group in [(ETC / 'rawpair.env', 'rawpair'), (ETC / 'collaboration.env', 'rawpair-collab'),
                            (ETC / 'nginx-secrets.conf', None), (Path('/etc/orqos/host.env'), None)]:
            info = path.lstat()
            expected_mode = 0o640 if group else 0o600
            expected_group = grp.getgrnam(group).gr_gid if group else 0
            if info.st_uid != 0 or info.st_gid != expected_group or stat.S_IMODE(info.st_mode) != expected_mode or stat.S_ISLNK(info.st_mode):
                raise ValueError('Invalid permissions')
        for directory in (ETC, STATE):
            info = directory.lstat()
            if info.st_uid != 0 or info.st_mode & 0o022 or stat.S_ISLNK(info.st_mode):
                raise ValueError('Setup/config directories must be protected and root owned')
        if PROGRESS.stat().st_uid != 0:
            raise ValueError('Progress must remain root owned')
        if REQUIRED.exists():
            raise ValueError('Setup is pending')
    check('configuration', permissions, 'Run sudo rawpair setup; protect root-owned configuration and complete pending upgrade')
    def tls():
        config = protected_json(PROGRESS)['config']
        tls_validate(config['certificate'], config['private_key'], config['management_host'], config['preview_domain'])
    check('TLS', tls, 'Renew a matching certificate covering management and wildcard preview hostnames; reload nginx')
    check('nginx', lambda: run(['nginx', '-t']), 'Run sudo nginx -t and resolve conflicting or invalid sites')
    check('workspace inventory and network', lambda: run(['orqos-host-admin', 'diagnose']),
          'Inspect root-owned inventory, account restrictions, subnet routes and nftables; run orqos-host-admin validate')
    for unit in ['orqos-host', *UNITS, 'nginx']:
        check(unit, lambda unit=unit: run(['systemctl', 'is-active', '--quiet', unit]), f'Inspect journalctl -u {unit}; rerun setup')
    check('database', lambda: run(['psql', '-XAtc', 'SELECT 1'], env=database(values(ETC / 'rawpair.env')['DATABASE_URL'])),
          'Check configured PostgreSQL connectivity and credentials')
    def reachable(port):
        with socket.create_connection(('127.0.0.1', port), timeout=3):
            pass
    for port in (9080, 4000, 1234):
        check(f'listener {port}', lambda port=port: reachable(port), f'Inspect service logs for loopback port {port}')
    check('forwarding', lambda: require(Path('/proc/sys/net/ipv4/ip_forward').read_text().strip() == '1'),
          'Enable net.ipv4.ip_forward=1 via orqos-host-admin init')
    return checks


def require(value):
    if not value:
        raise ValueError('Check failed')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    initialize = commands.add_parser('setup')
    initialize.add_argument('--config')
    doctor = commands.add_parser('doctor')
    doctor.add_argument('--json', action='store_true')
    workspace = commands.add_parser('workspace')
    workspace.add_argument('action', choices=['add'])
    workspace.add_argument('name')
    user = commands.add_parser('user')
    user.add_argument('action', choices=['add'])
    commands.add_parser('migrate')
    args = parser.parse_args()
    if args.command == 'doctor':
        checks = diagnostics()
        print(json.dumps({'ok': all(x['ok'] for x in checks), 'checks': checks}) if args.json else
              '\n'.join(('OK ' if x['ok'] else 'FAIL ') + x['check'] + ': ' + x['message'] for x in checks))
        return 0 if all(x['ok'] for x in checks) else 1
    root()
    os.umask(0o077)
    if not STATE.exists():
        raise ValueError('Install the RawPair package before running administration commands')
    with (STATE / '.setup.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.command == 'setup':
            try:
                setup(args.config)
            except Exception:
                owned = any((STATE / marker).exists() for marker in ('package-owner', 'source-owner'))
                if owned and PROGRESS.exists() and (ETC / 'rawpair.env').exists():
                    stop_controls()
                state = protected_json(PROGRESS) if PROGRESS.exists() else {}
                print('Setup incomplete. Rerun sudo rawpair setup to resume. Controls remain stopped.\n'
                      'Recovery: restore saved configuration and use pg_restore with the backup after inspecting the failure.\n'
                      'Database rollback is manual. Backup: ' + state.get('backup', 'none yet'), file=sys.stderr)
                raise
        elif args.command == 'workspace':
            run(['orqos-host-admin', 'provision', args.name], visible=True)
        elif args.command == 'user':
            login = credentials()
            validate_config({'mode': 'local', 'first_user': login})
            release('create_user', login)
            print('Login created')
        else:
            stop_controls()
            state = protected_json(PROGRESS)
            backup(state)
            release('migrate')
            print('Migrations complete. Controls are stopped; run sudo rawpair setup to validate and start.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, RuntimeError, OSError, KeyError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
