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
