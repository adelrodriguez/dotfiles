#!/usr/bin/env python3
"""Move tracked Stow sources into config/. Safe to rerun after the migration."""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[2]
old = root / 'roles/base/home'
for source in sorted(old.rglob('*')):
    if not source.is_file():
        continue
    relative = source.relative_to(old).as_posix()
    if relative.startswith('.config/systemd/') or relative in {
        '.config/agents/runtime.path', '.local/bin/.keep',
        '.config/fish/config.fish', '.config/fish/fish_plugins',
        '.config/fish/completions/fisher.fish',
        '.config/fish/completions/fzf_configure_bindings.fish',
    }:
        source.unlink()
        continue
    destination = {
        '.gitconfig': 'git/config', '.npmrc': 'npm/npmrc',
        '.ripgreprc': 'ripgreprc', '.zshenv': 'zsh/zshenv',
        '.zprofile': 'zsh/zprofile', '.zshrc': 'zsh/zshrc',
        '.local/bin/dotfiles-sync': 'bin/dotfiles-sync',
    }.get(relative, relative.removeprefix('.config/'))
    target = root / 'config' / destination
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        raise SystemExit(f'Refusing to overwrite {target}')
    shutil.move(source, target)
for directory in sorted(old.rglob('*'), reverse=True):
    if directory.is_dir():
        directory.rmdir()
if old.exists():
    old.rmdir()
