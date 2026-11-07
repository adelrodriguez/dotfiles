#!/usr/bin/env python3
"""Repeat the platform guard migration, using packages.sh as the hand-checked example."""
from pathlib import Path

repo = Path(__file__).resolve().parents[2]
for name in ('upstream-packages', 'github-release'):
    path = repo / 'tests' / (name + '.sh')
    text = path.read_text()
    if 'Ubuntu release checks run on Linux.' in text:
        continue
    anchor = 'set -euo pipefail\n'
    guard = '''if [[ "$(uname -s)" != Linux ]]; then
  echo 'Ubuntu release checks run on Linux. macOS ownership is checked by packages-macos.sh.'
  exit 0
fi
'''
    assert text.count(anchor) >= 1, path
    path.write_text(text.replace(anchor, anchor + guard, 1))
