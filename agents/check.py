#!/usr/bin/env python3
"""Inspect this domain without changing installed state."""
from pathlib import Path
import stat
import sys

home = Path.home()
failures = []

def require(condition, message):
    if not condition:
        failures.append(message)

for name in ('env', '1password-token'):
    path = home / '.config/agents' / name
    if path.exists():
        require(not path.is_symlink() and stat.S_IMODE(path.stat().st_mode) == 0o600,
                f'{path} must be a private regular file with mode 0600.')
if failures:
    print('\n'.join('FAIL ' + message for message in failures), file=sys.stderr)
    raise SystemExit(1)
print('PASS private agent file permissions')
