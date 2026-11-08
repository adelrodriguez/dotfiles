#!/usr/bin/env python3
"""Check shell startup and file handoff through their public interfaces."""
from pathlib import Path
import json
import os
import shutil
import shlex
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]
FISH = shutil.which('fish')
FNM = shutil.which('fnm')
ZSH = shutil.which('zsh')

class Home(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.home = self.root / 'home'
        (self.home / '.config/agents').mkdir(parents=True)
        self.env = {**os.environ, 'HOME': str(self.home), 'XDG_CONFIG_HOME': str(self.home / '.config'),
                    'XDG_DATA_HOME': str(self.home / '.local/share'), 'XDG_STATE_HOME': str(self.home / '.local/state'),
                    'XDG_CACHE_HOME': str(self.home / '.cache')}
        self.env.pop('CODEX_HOME', None)

    def executable(self, path, output):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('#!/bin/sh\nprintf "%s\\n" ' + shlex.quote(str(output)) + '\n')
        path.chmod(0o755)
        return path

    def check_zsh_listings(self, eza):
        binaries = self.root / 'bin'
        binaries.mkdir()
        system_ls = shutil.which('ls', path=os.defpath)
        (binaries / 'ls').symlink_to(system_ls)
        for name in ('mv', 'grep'):
            (binaries / name).symlink_to(shutil.which(name, path=os.defpath))
        for name in ('fnm', 'starship', 'zoxide'):
            command = binaries / name
            command.write_text('#!/bin/sh\nexit 0\n')
            command.chmod(0o755)
        if eza:
            command = binaries / 'eza'
            command.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            command.chmod(0o755)
        config = self.home / '.config/zsh'
        config.mkdir()
        (config / 'bindings.zsh').symlink_to(REPO / 'home/shell/zsh/bindings.zsh')
        fixture = self.root / 'fixture'
        fixture.mkdir()
        for name, modified in (('fixture-file', 100), ('newer-file', 200), ('.hidden', 300)):
            path = fixture / name
            path.write_text(name + '\n')
            os.utime(path, (modified, modified))
        (fixture / 'directory').mkdir()
        env = {**self.env, 'PATH': str(binaries), 'ZDOTDIR': str(self.home), 'LC_ALL': 'C',
               'FNM_DIR': str(self.home / '.local/share/fnm'),
               'FNM_MULTISHELL_PATH': str(self.root / 'fnm-shell')}

        commands = {'whence -w ls': 'ls: command\n'}
        for flags in ('-t fixture-file', '-t .', '-la .'):
            expected = subprocess.run([system_ls, *shlex.split(flags)], cwd=fixture, env=env,
                                      capture_output=True, text=True, check=True)
            commands['ls ' + flags] = expected.stdout
        if eza:
            shortcuts = {
                'l': '-lh --group-directories-first --icons=auto',
                'la': '-a --group-directories-first --icons=auto',
                'll': '-lha --group-directories-first --icons=auto',
                'lsa': '-a --group-directories-first --icons=auto',
                'lt': '--tree --level=2 --long --icons --git',
                'lta': '--tree --level=2 --long --icons --git -a',
            }
            for name, flags in shortcuts.items():
                commands[name + ' .'] = '\n'.join([*shlex.split(flags), '.']) + '\n'
        else:
            for name, flags in (('l', '-l'), ('la', '-a'), ('ll', '-la')):
                expected = subprocess.run([system_ls, flags, '.'], cwd=fixture, env=env,
                                          capture_output=True, text=True, check=True)
                commands[name + ' .'] = expected.stdout
        for command, expected in commands.items():
            with self.subTest(command=command):
                result = subprocess.run([ZSH, '-fic', 'source "$1"\neval "$2"', '_',
                                         str(REPO / 'home/shell/zsh/zshrc'), command],
                                        cwd=fixture, env=env, capture_output=True, text=True)
                self.assertEqual((result.returncode, result.stdout, result.stderr), (0, expected, ''))

    def test_zsh_keeps_system_ls_with_eza(self):
        self.check_zsh_listings(eza=True)

    def test_zsh_keeps_system_ls_without_eza(self):
        self.check_zsh_listings(eza=False)

    def zsh(self, commands):
        binaries = self.root / 'bin'
        self.executable(binaries / 'node', 'v26.13.0')
        self.executable(self.root / 'fnm/project/bin/node', 'v24.22.2')
        (self.root / 'fnm/multishell/bin').mkdir(parents=True)
        # fnm changes the available executable without changing the shell's PATH.
        fnm = binaries / 'fnm'
        fnm.write_text('''#!/bin/sh
case "$1" in
    env)
        printf '%s\\n' 'export FNM_MULTISHELL_PATH="$FNM_DIR/multishell"' \
            'export PATH="$FNM_MULTISHELL_PATH/bin:$PATH"'
        ;;
    use)
        if [ -n "${FNM_TEST_STATUS:-}" ]; then exit "$FNM_TEST_STATUS"; fi
        for selection do :; done
        if [ -f "$selection" ]; then selection=$(cat "$selection"); fi
        case "$selection" in
            system) /bin/rm -f "$FNM_MULTISHELL_PATH/bin/node" ;;
            *) /bin/ln -sf "$FNM_DIR/project/bin/node" "$FNM_MULTISHELL_PATH/bin/node" ;;
        esac
        ;;
esac
''')
        fnm.chmod(0o755)
        for name in ('starship', 'zoxide'):
            self.executable(binaries / name, '')
        (self.home / '.zshrc').symlink_to(REPO / 'home/shell/zsh/zshrc')
        (self.home / '.config/zsh').mkdir()
        (self.home / '.config/zsh/bindings.zsh').write_text('')
        env = {**self.env, 'PATH': f'{binaries}:/usr/bin:/bin', 'ZDOTDIR': str(self.home),
               'FNM_DIR': str(self.root / 'fnm'), 'FNM_TEST_STATUS': ''}
        env.pop('FNM_MULTISHELL_PATH', None)
        # Read separate input lines so node runs in the parent shell at each prompt.
        result = subprocess.run([ZSH, '-d', '-i'], input='\n'.join([*commands, 'exit 0', '']),
                                cwd=self.home, env=env, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip().splitlines()

    def test_zsh_refreshes_cached_node_when_entering_and_leaving_a_project(self):
        project = self.root / 'project'
        project.mkdir()
        (project / '.node-version').write_text('24.22.2\n')
        result = self.zsh(['node --version', f'cd {shlex.quote(str(project))}', 'node --version',
                           'cd "$HOME"', 'node --version'])
        self.assertEqual(result, ['v26.13.0', 'v24.22.2', 'v26.13.0'])

    def test_zsh_preserves_fnm_failure_status_in_and_outside_a_project(self):
        project = self.root / 'project'
        project.mkdir()
        (project / '.node-version').write_text('24.22.2\n')
        result = self.zsh([f'cd {shlex.quote(str(project))}', 'export FNM_TEST_STATUS=17',
                           'use_project_node', 'print -r -- "project:$?"', 'cd "$HOME"',
                           'use_project_node', 'print -r -- "system:$?"'])
        self.assertEqual(result, ['project:17', 'system:17'])

    @unittest.skipUnless(FNM and ZSH, 'Node selection requires fnm and zsh')
    def test_fnm_returns_to_system_outside_projects(self):
        base = self.executable(self.root / 'bin/node', 'v26.0.0')
        self.executable(base.parent / 'starship', '')
        self.executable(base.parent / 'zoxide', '')
        bindings = self.home / '.config/zsh/bindings.zsh'
        bindings.parent.mkdir(parents=True)
        bindings.touch()
        fnm = self.root / 'fnm'
        installations = []
        for version in ('20.0.0', '22.0.0'):
            installations.append(self.executable(fnm / f'node-versions/v{version}/installation/bin/node', f'v{version}'))
        aliases = fnm / 'aliases'
        aliases.mkdir()
        (aliases / 'default').symlink_to(installations[0].parent.parent)
        before = [path.read_bytes() for path in installations]
        runtime = self.root / 'runtime'
        runtime.mkdir(mode=0o700)
        for name in list(self.env):
            if name.startswith('FNM_'):
                self.env.pop(name)
        self.env.update({'FNM_DIR': str(fnm), 'ZDOTDIR': str(self.home),
                         'XDG_RUNTIME_DIR': str(runtime), 'TMPDIR': str(runtime),
                         'PATH': os.pathsep.join([str(base.parent), str(Path(FNM).parent), '/usr/bin', '/bin'])})
        projects = []
        for filename in ('.node-version', '.nvmrc'):
            project = self.root / filename.removeprefix('.') / 'nested'
            project.mkdir(parents=True)
            (project.parent / filename).write_text('22\n')
            projects.append((project, 'v22.0.0'))
        conflicting = self.root / 'conflicting'
        conflicting.mkdir()
        (conflicting / '.node-version').write_text('22\n')
        (conflicting / '.nvmrc').write_text('20\n')
        projects.append((conflicting, 'v20.0.0'))
        nearer_engine = self.root / 'ancestor/child'
        nearer_engine.mkdir(parents=True)
        (nearer_engine.parent / '.node-version').write_text('22\n')
        (nearer_engine / 'package.json').write_text(json.dumps({'engines': {'node': '20'}}))
        projects.append((nearer_engine, 'v20.0.0'))
        destinations = [self.home, Path('/')]
        for name in ('empty-system', 'file-system', 'project-system'):
            destination = self.root / name
            destination.mkdir()
            system = destination / 'system'
            if name == 'file-system':
                system.write_text('20\n')
            else:
                system.mkdir()
                if name == 'project-system':
                    (system / '.node-version').write_text('20\n')
            destinations.append(destination)
        for shell in ('fish', 'zsh'):
            if shell == 'fish':
                startup = REPO / 'home/shell/fish/conf.d/70-fnm.fish'
                command = [FISH, '--no-config', '-c']
                probe = 'node --version'
            else:
                startup = REPO / 'home/shell/zsh/zshrc'
                command = [ZSH, '-dfc']
                # Isolate #63 from the separate zsh command-cache defect in #65.
                probe = 'rehash; node --version'
            for project, selected in projects:
                for destination in destinations:
                    with self.subTest(shell=shell, project=str(project.relative_to(self.root)), destination=str(destination)):
                        script = f'source {shlex.quote(str(startup))}; {probe}; '
                        for directory in (project, destination, project, destination):
                            script += f'cd {shlex.quote(str(directory))}; {probe}; '
                        result = subprocess.run([*command, script + 'pwd'], cwd=self.home, env=self.env,
                                                capture_output=True, text=True)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        versions = [line for line in result.stdout.splitlines() if line.startswith('v')]
                        self.assertEqual(versions, ['v26.0.0', selected, 'v26.0.0', selected, 'v26.0.0'],
                                         result.stdout + result.stderr)
                        self.assertEqual(result.stdout.splitlines()[-1], str(destination))
        self.assertEqual([path.read_bytes() for path in installations], before)
        self.assertEqual((aliases / 'default').readlink(), installations[0].parent.parent)

    def test_fish_removes_global_and_universal_codex_home(self):
        runtime = self.home / '.config/agents/runtime.path'
        runtime.write_text('/usr/bin\n/bin\n')
        subprocess.run([FISH, '-c', 'set -Ux CODEX_HOME /old/universal'], env=self.env, check=True)
        inherited = {**self.env, 'CODEX_HOME': '/old/inherited'}
        result = subprocess.run([FISH, '-c', 'source $argv[1]; not set -q CODEX_HOME',
                                 str(REPO / 'home/shell/fish/conf.d/10-paths.fish')], env=inherited, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, 'A universal CODEX_HOME became visible after removing the global value')
        result = subprocess.run([FISH, '-c', 'not set -q CODEX_HOME'], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, 'A new Fish still loads the stored CODEX_HOME')

    def test_handoff_converts_linked_fish_before_fisher_cleanup(self):
        checkout = self.root / 'repo'
        fish = checkout / 'home/.config/fish'
        fish.mkdir(parents=True)
        (self.home / '.config/fish').symlink_to(fish)
        plugin = self.home / '.config/fish/functions/fzf_configure_bindings.fish'
        self.executable(plugin, 'old-plugin')
        unrelated = fish / 'functions/private.fish'
        unrelated.write_text('local function\n')
        subprocess.run([FISH, '-c', 'set -U _fisher_patrickf1_2F_fzf_2E_fish_files $argv[1]', str(plugin)],
                       env=self.env, check=True)
        manifest = self.root / 'targets.json'
        manifest.write_text(json.dumps(['.config/fish/conf.d/10-paths.fish']))
        command = [sys.executable, str(REPO / 'home/handoff.py'), str(self.home), str(checkout), str(manifest), FISH]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.home / '.config/fish').is_symlink())
        self.assertFalse(plugin.exists())
        self.assertEqual((self.home / '.config/fish/functions/private.fish').read_text(), 'local function\n')
        self.assertTrue((fish / 'functions/fzf_configure_bindings.fish').exists(), 'The source checkout must retain its files')
        backups = self.home / '.local/state/dotfiles/backups'
        self.assertTrue(any(path.is_file() for path in backups.rglob('fzf_configure_bindings.fish')))
        before = sorted(backups.rglob('*'))
        subprocess.run(command, capture_output=True, text=True, check=True)
        self.assertEqual(sorted(backups.rglob('*')), before)

    def test_handoff_rejects_foreign_fish_directory(self):
        foreign = self.root / 'foreign'
        foreign.mkdir()
        (foreign / 'private.fish').write_text('keep\n')
        (self.home / '.config/fish').symlink_to(foreign)
        manifest = self.root / 'targets.json'
        manifest.write_text(json.dumps(['.config/fish/conf.d/10-paths.fish']))
        result = subprocess.run([sys.executable, str(REPO / 'home/handoff.py'), str(self.home),
                                 str(self.root / 'repo'), str(manifest), FISH], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('foreign directory', result.stderr)
        self.assertEqual((foreign / 'private.fish').read_text(), 'keep\n')


if __name__ == '__main__':
    unittest.main()
