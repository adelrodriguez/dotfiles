#!/usr/bin/env python3
"""Reject reversed dependencies, imports of private files, and source cycles."""
import argparse
import ast
from pathlib import Path
import re
import sys

# Entry points compose domains. Lower domains never import their callers.
DEPENDENCIES = {
    'flake.nix': {'hosts'},
    'hosts': {'home', 'tools', 'agents', 'services'},
    'scripts': {'hosts', 'home', 'tools', 'agents', 'services'},
    'home': {'tools'},
    'services': {'agents', 'tools'},
    'agents': {'tools'},
    'tools': set(),
}
EXPORTS = {
    'hosts': {'select.sh', '*/machine.nix', '*/home.nix', '*/system.nix'},
    'home': {'default.nix', 'check.py', 'handoff.py'},
    'tools': {'default.nix', 'install.sh', 'check.py', 'runtime.sh'},
    'agents': {'default.nix', 'deploy.sh', 'env.sh', 'check.py'},
    'services': {'default.nix', '*/default.nix', '*/setup.sh', 'environment.sh', 'check.py'},
    'scripts': {'bootstrap.sh', 'apply.sh', 'sync.sh', 'doctor.sh', 'agents-env.sh'},
}


def references(root, path, text):
    if path.suffix == '.nix':
        for value in re.findall(r'(?<![\w/])\.\.?/(?:[\w./-]|\$\{[^}]+\})+', text):
            # The flake selects a host by its validated name.
            yield path.parent / re.sub(r'\$\{[^}]+\}', '*', value), 'import'
    if path.suffix == '.sh' or path.name == 'dotfiles-sync':
        for value in re.findall(r'\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)(/[\w./-]+)', text):
            if Path(value).suffix:
                yield path.parent / value.lstrip('/'), 'import'
        for variable, value in re.findall(r'\$(DOTFILES_DIR|repo|checkout)/([\w./-]+)', text):
            # A saved launcher calls a public command. It does not import it.
            yield value, 'callback' if variable == 'checkout' else 'import'
    if path.suffix == '.py':
        for node in ast.walk(ast.parse(text)):
            if isinstance(node, ast.ImportFrom):
                modules = [(node.module, node.level)] if node.module else [(alias.name, node.level) for alias in node.names]
            elif isinstance(node, ast.Import):
                modules = [(alias.name, 0) for alias in node.names]
            else:
                continue
            for module, level in modules:
                base = root if not level and module.split('.')[0] in DEPENDENCIES else path.parent
                for _ in range(max(0, level - 1)):
                    base = base.parent
                target = base / module.replace('.', '/')
                yield target / '__init__.py' if target.is_dir() else target.with_suffix('.py'), 'python'


def check(root):
    failures = []
    graph = {}
    paths = [root / 'flake.nix']
    for domain in DEPENDENCIES:
        if domain != 'flake.nix':
            paths.extend(path for path in (root / domain).rglob('*')
                         if path.is_file() and not {'tests', '__pycache__', 'migrations'} & set(path.relative_to(root).parts))
    for path in paths:
        if not path.is_file() or path.suffix not in {'.nix', '.sh', '.py'} and path.name != 'dotfiles-sync':
            continue
        source = path.relative_to(root).as_posix()
        owner = source.split('/')[0]
        graph.setdefault(source, set())
        # Comments describe legacy layouts and are not dependency declarations.
        text = '\n'.join(line for line in path.read_text().splitlines() if not line.lstrip().startswith('#'))
        for target, kind in references(root, path, text):
            target = Path(target) if isinstance(target, Path) else root / target
            target = target.resolve()
            if not target.is_relative_to(root):
                continue
            pattern = target.relative_to(root).as_posix()
            matches = list(root.glob(pattern)) if '*' in pattern else [target]
            if not matches:
                failures.append(f'{source}: missing dependency {pattern}')
            for destination in matches:
                if destination.is_dir() and (destination / 'default.nix').is_file():
                    destination /= 'default.nix'
                if not destination.exists():
                    if kind != 'python':
                        failures.append(f'{source}: missing dependency {pattern}')
                    continue
                name = destination.relative_to(root).as_posix()
                domain = name.split('/')[0]
                if owner != domain:
                    if kind == 'callback':
                        allowed = domain == 'scripts'
                    else:
                        allowed = domain in DEPENDENCIES[owner]
                    if not allowed:
                        failures.append(f'{source}: forbidden dependency on {name}')
                        continue
                    public = Path(name).relative_to(domain)
                    if not any(len(public.parts) == len(Path(export).parts) and public.match(export)
                               for export in EXPORTS[domain]):
                        failures.append(f'{source}: imports private file {name}')
                if kind != 'callback':
                    graph[source].add(name)

    visited = set()
    active = []

    def visit(node):
        if node in active:
            failures.append('Source cycle: ' + ' -> '.join(active[active.index(node):] + [node]))
            return
        if node in visited:
            return
        active.append(node)
        for child in sorted(graph.get(node, ())):
            visit(child)
        active.pop()
        visited.add(node)

    for node in sorted(graph):
        visit(node)
    return failures


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    failures = check(args.root.resolve())
    if failures:
        print('\n'.join(failures), file=sys.stderr)
        raise SystemExit(1)
    print('PASS domain exports, dependency direction, and source cycles')
