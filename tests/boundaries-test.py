#!/usr/bin/env python3
"""Prove boundary enforcement with real repository fixtures."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

CHECK = Path(__file__).with_name('boundaries.py')


class Boundaries(unittest.TestCase):
    def test_dependency_direction_exports_and_cycles(self):
        cases = [
            ({'flake.nix': '{ modules = [ ./hosts${host}/home.nix ]; }', 'hosts/mac/home.nix': '{}'}, 'missing dependency'),
            ({'flake.nix': '{ modules = [ ./hosts/${host}/home.nix ]; }', 'hosts/mac/home.nix': '{}'}, None),
            ({'home/shell/default.nix': '{ source = ./fish; }', 'home/shell/fish/config.fish': ''}, None),
            ({'hosts/mac/home.nix': '{ imports = [ ../../tools ]; }', 'tools/default.nix': '{}'}, None),
            ({'tools/default.nix': '{ imports = [ ../agents ]; }', 'agents/default.nix': '{}'}, 'forbidden dependency'),
            ({'hosts/mac/home.nix': '{ imports = [ ../../home/private.nix ]; }', 'home/private.nix': '{}'}, 'private file'),
            ({'hosts/mac/home.nix': '{ imports = [ ../../home/private ]; }', 'home/private/default.nix': '{}'}, 'private file'),
            ({'agents/a.py': 'from b import value', 'agents/b.py': 'from a import value'}, 'Source cycle'),
            ({'agents/env.sh': 'source "$(dirname "${BASH_SOURCE[0]}")/../tools/private.sh"', 'tools/private.sh': ''}, 'private file'),
            ({'tools/install.sh': 'source "$DOTFILES_DIR/agents/env.sh"', 'agents/env.sh': ''}, 'forbidden dependency'),
            ({'tools/a.py': 'from agents.private import value', 'agents/private.py': ''}, 'forbidden dependency'),
            ({'tools/a.py': 'import agents.private', 'agents/private.py': ''}, 'forbidden dependency'),
            ({'services/sync/dotfiles-sync': 'exec "$checkout/scripts/sync.sh"', 'scripts/sync.sh': ''}, None),
        ]
        for files, error in cases:
            with self.subTest(files=files), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                for name, contents in files.items():
                    path = root / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(contents)
                result = subprocess.run([sys.executable, str(CHECK), '--root', str(root)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0 if error is None else 1, result.stderr)
                if error:
                    self.assertIn(error, result.stderr)


if __name__ == '__main__':
    unittest.main()
