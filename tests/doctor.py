#!/usr/bin/env python3
"""Verify the public doctor composes domain checks without changing the caller."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

DOCTOR = Path(__file__).resolve().parents[1] / 'scripts/doctor.sh'


class Doctor(unittest.TestCase):
    def test_reports_all_domains_and_leaves_files_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            (home / '.config/dotfiles').mkdir(parents=True)
            (home / '.config/agents').mkdir()
            (home / '.config/dotfiles/expected.json').write_text(json.dumps({
                'host': 'homelab', 'tools': {}, 'npmPackages': {}, 'vendorTools': [],
                'runtimePaths': ['/usr/bin', '/bin'],
            }))
            env = {**os.environ, 'HOME': str(home)}
            env.pop('CODEX_HOME', None)

            def run(*flags):
                return subprocess.run(['bash', str(DOCTOR), *flags], env=env, capture_output=True, text=True)

            self.assertEqual(run('--home-only').returncode, 0)
            self.assertEqual(run('--no-services').returncode, 0)
            self.assertEqual(run('--invalid').returncode, 2)
            original = home / 'local-git'
            original.write_text('private credentials stay here\n')
            (home / '.gitconfig').symlink_to(original)
            secret = home / '.config/agents/env'
            secret.write_text('FIXTURE=value\n')
            secret.chmod(0o644)
            env['CODEX_HOME'] = '/old/custom-home'
            result = run('--no-services')
            self.assertEqual(result.returncode, 1)
            for message in ('CODEX_HOME is still set', '~/.gitconfig must stay writable', 'mode 0600'):
                self.assertIn(message, result.stderr)
            self.assertEqual(original.read_text(), 'private credentials stay here\n')
            self.assertTrue((home / '.gitconfig').is_symlink())
            self.assertEqual(secret.stat().st_mode & 0o777, 0o644)

    def test_checks_the_declared_services(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            (home / '.config/dotfiles').mkdir(parents=True)
            (home / '.config/dotfiles/expected.json').write_text(json.dumps({
                'host': 'homelab', 'tools': {}, 'npmPackages': {}, 'vendorTools': [], 'runtimePaths': [],
            }))
            (home / '.config/dotfiles/services.json').write_text('["example-agent"]')
            (home / 'bin').mkdir()
            systemctl = home / 'bin/systemctl'
            systemctl.write_text('#!/bin/sh\ncase "$*" in\n*is-active*) exit 1;;\n*MainPID*) echo 0;;\nesac\nexit 0\n')
            systemctl.chmod(0o755)
            env = {**os.environ, 'HOME': str(home), 'PATH': str(home / 'bin') + ':' + os.environ['PATH']}
            env.pop('CODEX_HOME', None)
            result = subprocess.run(['bash', str(DOCTOR)], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn('example-agent failed is-active', result.stderr)
            self.assertNotIn('opencode-web', result.stderr)


if __name__ == '__main__':
    unittest.main()
