#!/usr/bin/env python3
"""Check observed providers, Fish scope cleanup, and legacy directory handoff."""
from contextlib import redirect_stderr, redirect_stdout
import io
import json
import os
import runpy
from pathlib import Path
import shutil
import shlex
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
FISH = shutil.which('fish')


class Runtime(unittest.TestCase):
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

    def doctor_fixture(self):
        default = self.executable(self.home / '.nix-profile/bin/node', 'v26.0.0')
        (self.home / '.config/dotfiles').mkdir()
        (self.home / '.gitconfig').touch()
        completion = self.home / '.config/fish/completions/grok.fish'
        completion.parent.mkdir(parents=True)
        completion.touch()
        self.expected = {'host': 'homelab', 'tools': {'node': str(default)}, 'npmPackages': {}, 'vendorTools': [],
                         'runtimePaths': [str(default.parent), '/usr/bin', '/bin'], 'brew': {}}
        self.env['PATH'] = ':'.join(self.expected['runtimePaths'])

    def doctor(self, cwd=None):
        (self.home / '.config/dotfiles/expected.json').write_text(json.dumps(self.expected))
        return subprocess.run([sys.executable, str(REPO / 'checks/installed.py'), '--no-services'],
                              env=self.env, cwd=cwd or self.root, capture_output=True, text=True)

    def test_doctor_rejects_shadowed_providers(self):
        self.doctor_fixture()
        package = self.home / '.npm-global/lib/node_modules/fixture-cli'
        package.mkdir(parents=True)
        (package / 'package.json').write_text(json.dumps({'version': '1.0.0', 'bin': {'fixture-cli': 'bin/cli'}}))
        installed = self.executable(package / 'bin/cli', 'fixture-cli-1.0.0')
        launcher = self.home / '.npm-global/bin/fixture-cli'
        launcher.parent.mkdir(parents=True)
        launcher.symlink_to(installed)
        self.executable(self.home / '.local/bin/claude', 'claude-current')
        self.expected['npmPackages'] = {'fixture-cli': '1.0.0'}
        self.expected['vendorTools'] = ['claude']
        self.expected['runtimePaths'][1:1] = [str(launcher.parent), str(self.home / '.local/bin')]
        declared = ':'.join(self.expected['runtimePaths'])
        self.env['PATH'] = declared
        result = self.doctor()
        self.assertEqual(result.returncode, 0, result.stderr)
        for name in ('node', 'fixture-cli', 'claude'):
            with self.subTest(provider=name):
                shadow = self.executable(self.root / name / name, 'stale')
                self.env['PATH'] = str(shadow.parent) + ':' + declared
                result = self.doctor()
                self.assertNotEqual(result.returncode, 0, f'The doctor accepted shadowed {name}: {result.stdout}')
                self.assertIn(str(shadow), result.stderr)

    def test_doctor_rejects_a_path_missing_the_declared_tools(self):
        self.doctor_fixture()
        for path in ('/usr/bin:/bin', None):
            with self.subTest(path=path):
                if path is None:
                    self.env.pop('PATH')
                else:
                    self.env['PATH'] = path
                result = self.doctor()
                self.assertNotEqual(result.returncode, 0, 'The doctor replaced a caller PATH that lacks the declared Node')
                self.assertIn('FAIL node:', result.stderr)
                self.assertNotIn('Traceback', result.stderr)

    def test_doctor_checks_qualified_casks_against_installed_metadata(self):
        self.doctor_fixture()
        self.expected['host'] = 'mac'
        self.expected['brew'] = {'brews': [], 'casks': ['axiomhq/tap/axiom']}
        (self.home / '.config/dotfiles/expected.json').write_text(json.dumps(self.expected))
        original_run, original_which = subprocess.run, shutil.which
        for casks, recorded_tap, accepted in [
            ([{'token': 'axiom', 'full_token': 'axiomhq/tap/axiom', 'installed': '0.22.0'}], 'axiomhq/tap', True),
            ([{'token': 'axiom', 'full_token': 'other/tap/axiom', 'installed': '0.22.0'}], 'other/tap', False),
            ([{'token': 'axiom', 'full_token': 'axiomhq/tap/axiom', 'installed': None}], 'axiomhq/tap', False),
            ([{'token': 'axiom', 'full_token': 'axiom', 'tap': None, 'installed': '0.22.0'}], 'axiomhq/tap', True),
            ([{'token': 'axiom', 'full_token': 'axiomhq/tap/axiom', 'installed': '0.22.0'}], 'other/tap', False),
            ([{'token': 'axiom', 'full_token': 'axiomhq/tap/axiom', 'installed': '0.22.0'}], None, False),
            ([], 'axiomhq/tap', False),
        ]:
            with self.subTest(casks=casks, recorded_tap=recorded_tap):
                caskroom = self.root / 'Caskroom'
                receipt = caskroom / 'axiom/.metadata/INSTALL_RECEIPT.json'
                receipt.parent.mkdir(parents=True, exist_ok=True)
                if recorded_tap is None:
                    receipt.unlink(missing_ok=True)
                else:
                    receipt.write_text(json.dumps({'source': {'tap': recorded_tap}}))
                def brew(command, **kwargs):
                    if command == ['/opt/homebrew/bin/brew', '--caskroom']:
                        return subprocess.CompletedProcess(command, 0, stdout=str(caskroom)+'\n', stderr='')
                    if command == ['/opt/homebrew/bin/brew', 'info', '--cask', '--json=v2', '--installed']:
                        return subprocess.CompletedProcess(command, 0, stdout=json.dumps({'casks': casks}), stderr='')
                    if command[:3] == ['/opt/homebrew/bin/brew', 'list', '--cask']:
                        # brew list filters installed casks by token, not full_token.
                        return subprocess.CompletedProcess(command, 0, stdout='', stderr='')
                    if command == ['/opt/homebrew/bin/pnpm', '--version']:
                        return subprocess.CompletedProcess(command, 0, stdout='11.0.0\n', stderr='')
                    return original_run(command, **kwargs)

                def which(name, mode=os.F_OK | os.X_OK, path=None):
                    return '/opt/homebrew/bin/pnpm' if name == 'pnpm' else original_which(name, mode=mode, path=path)

                output, errors = io.StringIO(), io.StringIO()
                code = 0
                with patch.dict(os.environ, self.env, clear=True), \
                     patch.object(sys, 'argv', ['installed.py', '--no-services']), \
                     patch('subprocess.run', side_effect=brew), patch('shutil.which', side_effect=which), \
                     redirect_stdout(output), redirect_stderr(errors):
                    try:
                        runpy.run_path(str(REPO / 'checks/installed.py'), run_name='__main__')
                    except SystemExit as error:
                        code = error.code
                self.assertEqual(code == 0, accepted, errors.getvalue())
                if not accepted:
                    self.assertIn('Homebrew axiomhq/tap/axiom', errors.getvalue())

    def test_fish_removes_global_and_universal_codex_home(self):
        runtime = self.home / '.config/agents/runtime.path'
        runtime.write_text('/usr/bin\n/bin\n')
        subprocess.run([FISH, '-c', 'set -Ux CODEX_HOME /old/universal'], env=self.env, check=True)
        inherited = {**self.env, 'CODEX_HOME': '/old/inherited'}
        result = subprocess.run([FISH, '-c', 'source $argv[1]; not set -q CODEX_HOME',
                                 str(REPO / 'config/fish/conf.d/10-paths.fish')], env=inherited, capture_output=True, text=True)
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
        command = [sys.executable, str(REPO / 'scripts/lib/handoff.py'), str(self.home), str(checkout), str(manifest), FISH]
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
        result = subprocess.run([sys.executable, str(REPO / 'scripts/lib/handoff.py'), str(self.home),
                                 str(self.root / 'repo'), str(manifest), FISH], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('foreign directory', result.stderr)
        self.assertEqual((foreign / 'private.fish').read_text(), 'keep\n')


if __name__ == '__main__':
    unittest.main()
