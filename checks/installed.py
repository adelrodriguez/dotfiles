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
observed_path = env.get('PATH', os.defpath)
runtime_path = ':'.join(expected['runtimePaths'])
failures = []


def require(condition, message):
    if not condition:
        failures.append(message)


def run(command):
    return subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env, timeout=60)


for name, executable in expected['tools'].items():
    actual = shutil.which(name, path=observed_path)
    matches = actual is not None and Path(actual).resolve() == Path(executable).resolve()
    if name == 'node' and actual and not matches:
        # fnm owns an installed project version. Ask fnm to resolve the nearest
        # version file, without changing this shell or a persistent default alias.
        has_version_file = any((directory / filename).is_file()
                               for directory in [Path.cwd(), *Path.cwd().parents]
                               for filename in ('.nvmrc', '.node-version'))
        fnm = expected['tools'].get('fnm') or shutil.which('fnm', path=runtime_path)
        if has_version_file and fnm and os.access(fnm, os.X_OK):
            selected = run([fnm, 'exec', '--version-file-strategy', 'recursive', '--', 'node', '-p', 'process.execPath'])
            lines = selected.stdout.strip().splitlines()
            matches = selected.returncode == 0 and bool(lines) and Path(actual).resolve() == Path(lines[-1]).resolve()
    require(matches, f'{name}: expected {executable} or the fnm project version, found {actual}'
            if name == 'node' else f'{name}: expected {executable}, found {actual}')
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
    for package in expected['brew']['brews']:
        result = run(['/opt/homebrew/bin/brew', 'list', '--formula', '--versions', package])
        require(result.returncode == 0 and bool(result.stdout.strip()), f'Homebrew {package} is missing.')
    # Definition metadata can omit the tap under an isolated HOME. Check the
    # installed token and use its install receipt for the recorded source.
    result = subprocess.run(['/opt/homebrew/bin/brew', 'info', '--cask', '--json=v2', '--installed'],
                            env=env, text=True, capture_output=True, timeout=60)
    require(result.returncode == 0, f'Could not inspect installed Homebrew casks: {result.stderr[:300]}')
    casks = json.loads(result.stdout)['casks'] if result.returncode == 0 else []
    installed_casks = {cask['token'] for cask in casks if cask['installed']}
    room = subprocess.run(['/opt/homebrew/bin/brew', '--caskroom'], env=env,
                          text=True, capture_output=True, timeout=60)
    require(room.returncode == 0, f'Could not locate the Homebrew Caskroom: {room.stderr[:300]}')
    caskroom = Path(room.stdout.strip()) if room.returncode == 0 else None
    for package in expected['brew']['casks']:
        token = package.rsplit('/', 1)[-1]
        require(token in installed_casks, f'Homebrew {package} is missing.')
        if '/' in package and token in installed_casks:
            tap = package.rsplit('/', 1)[0]
            receipt = caskroom / token / '.metadata/INSTALL_RECEIPT.json' if caskroom else None
            recorded_tap = None
            if receipt and receipt.is_file():
                recorded_tap = json.loads(receipt.read_text())['source']['tap']
            require(recorded_tap == tap,
                    f'Homebrew {package}: expected installed tap {tap}, found {recorded_tap or "no install receipt"}.')
    actual = shutil.which('pnpm', path=observed_path)
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
                actual = shutil.which(name, path=observed_path)
                require(actual is not None and Path(actual).resolve().is_relative_to(directory.resolve()),
                        f'{package}: {name} is shadowed by {actual}')
            primary = next(iter(binaries), None)
            primary_executable = shutil.which(primary, path=observed_path) if primary else None
            if primary_executable:
                result = run([primary_executable, '--version'])
                require(result.returncode == 0, f'{package} could not execute: {result.stdout[:300]}')
    for tool in expected['vendorTools']:
        target = home / ('.opencode/bin/opencode' if tool == 'opencode' else f'.local/bin/{tool}')
        actual = shutil.which(tool, path=observed_path)
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
                require(running.get('PATH') == runtime_path, f'{service} uses a stale runtime PATH. Restart it when sessions can stop.')
                require('CODEX_HOME' not in running, f'{service} still sets CODEX_HOME.')
if failures:
    print('\n'.join('FAIL ' + message for message in failures), file=sys.stderr)
    raise SystemExit(1)
print(f"PASS {expected['host']}: installed providers, executable tools, mutable files, and private file permissions")
