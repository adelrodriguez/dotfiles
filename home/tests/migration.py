#!/usr/bin/env python3
"""Exercise the legacy handoff without a real profile or account."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[2]
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
    old_plugin = home / '.config/fish/functions/fzf_configure_bindings.fish'
    old_plugin.parent.mkdir(parents=True)
    old_plugin.write_text('old fisher function\n')
    fish_env = {**os.environ, 'HOME': str(home), 'XDG_CONFIG_HOME': str(home / '.config')}
    subprocess.run(['fish', '-c', 'set -U _fisher_patrickf1_2F_fzf_2E_fish_files $argv[1]', str(old_plugin)], env=fish_env, check=True)
    manifest = root / 'targets.json'
    manifest.write_text(json.dumps(['.zshrc', '.config/agents/env.tpl']))
    def handoff():
        subprocess.run(['python3', str(repo / 'home/handoff.py'), str(home), str(checkout), str(manifest)], check=True)
    handoff()
    assert not (home / '.zshrc').exists()
    assert not old_plugin.exists(), 'Old Fisher functions must not shadow Nix plugins'
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
    command = ['python3', str(repo / 'home/mutable.py'), 'git', str(home), str(checkout), 'git']
    subprocess.run(command, check=True)
    subprocess.run(command, check=True)
    assert not gitconfig.is_symlink()
    assert 'local-credential' in gitconfig.read_text()
    assert 'roles/base' not in gitconfig.read_text()
    assert gitconfig.read_text().count(str(home / '.config/git/managed')) == 1
    # npm login writes tokens to ~/.npmrc, so a read-only store link must become a local file.
    store = root / 'store-npmrc'
    store.write_text('prefix=${HOME}/.npm-global\n')
    store.chmod(0o444)
    npmrc = home / '.npmrc'
    npmrc.symlink_to(store)
    command = ['python3', str(repo / 'home/mutable.py'), 'npm', str(home)]
    subprocess.run(command, check=True)
    assert not npmrc.is_symlink()
    assert os.access(npmrc, os.W_OK), '~/.npmrc must accept npm login tokens'
    assert npmrc.stat().st_mode & 0o777 == 0o600, '~/.npmrc holds tokens, so only its owner may read it'
    npmrc.write_text('//registry.npmjs.org/:_authToken=local-token\nprefix=/old/prefix\n')
    npmrc.chmod(0o644)
    subprocess.run(command, check=True)
    subprocess.run(command, check=True)
    assert npmrc.read_text() == '//registry.npmjs.org/:_authToken=local-token\nprefix=${HOME}/.npm-global\n'
    assert npmrc.stat().st_mode & 0o777 == 0o600
print('PASS legacy handoff, private files, local credentials, backups, and repeat migration')
