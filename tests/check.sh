#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$repo" <<'PYTHON'
from pathlib import Path
import re, sys
for path in (Path(sys.argv[1]) / 'modules/home').glob('*.nix'):
    assert not re.search(r'(hosts|roles|profiles)/', path.read_text()), f'{path} imports a host or retired layout'
PYTHON
python3 "$repo/tests/migration.py"
python3 "$repo/tests/runtime.py"
for test in agents-env agents fish-limits grok-completions; do
  bash "$repo/tests/$test.sh"
done
