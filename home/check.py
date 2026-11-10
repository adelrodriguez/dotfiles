#!/usr/bin/env python3
"""Inspect this domain without changing installed state."""
from pathlib import Path
import sys

home = Path.home()
failures = []

def require(condition, message):
    if not condition:
        failures.append(message)

require(not (home / '.gitconfig').is_symlink(), '~/.gitconfig must stay writable.')
require(not (home / '.npmrc').is_symlink(), '~/.npmrc must stay writable.')
require(not (home / '.config/fish/completions/grok.fish').is_symlink(), 'Grok completion must stay writable.')
if failures:
    print('\n'.join('FAIL ' + message for message in failures), file=sys.stderr)
    raise SystemExit(1)
print('PASS writable home configuration')
