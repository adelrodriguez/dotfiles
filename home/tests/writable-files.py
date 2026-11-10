#!/usr/bin/env python3
"""Reject store links for files that their tools write."""
import json
import os
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[2]
env = {**os.environ, 'NIX_CONFIG': os.environ.get('NIX_CONFIG', '') + '\nexperimental-features = nix-command flakes\n'}


def evaluate(module):
    expression = f'''
      ((builtins.getFlake {json.dumps(str(repo))}).homeConfigurations.homelab.extendModules {{
        modules = [ {module} ];
      }}).activationPackage.drvPath
    '''
    return subprocess.run(['nix', 'eval', '--impure', '--raw', '--expr', expression],
                          env=env, text=True, capture_output=True)


# npm login writes ~/.npmrc. A read-only store link made it fail with EACCES.
# Linking a parent directory puts its files in the store too.
for module, path in (('{ home.file.".npmrc".text = ""; }', '.npmrc'),
                     ('{ home.file.".docker".text = ""; }', '.docker/config.json')):
    result = evaluate(module)
    assert result.returncode != 0, f'Linking ~/{path} from the Nix store must fail the build'
    assert f'~/{path} must stay writable' in result.stderr, result.stderr
print('PASS tool-written home files cannot be linked from the Nix store')
