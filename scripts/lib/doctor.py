"""Assess dotfiles-managed state. No installs, writes, network requests, or restarts."""
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import stat
import subprocess
import sys


def main():
    repo = Path(__file__).resolve().parents[2]
    home = Path.home()
    observed_path, codex_home, runtime_path = sys.argv[1:]
    findings = []

    def fail(path, reason, repair):
        findings.append(f"{path}: {reason}. {repair}")

    def command(args):
        try:
            environment = {**os.environ, 'GIT_OPTIONAL_LOCKS': '0', 'HOMEBREW_NO_AUTO_UPDATE': '1'}
            result = subprocess.run(args, capture_output=True, text=True, timeout=15, env=environment)
            return result.returncode, result.stdout.strip()
        except (OSError, subprocess.TimeoutExpired):
            return 1, ''

    def entries(path):
        if not path.is_file():
            return []
        return [line.strip() for line in path.read_text().splitlines() if line.strip() and not line.lstrip().startswith('#')]

    def digest(path):
        return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None

    profile_file = home / '.config/dotfiles/profile'
    profile = profile_file.read_text().strip() if profile_file.is_file() else ''
    if not re.fullmatch('[a-z0-9-]+', profile) or not (repo / 'profiles' / (profile + '.txt')).is_file():
        print('No valid profile recorded. Run scripts/install.sh <mac|server>.')
        return 2
    roles = entries(repo / 'profiles' / (profile + '.txt'))
    if not roles or any(not re.fullmatch('[a-z0-9-]+', role) or not (repo / 'roles' / role).is_dir() for role in roles):
        print(f'Invalid roles in profiles/{profile}.txt')
        return 2
    print(f'Checking {platform.node()} with the {profile} profile')
    if codex_home:
        fail('CODEX_HOME', 'a custom config home is still exported', 'Start a fresh shell using the default ~/.codex')

    for role in roles:
        root = repo / 'roles' / role / 'home'
        for source in sorted(root.rglob('*')):
            if not source.is_file():
                continue
            rel = source.relative_to(root)
            target = home / rel
            if str(rel) == '.gitconfig':
                code, includes = command(['git', 'config', '--file', str(target), '--get-all', 'include.path'])
                valid = not target.is_symlink() and code == 0 and str(source) in includes.splitlines()
            elif str(rel) == '.config/fish/completions/grok.fish':
                valid = not target.is_symlink() and digest(source) == digest(target)
            else:
                valid = target.is_symlink() and target.resolve() == source.resolve() and target.exists()
            if not valid:
                fail(rel, 'managed configuration differs or is missing', 'Run scripts/link.sh')

    for link in (home / '.config').rglob('*'):
        if not link.is_symlink() or link.exists() or link.parent.name != 'skills':
            continue
        target = Path(os.path.abspath(link.parent / os.readlink(link)))
        if target == home / '.agents/skills' / link.name:
            fail(link.relative_to(home), 'alias points to a removed shared skill', 'Run scripts/link.sh')

    for name in ('apm.yml', 'apm.lock.yaml'):
        source, target = repo / 'agents' / name, home / '.apm' / name
        if digest(source) != digest(target) or not target.is_file():
            label = 'agent lock' if name.endswith('lock.yaml') else 'agent manifest'
            fail(label, 'checkout and deployed copy differ', 'Follow agents/AGENTS.md before make -C ~ agents:sync')
    lock = repo / 'agents/apm.lock.yaml'
    if lock.is_file():
        if '.claude/rules/' in lock.read_text():
            for rel in ('.codex/AGENTS.md', '.config/opencode/AGENTS.md'):
                if not (home / rel).is_file():
                    fail(rel, 'compiled global instructions are missing', 'Run make -C ~ agents:sync after reconciling the agent lock')
        for rel, expected in re.findall(r'^    (.+): sha256:([a-f0-9]{64})$', lock.read_text(), re.M):
            path = Path(rel)
            if path.is_absolute() or '..' in path.parts:
                fail('agent lock', 'a deployed path is outside the home directory', 'Repair the lock before deployment')
            elif digest(home / path) != expected:
                fail(rel, 'deployed file differs or is missing', 'Preserve local edits and follow agents/AGENTS.md')

    aliases = {'1password-cli': 'op', 'bubblewrap': 'bwrap', 'neovim': 'nvim', 'ripgrep': 'rg'}
    npm_packages = []
    extras = []
    for role in roles:
        packages = repo / 'roles' / role / 'packages'
        npm_packages.extend(entries(packages / 'npm.txt'))
        extras.extend(entries(packages / 'extras.txt'))
        if platform.system() == 'Linux':
            for package in entries(packages / 'apt.txt'):
                code, status_text = command(['dpkg-query', '-W', '-f=${Status}', package])
                if code or status_text != 'install ok installed':
                    fail(package, 'APT package is missing', 'Run scripts/package.sh install')
    if platform.system() == 'Linux':
        for package in extras:
            binary = aliases.get(package, package)
            if not shutil.which(binary, path=runtime_path):
                fail(package, 'upstream tool is missing', 'Run scripts/package.sh install')
    elif platform.system() == 'Darwin':
        brewfiles = [repo / 'roles' / role / 'packages/Brewfile' for role in roles]
        declarations = [(kind, name) for file in brewfiles if file.is_file() for kind, name in re.findall(r'^(brew|cask) "([^"]+)"', file.read_text(), re.M)]
        if declarations:
            code, output = command(['brew', 'info', '--json=v2', '--installed'])
            try:
                installed = json.loads(output) if code == 0 else {}
                formulae = {name for item in installed.get('formulae', []) for name in [item['name'], item['full_name'], *item.get('aliases', [])]}
                casks = {name for item in installed.get('casks', []) for name in [item['token'], item.get('full_token', item['token'])]}
                for kind, name in declarations:
                    if name not in (formulae if kind == 'brew' else casks) and name.split('/')[-1] not in (formulae if kind == 'brew' else casks):
                        fail(name, 'Homebrew package is missing', 'Run scripts/package.sh install')
            except (ValueError, KeyError):
                fail('Homebrew', 'installed package inventory could not be read', 'Check brew info --json=v2 --installed')

    for package in npm_packages:
        metadata = home / '.npm-global/lib/node_modules' / package / 'package.json'
        try:
            installed = json.loads(metadata.read_text())
        except (OSError, ValueError):
            installed = {}
        if installed.get('name') != package or not installed.get('version'):
            fail(package, 'global npm package is missing', 'Run scripts/package.sh install')
    shared = []
    manages_node = 'node' in extras or platform.system() == 'Darwin' and any(
        'brew "fnm"' in entries(repo / 'roles' / role / 'packages/Brewfile') for role in roles
    )
    if manages_node:
        node = home / '.local/share/fnm/aliases/default/bin/node'
        for directory in (Path.cwd(), *Path.cwd().parents):
            version_file = directory / '.node-version'
            if not version_file.is_file():
                continue
            version = version_file.read_text().strip().removeprefix('v')
            if re.fullmatch(r'[0-9]+(?:\.[0-9]+){0,2}', version):
                requested = tuple(map(int, version.split('.')))
                matches = []
                for installation in (home / '.local/share/fnm/node-versions').glob('v*/installation/bin/node'):
                    installed_version = installation.parents[2].name.removeprefix('v')
                    if re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', installed_version):
                        parts = tuple(map(int, installed_version.split('.')))
                        if parts[:len(requested)] == requested:
                            matches.append((parts, installation))
                if matches:
                    node = max(matches)[1]
                else:
                    fail('.node-version', 'the requested project Node is not installed', 'Run fnm install in the project')
            break
        shared.append(('node', node))
    if 'pnpm' in npm_packages:
        pnpm = home / '.npm-global/bin/pnpm'
        if manages_node and node != home / '.local/share/fnm/aliases/default/bin/node' and (node.parent / 'pnpm').is_file():
            pnpm = node.parent / 'pnpm'
        shared.append(('pnpm', pnpm))
    for binary, wanted in shared:
        selected = shutil.which(binary, path=observed_path)
        if not wanted.is_file() or not selected or Path(selected).resolve() != wanted.resolve():
            fail(binary, 'this shell selects a different provider from the profile', 'Run the package installer, then start a fresh shell')

    env_file = home / '.config/agents/env'
    if env_file.is_file():
        for line in env_file.read_text().splitlines():
            if re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', line):
                key, value = line.split('=', 1)
                if os.environ.get(key) != value:
                    fail(key, 'this shell has a stale agent environment', 'Refresh agents-env.sh and start a fresh shell')
    for path in (env_file, home / '.config/agents/1password-token'):
        if path.exists() and (path.is_symlink() or stat.S_IMODE(path.stat().st_mode) != 0o600):
            fail(path.relative_to(home), 'private environment file must be a regular mode-600 file', 'Correct the file permissions outside the checkout')
    if platform.system() == 'Linux':
        service_binary = home / 'services/opencode/bin/opencode'
        cli = shutil.which('opencode', path=runtime_path)
        if service_binary.is_file() and cli:
            service_status, service_version = command([str(service_binary), '--version'])
            cli_status, cli_version = command([cli, '--version'])
            if service_status or cli_status or service_version != cli_version:
                fail('OpenCode service', 'service binary and CLI releases differ', 'Run bash services/opencode/setup.sh to update and restart the service')
        for unit in ('t3code', 'opencode-web'):
            dropin = home / f'.config/systemd/user/{unit}.service.d/runtime.conf'
            expected = f'[Service]\nEnvironment="PATH={runtime_path}"\nUnsetEnvironment=CODEX_HOME\n'
            if not dropin.is_file() or dropin.read_text() != expected:
                fail(dropin.relative_to(home), 'service runtime configuration is stale', 'Run scripts/link.sh, then reload the user units')
            code, output = command(['systemctl', '--user', 'show', unit + '.service', '-p', 'ActiveState,MainPID'])
            properties = dict(line.split('=', 1) for line in output.splitlines() if '=' in line)
            pid = properties.get('MainPID', '0')
            if code or pid == '0':
                continue
            try:
                values = dict(item.split('=', 1) for item in (Path('/proc') / pid / 'environ').read_bytes().decode().split('\0') if '=' in item)
                if values.get('CODEX_HOME') or values.get('PATH') != runtime_path:
                    fail(unit + '.service', 'running process has a stale runtime environment', 'Reload user units and restart the service when its sessions can stop')
                if env_file.is_file():
                    required = dict(line.split('=', 1) for line in env_file.read_text().splitlines() if re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', line))
                    if any(values.get(key) != value for key, value in required.items()):
                        fail(unit + '.service', 'running agent environment is stale', 'Refresh agents-env.sh and restart the service when its sessions can stop')
            except (OSError, UnicodeError):
                fail(unit + '.service', 'process environment could not be inspected', 'Inspect the service as its owning user')

    code, root = command(['git', '-C', str(repo), 'rev-parse', '--show-toplevel'])
    if code == 0 and Path(root).resolve() == repo:
        _, changed = command(['git', '-C', str(repo), 'status', '--porcelain', '--', 'roles', 'profiles', 'agents'])
        if changed:
            fail('checkout', 'managed source has uncommitted changes', 'Review git status before syncing')
    for finding in findings:
        print('DRIFT ' + finding)
    if not findings:
        print('No drift found')
    return int(bool(findings))


if __name__ == '__main__':
    sys.exit(main())
