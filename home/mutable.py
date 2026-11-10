#!/usr/bin/env python3
"""Keep files written by credential and CLI tools outside the Nix store."""
from datetime import datetime, timezone
from pathlib import Path
import shutil
import subprocess
import sys


def backup(home, path):
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    target = home / '.local/state/dotfiles/backups' / stamp / path.relative_to(home)
    target.parent.mkdir(parents=True, exist_ok=True)
    # Preserve the contents of old checkout links before moving to an immutable source.
    if path.is_file():
        shutil.copy2(path, target)
    elif path.is_symlink():
        target.symlink_to(path.readlink())
    print(f'Backed up {path} to {target}')


def git_include(home, checkout, git):
    path = home / '.gitconfig'
    managed = home / '.config/git/managed'
    if path.is_symlink():
        backup(home, path)
        contents = path.read_text() if path.exists() else ''
        path.unlink()
        path.write_text(contents)
    path.touch(exist_ok=True)
    includes = subprocess.run([git, 'config', '--file', str(path), '--get-all', 'include.path'],
                              text=True, capture_output=True, check=False)
    if includes.returncode not in (0, 1):
        raise RuntimeError(includes.stderr)
    for include in includes.stdout.splitlines():
        # Only retire this checkout's old managed include, never local credentials.
        if include in (f'{checkout}/roles/base/home/.gitconfig', f'{checkout}/home/.gitconfig'):
            subprocess.run([git, 'config', '--file', str(path), '--fixed-value',
                            '--unset-all', 'include.path', include], check=True)
    includes = subprocess.run([git, 'config', '--file', str(path), '--get-all', 'include.path'],
                              text=True, capture_output=True, check=False).stdout.splitlines()
    if str(managed) not in includes:
        # Include managed defaults first so local overrides retain precedence.
        contents = path.read_text()
        temporary = path.with_name('.gitconfig.dotfiles-new')
        temporary.write_text('')
        subprocess.run([git, 'config', '--file', str(temporary), 'include.path', str(managed)], check=True)
        temporary.write_text(temporary.read_text() + contents)
        temporary.chmod(path.stat().st_mode & 0o777)
        temporary.replace(path)


def npmrc(home):
    path = home / '.npmrc'
    if path.is_symlink():
        backup(home, path)
        contents = path.read_text() if path.exists() else ''
        path.unlink()
        path.write_text(contents)
    path.touch(mode=0o600, exist_ok=True)
    lines = [line for line in path.read_text().splitlines() if not line.replace(' ', '').startswith('prefix=')]
    contents = '\n'.join([*lines, 'prefix=${HOME}/.npm-global']) + '\n'
    if path.read_text() != contents:
        path.write_text(contents)


def completion(home, source):
    target = home / '.config/fish/completions/grok.fish'
    if target.is_file() and not target.is_symlink() and target.read_bytes() == source.read_bytes():
        return
    if target.exists() or target.is_symlink():
        backup(home, target)
        target.unlink()
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)


if __name__ == '__main__':
    operation, directory, *args = sys.argv[1:]
    home = Path(directory)
    if operation == 'git':
        git_include(home, args[0], args[1])
    elif operation == 'npm':
        npmrc(home)
    elif operation == 'completion':
        completion(home, Path(args[0]))
    else:
        raise SystemExit(f'Unknown mutable file: {operation}')
