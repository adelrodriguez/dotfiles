#!/usr/bin/env python3
"""Reject store links for files that their tools write."""
import json
import os
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[2]
# npm login writes ~/.npmrc. A read-only store link made it fail with EACCES.
expression = f'''
  ((builtins.getFlake {json.dumps(str(repo))}).homeConfigurations.homelab.extendModules {{
    modules = [ {{ home.file.".npmrc".text = ""; }} ];
  }}).activationPackage.drvPath
'''
env = {**os.environ, 'NIX_CONFIG': os.environ.get('NIX_CONFIG', '') + '\nexperimental-features = nix-command flakes\n'}
result = subprocess.run(['nix', 'eval', '--impure', '--raw', '--expr', expression],
                        env=env, text=True, capture_output=True)
assert result.returncode != 0, 'Linking ~/.npmrc from the Nix store must fail the build'
assert '~/.npmrc must stay writable' in result.stderr, result.stderr
print('PASS tool-written home files cannot be linked from the Nix store')
