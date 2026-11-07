#!/usr/bin/env python3
"""Exercise bootstrap and apply with external installers and OS commands stubbed."""
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]


class Provisioning(unittest.TestCase):
    def test_bootstrap_runs_apply_agents_and_doctor(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            repo = root / 'repo'
            for domain in ('scripts', 'hosts', 'tools', 'home', 'agents', 'services'):
                shutil.copytree(REPO / domain, repo / domain, ignore=shutil.ignore_patterns('__pycache__'))
            home = root / 'home'
            (home / '.config/dotfiles').mkdir(parents=True)
            (home / '.config/agents').mkdir()
            binary = root / 'bin'
            binary.mkdir()
            (binary / 'python3').symlink_to(sys.executable)
            host = 'mac' if platform.system() == 'Darwin' else 'homelab'
            runtime = [str(binary), '/usr/bin', '/bin']
            (home / '.config/dotfiles/host').write_text(host)
            (home / '.config/dotfiles/expected.json').write_text(json.dumps({
                'host': host, 'tools': {}, 'npmPackages': {}, 'vendorTools': [], 'runtimePaths': runtime,
                'brew': {'brews': [], 'casks': []},
            }))
            (home / '.config/dotfiles/services.json').write_text('[]')
            (home / '.config/agents/runtime.path').write_text('\n'.join(runtime) + '\n')
            (home / '.opencode/bin').mkdir(parents=True)
            opencode = home / '.opencode/bin/opencode'
            opencode.write_text('#!/bin/sh\nexit 0\n')
            opencode.chmod(0o755)
            result = root / 'generation'
            result.mkdir()
            activate = result / 'activate'
            activate.write_text('#!/bin/sh\nexit 0\n')
            activate.chmod(0o755)
            commands = {
                'nix': '''case "$1" in
eval) case "$*" in
  *--json*) echo '[]';;
  *dotfiles.checkout*) echo "$FIXTURE_REPO";;
  *home.homeDirectory*) echo "$HOME";;
  *home.username*) id -un;;
esac;;
build) echo "$FIXTURE_GENERATION";;
esac
''',
                'sudo': 'printf "sudo %s\\n" "$*" >> "$CALLS"\n',
                'apm': 'printf "apm %s\\n" "$*" >> "$CALLS"\n',
                'systemctl': 'case "$*" in *MainPID*) echo 0;; esac\n',
                't3': 'printf "t3 %s\\n" "$*" >> "$CALLS"\n',
            }
            for name, content in commands.items():
                path = binary / name
                path.write_text('#!/bin/sh\n' + content)
                path.chmod(0o755)
            env = {**os.environ, 'HOME': str(home), 'PATH': ':'.join(runtime),
                   'FIXTURE_REPO': str(repo), 'FIXTURE_GENERATION': str(result),
                   'CALLS': str(root / 'calls'), 'T3_BIN': str(binary / 't3')}
            for key in ('T3CODE_HOME', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME'):
                env.pop(key, None)
            process = subprocess.run(['bash', str(repo / 'scripts/bootstrap.sh'), host], env=env,
                                     capture_output=True, text=True, timeout=60)
            # The isolated Mac PATH deliberately lacks Homebrew pnpm. Doctor
            # must report that after completing apply and agent deployment.
            self.assertEqual(process.returncode, 1 if host == 'mac' else 0, process.stdout + process.stderr)
            if host == 'mac':
                self.assertIn('Mac pnpm must come from Homebrew, found None', process.stderr)
            self.assertIn('Skipping agent environment', process.stdout)
            self.assertIn('PASS private agent file permissions', process.stdout)
            self.assertIn('apm compile --global', (root / 'calls').read_text())
            self.assertEqual((home / '.apm/apm.lock.yaml').read_bytes(), (REPO / 'agents/apm.lock.yaml').read_bytes())


if __name__ == '__main__':
    unittest.main()
