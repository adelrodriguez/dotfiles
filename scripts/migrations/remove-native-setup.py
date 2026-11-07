#!/usr/bin/env python3
"""Remove the native installer and fixtures superseded by host Nix configurations."""
from pathlib import Path
import shutil
root = Path(__file__).resolve().parents[2]
for name in ('roles', 'profiles', 'nix', 'scripts/lib/packages'):
    shutil.rmtree(root / name, ignore_errors=True)
for name in (
    'scripts/install.sh', 'scripts/link.sh', 'scripts/package.sh',
    'scripts/lib/profile.sh', 'scripts/lib/home.sh', 'scripts/lib/fish.sh',
    'scripts/lib/process-compose.sh', 'scripts/lib/doctor.py',
    'docs/nix-pilot.md', 'tests/nix.py',
    'scripts/migrations/remove-ghostty.py', 'scripts/migrations/isolate-platform-tests.py',
    *('tests/' + name + '.sh' for name in (
        'roles', 'link', 'sync', 'packages', 'packages-macos', 'upstream-packages',
        'github-release', 'runtime', 'doctor', 'installed-tools',
    )),
):
    (root / name).unlink(missing_ok=True)
