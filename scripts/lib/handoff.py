#!/usr/bin/env python3
"""Back up conflicting targets before handing file ownership to Home Manager."""
import json
import os
from pathlib import Path
import shutil
import sys
from mutable import backup


def handoff(home, checkout, targets, fish='fish'):
    home, checkout = home.resolve(), checkout.resolve()
    # Materialize folded checkout directories before individual file handoff.
    for relative in targets:
        path = home / relative
        for parent in reversed(path.parents):
            if parent == home or home not in parent.parents or not parent.is_symlink():
                continue
            resolved = parent.resolve()
            if not str(resolved).startswith(str(checkout) + '/'):
                raise RuntimeError(f'Refusing to write through foreign directory link {parent}')
            backup(home, parent)
            parent.unlink()
            if resolved.is_dir():
                shutil.copytree(resolved, parent, symlinks=True)
            else:
                parent.mkdir(parents=True)
    for relative in targets:
        path = home / relative
        if path.is_symlink() and str(path.resolve()).startswith('/nix/store/'):
            continue
        if path.exists() or path.is_symlink():
            backup(home, path)
            if path.is_dir() and not path.is_symlink():
                raise RuntimeError(f'Refusing to replace directory {path}')
            path.unlink()
    # Retire links to removed files, including old tmux and service drop-ins.
    links = [path for path in home.iterdir() if path.is_symlink()]
    for directory in (home / '.config', home / '.local/bin'):
        if directory.is_dir():
            for base, dirs, files in os.walk(directory):
                links.extend(Path(base) / name for name in dirs + files if (Path(base) / name).is_symlink())
    for path in links:
        relative = path.relative_to(home).as_posix()
        if relative in ('.gitconfig', '.config/fish/completions/grok.fish') or '.wants/' in relative:
            continue
        if str(path.resolve()).startswith(str(checkout) + '/'):
            backup(home, path)
            path.unlink()
    # Old enable links must point through Home Manager's unit, not the checkout.
    units = home / '.config/systemd/user'
    for path in units.glob('*.wants/*'):
        if path.is_symlink() and str(path.resolve()).startswith(str(checkout) + '/'):
            name = path.name
            path.unlink()
            path.symlink_to('../' + name)
    # Remove aliases to skills APM has pruned. Keep every live integration.
    for path in (home / '.config').glob('*/skills/*'):
        if path.is_symlink() and not path.exists() and str(path.resolve()).startswith(str(home / '.agents/skills') + '/'):
            path.unlink()


if __name__ == '__main__':
    home, checkout, manifest, *fish = sys.argv[1:]
    handoff(Path(home), Path(checkout), json.loads(Path(manifest).read_text()), *(fish or []))
