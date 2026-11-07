#!/usr/bin/env python3
"""Inspect this domain without changing installed state."""
import json
import os
from pathlib import Path
import subprocess
import sys

home = Path.home()
expected = json.loads((home / '.config/dotfiles/expected.json').read_text())
env = os.environ.copy()
runtime_path = ':'.join(expected['runtimePaths'])
failures = []


def require(condition, message):
    if not condition:
        failures.append(message)


def run(command):
    return subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env, timeout=60)


for service in json.loads((home / '.config/dotfiles/services.json').read_text()):
    for state in ('is-enabled', 'is-active'):
        require(run(['systemctl', '--user', state, '--quiet', service + '.service']).returncode == 0,
                f'{service} failed {state}')
    pid = run(['systemctl', '--user', 'show', service + '.service', '--property=MainPID', '--value']).stdout.strip()
    process = Path('/proc') / pid / 'environ'
    if process.is_file():
        running = dict(entry.split('=', 1) for entry in process.read_text().split('\0') if '=' in entry)
        require(running.get('PATH') == runtime_path, f'{service} uses a stale runtime PATH. Restart it when sessions can stop.')
        require('CODEX_HOME' not in running, f'{service} still sets CODEX_HOME.')
if failures:
    print('\n'.join('FAIL ' + message for message in failures), file=sys.stderr)
    raise SystemExit(1)
print('PASS declared user services')
