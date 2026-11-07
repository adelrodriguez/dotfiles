#!/usr/bin/env python3
"""Run the OpenCode verifier against isolated HTTP, process, and service fixtures."""
from contextlib import redirect_stdout
import base64
import io
import json
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import urllib.error
import urllib.parse

VERIFY = Path(__file__).resolve().parents[1] / 'opencode/verify.py'
LOCAL = 'http://127.0.0.1:4096'
PUBLIC = 'https://opencode.homelab.adel.wtf'


class OpenCode(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        home = self.root / 'home'
        service = home / 'services/opencode'
        binary = service / 'bin/opencode'
        binary.parent.mkdir(parents=True)
        binary.touch()
        config = home / '.config/opencode/service.json'
        config.parent.mkdir(parents=True)
        config.write_text(json.dumps({'password': 'fixture-password'}))
        self.auth = 'Basic ' + base64.b64encode(b'opencode:fixture-password').decode()
        self.env = {'HOME': str(home), 'OPENCODE_PORT': '4096',
                    'XDG_CONFIG_HOME': str(home / '.config'), 'XDG_DATA_HOME': str(home / '.local/share'),
                    'XDG_STATE_HOME': str(home / '.local/state'), 'XDG_CACHE_HOME': str(home / '.cache'),
                    'FNM_DIR': str(home / '.local/share/fnm')}
        pid = 12345
        process = self.root / 'proc' / str(pid)
        (process / 'root/etc').mkdir(parents=True)
        (process / 'exe').symlink_to(binary)
        release = process / 'root/etc/os-release'
        release.write_text('ID=ubuntu\n')
        environment = {'DBUS_SESSION_BUS_ADDRESS': f'unix:path=/run/user/{os.getuid()}/bus'}
        for variable, directory in [('XDG_DATA_HOME', 'data'), ('XDG_STATE_HOME', 'state'), ('XDG_CACHE_HOME', 'cache')]:
            target = service / 'runtime' / directory
            target.mkdir(parents=True)
            xdg = service / 'runtime' / f'xdg-{directory}'
            xdg.mkdir()
            (xdg / 'opencode').symlink_to(target)
            environment[variable] = str(xdg)
        (process / 'environ').write_text('\0'.join(f'{key}={value}' for key, value in environment.items()))
        self.paths = {f'/proc/{pid}': process, '/etc/os-release': release}
        self.paths.update({str(path): path for path in service.glob('runtime/xdg-*')})
        self.home = home
        self.pages = {base: b'<html><head><title>OpenCode</title></head></html>' for base in (LOCAL, PUBLIC)}
        self.api = {
            (base, path): value
            for base in (LOCAL, PUBLIC)
            for path, value in [
                ('/api/info', {'version': '2.2.6', 'pid': pid}),
                ('/api/session?limit=1', {'data': [{'id': 'fixture-session'}]}),
                ('/api/config', [{'type': 'document', 'info': {
                    'permissions': [{'action': '*', 'resource': '*', 'effect': 'allow'}],
                }}]),
            ]
        }
        self.auth_status = 401
        self.outputs = {
            (str(binary), '--version'): 'opencode v2.2.6\n',
            ('systemctl', '--user', 'show', 'opencode-web.service', '--property=MainPID', '--value'): f'{pid}\n',
            ('ss', '-ltnp'): f'LISTEN 0 128 127.0.0.1:4096 0.0.0.0:* users:(("opencode",pid={pid},fd=3))\n',
            ('docker', 'compose', 'ps', '-q', 'opencode'): '',
        }
        self.statuses = {
            ('systemctl', '--user', operation, '--quiet', 'opencode-web.service'): 0
            for operation in ('is-active', 'is-enabled')
        }
        self.statuses[('systemctl', '--user', 'show', 't3code.service', '--property=ActiveState')] = 0

    def request(self, request, timeout):
        url = urllib.parse.urlsplit(request.full_url)
        base = f'{url.scheme}://{url.netloc}'
        path = url.path + (f'?{url.query}' if url.query else '')
        if path == '/':
            return io.BytesIO(self.pages[base])
        if base == LOCAL:
            if request.get_header('Authorization') != self.auth and self.auth_status != 200:
                raise urllib.error.HTTPError(request.full_url, self.auth_status, 'Fixture authentication', {}, None)
        else:
            self.assertIsNone(request.get_header('Authorization'))
        return io.BytesIO(json.dumps(self.api[base, path]).encode())

    def command(self, command, **kwargs):
        result = subprocess.CompletedProcess(command, self.statuses[tuple(command)])
        if kwargs.get('check'):
            result.check_returncode()
        return result

    def verify(self):
        output = io.StringIO()
        with patch.dict(os.environ, self.env, clear=True), \
             patch('pathlib.Path', side_effect=self.paths.__getitem__) as path, \
             patch('urllib.request.urlopen', side_effect=self.request), \
             patch('subprocess.check_output', side_effect=lambda command, **kwargs: self.outputs[tuple(command)]), \
             patch('subprocess.run', side_effect=self.command), redirect_stdout(output):
            path.home.return_value = self.home
            runpy.run_path(str(VERIFY), run_name='__main__')
        return output.getvalue()

    def test_accepts_title_attributes_and_completes_verification(self):
        for base in (LOCAL, PUBLIC):
            for title in [b'<title>OpenCode</title>', b'<title data-sm>OpenCode</title>',
                          b'<TITLE lang="en" data-sm data-value=">">OpenCode</TITLE>',
                          b"<title data-sm='true'>Open&#67;ode</title>"]:
                with self.subTest(base=base, title=title):
                    self.pages[base] = b'<!doctype html><html><head>' + title + b'</head></html>'
                    output = self.verify()
                    for message in (f'PASS {LOCAL}:', f'PASS {PUBLIC}:', 'PASS loaded global configuration',
                                    'PASS copied session history', 'PASS native service, boot startup'):
                        self.assertIn(message, output)
            self.pages[base] = b'<title>OpenCode</title>'

    def test_rejects_missing_or_wrong_titles(self):
        for base in (LOCAL, PUBLIC):
            for title in [b'', b'<title data-sm></title>', b'<title data-sm>Other</title>',
                          b'<title data-sm>OpenCode docs</title>', b'<title data-sm>OpenCode',
                          b'<!-- <title>OpenCode</title> -->',
                          b'<script>const title = "<title>OpenCode</title>";</script>']:
                with self.subTest(base=base, title=title):
                    self.pages[base] = title
                    with self.assertRaisesRegex(AssertionError, base.replace('.', r'\.')):
                        self.verify()
            self.pages[base] = b'<title>OpenCode</title>'

    def test_rejects_unauthenticated_backend_access(self):
        self.auth_status = 200
        with self.assertRaisesRegex(AssertionError, 'backend accepted an unauthenticated request'):
            self.verify()

    def test_rejects_wrong_versions_and_missing_sessions(self):
        for base in (LOCAL, PUBLIC):
            for path, value in [('/api/info', {'version': '0.0.0', 'pid': 12345}),
                                ('/api/session?limit=1', {'data': []})]:
                with self.subTest(base=base, path=path):
                    original = self.api[base, path]
                    self.api[base, path] = value
                    with self.assertRaises(AssertionError):
                        self.verify()
                    self.api[base, path] = original

    def test_rejects_denied_file_permissions(self):
        self.api[LOCAL, '/api/config'] = []
        with self.assertRaisesRegex(AssertionError, 'read.*etc/hosts'):
            self.verify()

    def test_rejects_inactive_or_disabled_service(self):
        for operation in ('is-active', 'is-enabled'):
            with self.subTest(operation=operation):
                command = ('systemctl', '--user', operation, '--quiet', 'opencode-web.service')
                self.statuses[command] = 1
                with self.assertRaises(subprocess.CalledProcessError):
                    self.verify()
                self.statuses[command] = 0


if __name__ == '__main__':
    unittest.main()
