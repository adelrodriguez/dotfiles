#!/usr/bin/env python3
"""Exercise the legacy handoff without a real profile or account."""
import json
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    home = root / 'home'
    checkout = root / 'repo'
    (home / '.config').mkdir(parents=True)
    (checkout / 'old/agents').mkdir(parents=True)
    (checkout / 'old/agents/env').write_text('TEST_SECRET=private-fixture\n')
    (home / '.config/agents').symlink_to(checkout / 'old/agents')
    (home / '.zshrc').write_text('local shell edits\n')
    (home / '.tmux.conf').symlink_to(checkout / 'removed-tmux')
    manifest = root / 'targets.json'
    manifest.write_text(json.dumps(['.zshrc', '.config/agents/env.tpl']))
    def handoff():
        subprocess.run(['python3', str(repo / 'scripts/lib/handoff.py'), str(home), str(checkout), str(manifest)], check=True)
    handoff()
    assert not (home / '.zshrc').exists()
    assert not (home / '.config/agents').is_symlink()
    assert (home / '.config/agents/env').read_text() == 'TEST_SECRET=private-fixture\n'
    assert not (home / '.tmux.conf').is_symlink(), 'Removed checkout links must not remain dangling'
    backups = home / '.local/state/dotfiles/backups'
    assert any(path.read_text() == 'local shell edits\n' for path in backups.rglob('.zshrc'))
    before = sorted(backups.rglob('*'))
    handoff()
    assert before == sorted(backups.rglob('*')), 'Handoff must be idempotent'
    # Mutable Git configuration preserves local credentials and retires the old include.
    gitconfig = home / '.gitconfig'
    gitconfig.write_text(f'[include]\n path = {checkout}/roles/base/home/.gitconfig\n[credential]\n helper = local-credential\n')
    command = ['python3', str(repo / 'scripts/lib/mutable.py'), 'git', str(home), str(checkout), 'git']
    subprocess.run(command, check=True)
    subprocess.run(command, check=True)
    assert not gitconfig.is_symlink()
    assert 'local-credential' in gitconfig.read_text()
    assert 'roles/base' not in gitconfig.read_text()
    assert gitconfig.read_text().count(str(home / '.config/git/managed')) == 1
print('PASS legacy handoff, private files, local credentials, backups, and repeat migration')
