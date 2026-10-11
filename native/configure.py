#!/usr/bin/python3
"""Shared configuration primitives for package and source setup."""
import grp
import os
from pathlib import Path
import shlex
import tempfile


def write(path, text, group=None, mode=None):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix='.' + path.name, dir=path.parent)
    try:
        with os.fdopen(descriptor, 'w') as stream:
            stream.write(text)
            os.fchmod(stream.fileno(), mode or (0o640 if group else 0o600))
            if group:
                os.fchown(stream.fileno(), 0, grp.getgrnam(group).gr_gid)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def values(path):
    result = {}
    for line in Path(path).read_text().splitlines():
        if line and not line.startswith('#'):
            key, value = line.split('=', 1)
            parsed = shlex.split(value)
            result[key] = parsed[0] if parsed else ''
    return result


def environment(path, entries, group):
    def quote(value):
        if '\n' in value or '\r' in value or '\x00' in value:
            raise ValueError('Environment values must be single-line strings')
        return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'
    write(path, ''.join(f'{key}={quote(value)}\n' for key, value in entries.items()), group)


def render(configuration, template, management, preview, cert, key, local):
    config = Path(configuration)
    env = values(config / 'rawpair.env')
    environment(config / 'collaboration.env', {
        'RAWPAIR_AUTH_URL': 'http://127.0.0.1:4000/internal/collaboration/authorize',
        'RAWPAIR_COLLABORATION_TOKEN': env['RAWPAIR_COLLABORATION_TOKEN'],
        'RAWPAIR_COLLABORATION_DIR': '/var/lib/rawpair-collaboration',
        'RAWPAIR_ORIGIN': 'https://' + management,
    }, 'rawpair-collab')
    write(config / 'nginx-secrets.conf',
          f"set $rawpair_gateway_token '{env['RAWPAIR_GATEWAY_TOKEN']}';\n"
          f"set $orqos_host_token '{env['ORQOS_HOST_TOKEN']}';\n")
    rendered = Path(template).read_text().replace('__MANAGEMENT_HOST__', management).replace('__PREVIEW_DOMAIN__', preview)
    rendered = rendered.replace('/etc/rawpair/tls/cert.pem', cert).replace('/etc/rawpair/tls/key.pem', key)
    if local:
        rendered = rendered.replace('listen 443 ssl;', 'listen 127.0.0.1:443 ssl;').replace('listen [::]:443 ssl;', 'listen [::1]:443 ssl;')
    return rendered
