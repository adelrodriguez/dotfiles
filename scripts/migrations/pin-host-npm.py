#!/usr/bin/env python3
"""Convert either host's unversioned npm list to explicit direct versions."""
from pathlib import Path
import json
import re
import subprocess
root = Path(__file__).resolve().parents[2]
for host in ('mac', 'homelab'):
    path = root / 'hosts' / host / 'home.nix'
    text = path.read_text()
    match = re.search(r'    npmPackages = \[([^\]]+)\];', text)
    if not match:
        continue
    names = re.findall(r'"([^\"]+)"', match[1])
    versions = {}
    for name in names:
        versions[name] = json.loads(subprocess.check_output(['npm', 'view', name, 'version', '--json'], text=True))
    declaration = '    npmPackages = {\n' + ''.join(f'      {json.dumps(name)} = {json.dumps(version)};\n' for name, version in versions.items()) + '    };'
    path.write_text(text[:match.start()] + declaration + text[match.end():])
