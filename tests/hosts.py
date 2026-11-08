#!/usr/bin/env python3
"""Activate the full host configuration in a disposable home and profile state."""
import argparse
import getpass
import json
import os
from pathlib import Path
import platform
import shlex
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--runtime', action='store_true', help='Also install and verify all host runtime packages.')
parser.add_argument('--keep', action='store_true', help='Keep the disposable home for inspection on a test host.')
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
host = 'mac' if platform.system() == 'Darwin' else 'homelab'
system = 'aarch64-darwin' if host == 'mac' else 'x86_64-linux'
original_home = Path.home()


def snapshot(path):
    if path.is_symlink():
        return ('link', str(path.readlink()))
    if path.is_file():
        return ('file', path.read_bytes())
    if path.is_dir():
        return ('directory', tuple((p.relative_to(path).as_posix(), snapshot(p)) for p in sorted(path.iterdir())))
    return ('absent',)


with tempfile.TemporaryDirectory(prefix='.dotfiles-host-', dir=original_home, delete=not args.keep) as directory:
    root = Path(directory).resolve()
    home = root / 'home'
    home.mkdir()
    # An inherited custom NIX_STATE_HOME must never become the test profile.
    inherited_state = root / 'protected-custom-nix-state'
    inherited_state.mkdir()
    (inherited_state / 'sentinel').write_text('keep this account state\n')
    protected = [inherited_state, original_home / '.nix-profile', original_home / '.local/state/nix/profiles',
                 Path(os.environ.get('NIX_STATE_DIR', '/nix/var/nix')) / 'profiles/per-user' / getpass.getuser()]
    if os.environ.get('XDG_STATE_HOME'):
        protected.append(Path(os.environ['XDG_STATE_HOME']) / 'nix/profiles')
    if os.environ.get('NIX_STATE_HOME'):
        protected.append(Path(os.environ['NIX_STATE_HOME']))
    before = [snapshot(path) for path in protected]
    env = os.environ.copy()
    env['NIX_STATE_HOME'] = str(inherited_state)
    for name in ('NIX_PROFILE', 'NIX_PROFILES', 'NIX_USER_PROFILE_DIR', 'NIX_PATH', 'NIX_BUILD_TOP', 'IN_NIX_SHELL',
                 '__NIX_DARWIN_SET_ENVIRONMENT_DONE', '__HM_SESS_VARS_SOURCED', 'DBUS_SESSION_BUS_ADDRESS',
                 'FNM_DIR', 'FNM_MULTISHELL_PATH', 'NPM_CONFIG_PREFIX', 'CODEX_HOME'):
        env.pop(name, None)
    env.update({
        'HOME': str(home),
        'XDG_CONFIG_HOME': str(home / '.config'),
        'XDG_DATA_HOME': str(home / '.local/share'),
        'XDG_STATE_HOME': str(home / '.local/state'),
        'XDG_CACHE_HOME': str(home / '.cache'),
        'XDG_RUNTIME_DIR': str(root / 'runtime'),
        'NIX_STATE_HOME': str(home / '.local/state/nix'),
        'FNM_DIR': str(home / '.local/share/fnm'),
        'NIX_STATE_DIR': str(root / 'nix-state'),
        'NIX_REMOTE': 'unix:///nix/var/nix/daemon-socket/socket',
        'NIX_CONFIG': env.get('NIX_CONFIG', '') + '\nexperimental-features = nix-command flakes\n',
    })
    Path(env['XDG_RUNTIME_DIR']).mkdir(mode=0o700)
    for name in ('XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME', 'NIX_STATE_HOME', 'NIX_STATE_DIR'):
        Path(env[name]).mkdir(parents=True, exist_ok=True)
    machine = {'username': getpass.getuser(), 'homeDirectory': str(home), 'checkout': str(repo), 'system': system}
    expression = f'(builtins.getFlake {json.dumps(str(repo))}).lib.mkHome {json.dumps(host)} (builtins.fromJSON {json.dumps(json.dumps(machine))})'
    def run(command, **kwargs):
        return subprocess.run(command, env=env, cwd=kwargs.pop('cwd', repo), text=True, check=True, **kwargs)
    result = run(['nix', 'build', '--impure', '--no-link', '--print-out-paths', '--expr', '(' + expression + ').activationPackage'], stdout=subprocess.PIPE)
    generation = Path(result.stdout.strip().splitlines()[-1])
    # The build must leave target files alone. Then activation must reject a collision.
    (home / '.zshrc').write_text('private local shell edits\n')
    collision = subprocess.run([str(generation / 'activate')], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    assert collision.returncode != 0 and (home / '.zshrc').read_text() == 'private local shell edits\n', collision.stdout
    manifest = root / 'targets.json'
    result = run(['nix', 'eval', '--impure', '--json', '--expr', f'builtins.attrNames ({expression}).config.home.file'], stdout=subprocess.PIPE)
    manifest.write_text(result.stdout)
    run(['python3', str(repo / 'home/handoff.py'), str(home), str(repo), str(manifest)])
    run([str(generation / 'activate')])
    run([str(generation / 'activate')])
    expected = json.loads((home / '.config/dotfiles/expected.json').read_text())
    services = json.loads((home / '.config/dotfiles/services.json').read_text())
    units = {path.stem for path in (home / '.config/systemd/user').glob('*.service')}
    assert set(services) == (units | {'t3code'} if host == 'homelab' else set()), services
    env['PATH'] = ':'.join(expected['runtimePaths'])
    # The host provides real fnm, including when the lightweight checks skip it.
    run(['python3', str(repo / 'home/tests/runtime.py'), 'Home.test_fnm_returns_to_system_outside_projects'])
    # Catch conflicts with preexisting Homebrew tools before a large Brew install.
    run(['python3', str(repo / 'tools/check.py'), '--home-only'])
    if args.runtime:
        if host == 'mac':
            result = run(['nix', 'eval', '--impure', '--raw', '--expr', f'((builtins.getFlake {json.dumps(str(repo))}).lib.mkMac (builtins.fromJSON {json.dumps(json.dumps(machine))})).config.homebrew.brewfile'], stdout=subprocess.PIPE)
            brewfile = root / 'Brewfile'
            brewfile.write_text(result.stdout)
            run(['/opt/homebrew/bin/brew', 'bundle', '--file', str(brewfile), '--no-upgrade'])
    base_node_version = run([expected['tools']['node'], '--version'], stdout=subprocess.PIPE).stdout.strip()
    # Fresh shells must select this host's packages even after inheriting a stale Codex home.
    env['CODEX_HOME'] = str(root / 'old-codex-home')
    for shell, flags in [('fish', ['-lc']), ('zsh', ['-lc'])]:
        command = 'node --version; test -z "$CODEX_HOME"' if shell == 'zsh' else 'node --version; not set -q CODEX_HOME'
        result = run([shell, *flags, command], stdout=subprocess.PIPE)
        assert result.stdout.strip().splitlines()[-1] == base_node_version, result.stdout
    env.pop('CODEX_HOME')
    if host == 'homelab' or args.runtime:
        # Project versions must override Nix and return to Nix outside a project.
        run(['fnm', 'install', '22'])
        project = root / 'project'
        project.mkdir()
        (project / '.node-version').write_text('22\n')
        for shell in ('fish', 'zsh'):
            result = run([shell, '-lc', 'node --version'], cwd=project, stdout=subprocess.PIPE)
            assert result.stdout.strip().splitlines()[-1].startswith('v22.'), result.stdout
        (project / '.node-version').rename(project / '.nvmrc')
        for shell in ('fish', 'zsh'):
            result = run([shell, '-lc', 'node --version'], cwd=project, stdout=subprocess.PIPE)
            assert result.stdout.strip().splitlines()[-1].startswith('v22.'), result.stdout
        run(['fnm', 'install', '20'])
        conflicting = root / 'conflicting'
        conflicting.mkdir()
        (conflicting / '.nvmrc').write_text('20\n')
        (conflicting / '.node-version').write_text('22\n')
        ancestor = root / 'ancestor'
        nearer_engine = ancestor / 'child'
        nearer_engine.mkdir(parents=True)
        (ancestor / '.node-version').write_text('22\n')
        (nearer_engine / 'package.json').write_text(json.dumps({'engines': {'node': '20'}}))
        for directory in (conflicting, nearer_engine):
            for shell in ('fish', 'zsh'):
                result = run([shell, '-lc', 'node --version'], cwd=directory, stdout=subprocess.PIPE)
                assert result.stdout.strip().splitlines()[-1].startswith('v20.'), result.stdout
        result = run(['fish', '-lc', f'cd {project}; node --version; cd {home}; node --version'], stdout=subprocess.PIPE)
        assert 'v22.' in result.stdout and result.stdout.strip().endswith(base_node_version), result.stdout
        # Populate zsh's command cache before fnm changes the executable at a prompt.
        for version_file in ('.node-version', '.nvmrc'):
            (project / '.nvmrc').rename(project / version_file)
            for directory in (project, nearer_engine):
                commands = ['node --version', f'cd {shlex.quote(str(directory))}', 'node --version',
                            f'cd {shlex.quote(str(home))}', 'node --version', 'exit 0', '']
                result = run(['zsh', '-i'], input='\n'.join(commands), cwd=home,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
                versions = [line for line in result.stdout.splitlines() if line.startswith('v')]
                assert len(versions) == 3, result.stdout + result.stderr
                assert versions[0] == versions[2] == base_node_version, result.stdout
                assert versions[1].startswith('v22.' if directory == project else 'v20.'), result.stdout
            (project / version_file).rename(project / '.nvmrc')

    if args.runtime:
        run(['bash', str(repo / 'tools/install.sh')])
    doctor = str(repo / 'scripts/doctor.sh')
    for shell in ('fish', 'zsh'):
        run([shell, '-lc', shlex.join(['bash', doctor, '--no-services' if args.runtime else '--home-only'])])
    if host == 'homelab' or args.runtime:
        for directory in (project, conflicting, nearer_engine):
            for shell in ('fish', 'zsh'):
                run([shell, '-lc', shlex.join(['bash', doctor, '--home-only'])], cwd=directory)
    # Switching to another generation and back must restore the managed files.
    changed = '(' + expression + ').extendModules { modules = [ { home.file.".config/dotfiles/rollback-probe".text = "new generation"; } ]; }'
    result = run(['nix', 'build', '--impure', '--no-link', '--print-out-paths', '--expr', '(' + changed + ').activationPackage'], stdout=subprocess.PIPE)
    run([str(Path(result.stdout.strip().splitlines()[-1]) / 'activate')])
    assert (home / '.config/dotfiles/rollback-probe').read_text() == 'new generation'
    run([str(generation / 'activate')])
    assert not (home / '.config/dotfiles/rollback-probe').exists()
    # Generated files may contain references, never injected secret values.
    (home / '.config/agents/env').write_text('TEST_SECRET=private-fixture-value\n')
    (home / '.config/agents/env').chmod(0o600)
    assert not (home / '.config/agents').is_symlink()
    assert not (generation / 'home-files/.config/agents/env').exists()
    if host == 'homelab':
        unit = home / '.config/systemd/user/opencode-web.service'
        assert '127.0.0.1' in unit.read_text()
        if args.runtime:
            run(['bash', str(repo / 'services/opencode/setup.sh'), '--prepare'])
            run(['systemd-analyze', '--user', 'verify', str(unit), str(home / '.config/systemd/user/process-compose.service')])
        assert (home / '.config/systemd/user/t3code.service.d/runtime.conf').is_file()
        assert not (home / '.config/systemd/user/t3code.service').exists(), 'T3 must own its main unit'
    else:
        run(['nix', 'build', '--impure', '--no-link', '--expr', f'((builtins.getFlake {json.dumps(str(repo))}).lib.mkMac (builtins.fromJSON {json.dumps(json.dumps(machine))})).system'])
    assert [snapshot(path) for path in protected] == before, 'Test modified an account profile or inherited custom Nix state'
    if args.keep:
        print(f'Kept disposable home: {home}')
print(f'PASS {host}: full activation, repeat activation, collisions, fresh shells, installed contracts, and Nix state isolation')
