#!/usr/bin/env python3
"""Compare the installed result with the active host's Nix declarations."""
import argparse
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--home-only', action='store_true', help='Check Home Manager before runtime installers and services.')
parser.add_argument('--no-services', action='store_true', help='Verify packages in a disposable home without a login user manager.')
args = parser.parse_args()
home = Path.home()
expected = json.loads((home / '.config/dotfiles/expected.json').read_text())
env = os.environ.copy()
env['PATH'] = ':'.join(expected['runtimePaths'])
failures = []


def require(condition, message):
    if not condition:
        failures.append(message)


def run(command):
    return subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env, timeout=60)


for name, executable in expected['tools'].items():
    actual = shutil.which(name, path=env['PATH'])
    require(actual is not None and Path(actual).resolve() == Path(executable).resolve(),
            f'{name}: expected {executable}, found {actual}')
    if actual:
        flags = {'unzip': ['-v'], 'process-compose': ['version']}.get(name, ['--version'])
        result = run([actual, *flags])
        require(result.returncode == 0, f'{name} could not run: {result.stdout[:300]}')
require('CODEX_HOME' not in os.environ, 'CODEX_HOME is still set. Start a fresh shell.')
require(not (home / '.gitconfig').is_symlink(), '~/.gitconfig must stay writable.')
require(not (home / '.config/fish/completions/grok.fish').is_symlink(), 'Grok completion must stay writable.')
for name in ('env', '1password-token'):
    path = home / '.config/agents' / name
    if path.exists():
        require(not path.is_symlink() and stat.S_IMODE(path.stat().st_mode) == 0o600,
                f'{path} must be a private regular file with mode 0600.')
if expected['host'] == 'mac' and not args.home_only:
    for category, option in [('brews', '--formula'), ('casks', '--cask')]:
        for package in expected['brew'][category]:
            result = run(['/opt/homebrew/bin/brew', 'list', option, '--versions', package])
            require(result.returncode == 0 and bool(result.stdout.strip()), f'Homebrew {package} is missing.')
    actual = shutil.which('pnpm', path=env['PATH'])
    require(actual == '/opt/homebrew/bin/pnpm', f'Mac pnpm must come from Homebrew, found {actual}')
    if actual:
        require(run([actual, '--version']).returncode == 0, 'Homebrew pnpm could not execute.')
if not args.home_only:
    for package, version in expected['npmPackages'].items():
        directory = home / '.npm-global/lib/node_modules' / package
        metadata = directory / 'package.json'
        require(metadata.is_file(), f'npm package {package} is missing.')
        if metadata.is_file():
            info = json.loads(metadata.read_text())
            require(info['version'] == version, f'{package}: expected version {version}, found {info["version"]}')
            binaries = info.get('bin', {})
            if isinstance(binaries, str):
                binaries = {package.rsplit('/', 1)[-1]: binaries}
            for name, relative in binaries.items():
                actual = shutil.which(name, path=env['PATH'])
                require(actual is not None and Path(actual).resolve().is_relative_to(directory.resolve()),
                        f'{package}: {name} is shadowed by {actual}')
            primary = next(iter(binaries), None)
            if primary:
                result = run([primary, '--version'])
                require(result.returncode == 0, f'{package} could not execute: {result.stdout[:300]}')
    for tool in expected['vendorTools']:
        target = home / ('.opencode/bin/opencode' if tool == 'opencode' else f'.local/bin/{tool}')
        actual = shutil.which(tool, path=env['PATH'])
        require(target.is_file() and actual is not None and Path(actual).resolve() == target.resolve(),
                f'{tool}: expected writable native installation {target}, found {actual}')
        if actual:
            result = run([actual, '--version'])
            require(result.returncode == 0, f'{tool} could not run: {result.stdout[:300]}')
    if expected['host'] == 'homelab' and not args.no_services:
        for service in ('opencode-web', 't3code', 'process-compose'):
            for state in ('is-enabled', 'is-active'):
                require(run(['systemctl', '--user', state, '--quiet', service + '.service']).returncode == 0,
                        f'{service} failed {state}')
            pid = run(['systemctl', '--user', 'show', service + '.service', '--property=MainPID', '--value']).stdout.strip()
            process = Path('/proc') / pid / 'environ'
            if process.is_file():
                running = dict(entry.split('=', 1) for entry in process.read_text().split('\0') if '=' in entry)
                require(running.get('PATH') == env['PATH'], f'{service} uses a stale runtime PATH. Restart it when sessions can stop.')
                require('CODEX_HOME' not in running, f'{service} still sets CODEX_HOME.')
if failures:
    print('\n'.join('FAIL ' + message for message in failures), file=sys.stderr)
    raise SystemExit(1)
print(f"PASS {expected['host']}: installed providers, executable tools, mutable files, and private file permissions")
