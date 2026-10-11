#!/usr/bin/python3
"""Privileged acceptance checks on disposable Ubuntu GitHub-hosted runners only."""
import argparse
import http.client
from http.cookies import SimpleCookie
import json
import os
from pathlib import Path
import re
import secrets
import socket
import ssl
import subprocess
import sys
import time
from urllib.parse import urlencode, urlsplit

sys.path.insert(0, '/usr/lib/rawpair')
import setup


class Browser:
    def __init__(self):
        self.cookies = {}
        self.csrf = None
        self.context = ssl.create_default_context(cafile=Path(subprocess.check_output(['mkcert', '-CAROOT'], text=True).strip()) / 'rootCA.pem')

    def request(self, method, path, data=None, host='rawpair.localhost', expected=200):
        connection = http.client.HTTPSConnection(host, context=self.context, timeout=30)
        connection._create_connection = lambda address, timeout, source_address=None: socket.create_connection(('127.0.0.1', 443), timeout)
        headers = {'cookie': self.cookies.get(host, ''), 'origin': 'https://' + host}
        if self.csrf:
            headers['x-csrf-token'] = self.csrf
        if data is not None:
            headers['content-type'] = 'application/json'
        connection.request(method, path, json.dumps(data) if data is not None else None, headers)
        response = connection.getresponse()
        content = response.read().decode()
        cookies = [value for key, value in response.getheaders() if key.lower() == 'set-cookie']
        if cookies:
            parsed = SimpleCookie()
            parsed.load(self.cookies.get(host, ''))
            for value in cookies:
                parsed.load(value)
            self.cookies[host] = '; '.join(key + '=' + value.value for key, value in parsed.items())
        location = response.getheader('location')
        assert response.status == expected, (method, path, response.status, content[:1000])
        connection.close()
        return content, location

    def login(self, username, password):
        content, _ = self.request('GET', '/')
        self.csrf = re.search(r'name="_csrf_token" value="([^"]+)"', content)[1]
        self.request('POST', '/enter', {'username': username, 'password': password}, expected=302)
        content, _ = self.request('GET', '/workspaces')
        self.csrf = re.search(r'name="csrf-token" content="([^"]+)"', content)[1]

    def api(self, method, path, data=None):
        return json.loads(self.request(method, path, data)[0])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', required=True)
    args = parser.parse_args()
    assert os.geteuid() == 0 and os.environ.get('GITHUB_ACTIONS') == 'true', 'Disposable CI host only'
    for unit in setup.UNITS + ['orqos-host']:
        assert subprocess.run(['systemctl', 'is-active', '--quiet', unit]).returncode != 0
    assert not Path('/etc/rawpair/rawpair.env').exists()
    password = secrets.token_urlsafe(32)
    fixture = Path('/var/lib/rawpair/acceptance.json')
    config = {'mode': 'local', 'first_user': {'username': 'acceptance', 'password': password}}
    setup.write(fixture, json.dumps(config))
    subprocess.run(['rawpair', 'setup', '--config', str(fixture)], check=True)
    assert Path('/var/lib/rawpair/setup.json').stat().st_uid == 0
    original = Path('/etc/rawpair/rawpair.env').read_bytes()
    subprocess.run(['rawpair', 'setup', '--config', str(fixture)], check=True)
    assert Path('/etc/rawpair/rawpair.env').read_bytes() == original
    subprocess.run(['rawpair', 'doctor', '--json'], check=True)
    member_password = secrets.token_urlsafe(32)
    setup.release('create_user', {'username': 'collaborator', 'password': member_password})
    owner, member, anonymous = Browser(), Browser(), Browser()
    owner.login('acceptance', password)
    member.login('collaborator', member_password)
    workspaces, tickets = [], []
    for suffix in ('a', 'b'):
        workspace = owner.api('POST', '/api/workspaces', {'workspace': {'name': 'Package project ' + suffix,
                               'slug': 'package-project-' + suffix, 'backend': 'host', 'host_slot': 'project-' + suffix}})
        workspace = owner.api('POST', f'/api/workspaces/{workspace["id"]}/actions', {'operation': 'start'})
        assert workspace['observed']['status'] == 'running', workspace
        owner.api('POST', f'/api/workspaces/{workspace["id"]}/members', {'username': 'collaborator', 'role': 'member'})
        record = json.loads(Path('/var/lib/orqos/host', workspace['runtime_id'] + '.json').read_text())
        # Use the actual shared tmux shell, so the HTTP process belongs to its workspace cgroup/netns.
        command = ['runuser', '-u', record['user'], '--', 'tmux', '-S', '/run/' + record['runtime'] + '/tmux.sock']
        subprocess.run(command + ['send-keys', '-t', 'shared', 'echo package-content > smoke.txt; python3 -m http.server 3000 --bind 127.0.0.1', 'Enter'], check=True)
        time.sleep(1)
        file_path = f'/api/workspaces/{workspace["slug"]}/files/smoke.txt'
        assert 'package-content' in owner.api('GET', file_path)['contents']
        member.api('PUT', file_path, {'content': 'shared package edit\n'})
        assert owner.api('GET', file_path)['contents'] == 'shared package edit\n'
        for browser in (owner, member):
            tickets.append(browser.api('GET', f'/api/workspaces/{workspace["slug"]}/collaboration?' + urlencode({'path': 'smoke.txt'})))
        terminal = workspace['terminal']
        anonymous.request('GET', terminal, expected=403)
        member.request('GET', terminal)
        owner.request('GET', terminal)
        app = owner.api('POST', f'/api/workspaces/{workspace["id"]}/applications', {'application': {'name': 'web', 'port': 3000}})
        app_host = urlsplit(app['url']).hostname
        anonymous.request('GET', '/', host=app_host, expected=302)
        _, claim = member.request('GET', '/previews/' + app_host, expected=302)
        parsed = urlsplit(claim)
        member.request('GET', parsed.path + '?' + parsed.query, host=app_host, expected=302)
        for _ in range(20):
            try:
                body, _ = member.request('GET', '/smoke.txt', host=app_host)
                break
            except AssertionError:
                time.sleep(0.5)
        else:
            raise AssertionError('Private preview did not become ready')
        assert body == 'shared package edit\n'
        workspaces.append(dict(workspace, record=record))
    setup.write(Path('/var/lib/rawpair/collaboration-acceptance.json'), json.dumps({'tickets': tickets[:2], 'terminal': {'path': workspaces[0]['terminal'], 'cookies': [owner.cookies['rawpair.localhost'], member.cookies['rawpair.localhost']]}}))
    subprocess.run(['node', str(Path(__file__).with_name('installed-collaboration.mjs'))], check=True)
    owner.api('POST', f'/api/workspaces/{workspaces[0]["id"]}/actions', {'operation': 'stop'})
    assert owner.api('GET', f'/api/workspaces/{workspaces[1]["id"]}')['observed']['status'] == 'running'
    subprocess.run(['systemctl', 'restart', 'orqos-host', *setup.UNITS], check=True)
    setup.wait_ready()
    assert owner.api('GET', f'/api/workspaces/{workspaces[1]["id"]}')['observed']['status'] == 'running'
    # Keep workspace B running for the coordinated upgrade and removal checks.
    setup.write(Path('/var/lib/rawpair/acceptance-state.json'), json.dumps({'workspaces': workspaces, 'tag': args.tag}))
    print('Installed packages: login, two workspaces, shared files/editor tickets/terminal, private previews, independent stop and control restart passed')


if __name__ == '__main__':
    main()
