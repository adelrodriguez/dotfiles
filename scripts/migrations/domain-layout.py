#!/usr/bin/env python3
"""Reproduce the domain layout from the merged Nix setup. Reruns are a no-op.

Run from a checkout of d18ebd6, or its OpenCode extraction commit. This changes
repository sources only. It never activates a host or touches the account home.
"""
from pathlib import Path
import os
import re

root = Path(__file__).resolve().parents[2]
if not (root / 'modules/home/default.nix').exists():
    if (root / 'home/default.nix').exists():
        print('Domain layout is already installed.')
        raise SystemExit(0)
    raise SystemExit('Expected the merged Nix repository layout.')


def read(name):
    return (root / name).read_text()


def write(name, contents):
    path = root / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(contents)


def body(text, marker):
    start = text.index('{', text.index(marker))
    depth = 0
    for end in range(start, len(text)):
        depth += (text[end] == '{') - (text[end] == '}')
        if depth == 0:
            return text[start:end + 1]
    raise ValueError(f'Unclosed Nix block: {marker}')


# The first unit was extracted by hand. Reproduce and compare it before the sweep.
service = read('hosts/homelab/services.nix')
if '    opencode-web = {' in service:
    block = body(service, '    opencode-web =')
    normalized = '\n'.join(line[4:] if line.startswith('    ') else line for line in block.splitlines())
    write('services/opencode/default.nix', '''{ config, lib, pkgs, ... }:
let
  home = config.home.homeDirectory;
  runtime = lib.concatStringsSep ":" config.dotfiles.runtimePaths;
in {
  home.file = {
    "services/opencode/verify.py".source = ./verify.py;
    "services/opencode/caddy.conf".source = ./caddy.conf;
  };
  systemd.user.services.opencode-web = ''' + normalized + ';\n}\n')
else:
    assert (root / 'services/opencode/default.nix').is_file()

moves = {
    'modules/home/shell.nix': 'home/shell/default.nix',
    'modules/home/git.nix': 'home/git/default.nix',
    'modules/home/agents.nix': 'home/shell/grok.nix',
    'modules/home/files.nix': 'home/apps/default.nix',
    'scripts/lib/handoff.py': 'home/handoff.py',
    'scripts/lib/mutable.py': 'home/mutable.py',
    'scripts/lib/fisher.fish': 'home/fisher.fish',
    'scripts/lib/core.sh': 'tools/runtime.sh',
    'scripts/lib/opencode.sh': 'tools/opencode.sh',
    'scripts/installers.sh': 'tools/install.sh',
    'scripts/lib/agents.sh': 'agents/deploy.sh',
    'scripts/lib/agents-env.sh': 'agents/env.sh',
    'config/Makefile': 'agents/Makefile',
    'config/agents/env.tpl': 'agents/env.tpl',
    'config/process-compose/process-compose.yaml': 'services/sync/process-compose.yaml',
    'config/bin/dotfiles-sync': 'services/sync/dotfiles-sync',
    'tests/migration.py': 'home/tests/migration.py',
    'tests/fish-limits.sh': 'home/tests/fish-limits.sh',
    'tests/grok-completions.sh': 'home/tests/grok-completions.sh',
    'tests/runtime.py': 'tools/tests/providers.py',
    'tests/agents.sh': 'agents/tests/deploy.sh',
    'tests/agents-env.sh': 'agents/tests/environment.sh',
    'hosts/mac/default.nix': 'hosts/mac/system.nix',
    'hosts/mac/packages.nix': 'hosts/mac/homebrew.nix',
}
for path in (root / 'config').rglob('*'):
    if not path.is_file():
        continue
    source = path.relative_to(root).as_posix()
    if source in moves:
        continue
    relative = path.relative_to(root / 'config')
    section = relative.parts[0]
    if section in ('fish', 'zsh'):
        moves[source] = 'home/shell/' + relative.as_posix()
    elif section == 'git':
        moves[source] = 'home/' + relative.as_posix()
    else:
        moves[source] = 'home/apps/' + relative.as_posix()


def mapped(name):
    if name in moves:
        return moves[name]
    # Nix also references directories, which are not individual tracked files.
    prefixes = {
        'modules/home': 'home', 'config/fish': 'home/shell/fish',
        'config/zsh': 'home/shell/zsh', 'config/git': 'home/git',
        'config/agents': 'agents',
    }
    for prefix, target in prefixes.items():
        if name == prefix or name.startswith(prefix + '/'):
            return target + name[len(prefix):]
    if name.startswith('config/'):
        return 'home/apps/' + name[len('config/'):]
    return name


# Rewrite Nix source paths relative to each file's destination before moving it.
for path in root.rglob('*.nix'):
    if '.git' in path.parts:
        continue
    old = path.relative_to(root).as_posix()
    new = mapped(old)
    def relocate(match):
        target = (path.parent / match[0]).resolve()
        if not target.is_relative_to(root):
            return match[0]
        target_name = mapped(target.relative_to(root).as_posix())
        if old == 'flake.nix' and target_name == 'hosts/mac':
            target_name = 'hosts/mac/system.nix'
        relative = os.path.relpath(root / target_name, (root / new).parent)
        return relative if relative.startswith('.') else './' + relative
    path.write_text(re.sub(r'(?<![\w/])\.\.?/(?:[A-Za-z0-9_./-]|\$\{[^}]+\})+', relocate, path.read_text()))
for source, destination in moves.items():
    path, target = root / source, root / destination
    data = path.read_bytes()
    target.parent.mkdir(parents=True, exist_ok=True)
    path.rename(target)
    assert target.read_bytes() == data, f'Move changed {source}'

# Update repository-path call sites without rewriting installed ~/.config paths.
for path in root.rglob('*'):
    if not path.is_file() or '.git' in path.parts or path == Path(__file__) or path.suffix not in {'.sh', '.py', '.md', '.tpl'} and path.name != 'Makefile':
        continue
    text = path.read_text()
    for source in sorted(moves, key=len, reverse=True):
        destination = moves[source]
        text = text.replace('$repo/' + source, '$repo/' + destination)
        text = text.replace('$DOTFILES_DIR/' + source, '$DOTFILES_DIR/' + destination)
        text = text.replace("repo / '" + source + "'", "repo / '" + destination + "'")
        text = text.replace("REPO / '" + source + "'", "REPO / '" + destination + "'")
        if path.suffix == '.md':
            text = text.replace(source, destination)
    text = text.replace('$repo/config/fish/', '$repo/home/shell/fish/')
    text = text.replace('$repo/config/zsh/', '$repo/home/shell/zsh/')
    text = text.replace('$repo/config/agents', '$repo/agents')
    if '/tests/' in path.as_posix() and path.parent != root / 'tests':
        text = text.replace('/.." && pwd)', '/../.." && pwd)')
        text = text.replace('.parents[1]', '.parents[2]')
        text = text.replace('"$source_repo/scripts" "$source_repo/config" "$source_repo/agents"', '"$source_repo/scripts" "$source_repo/home" "$source_repo/tools" "$source_repo/services" "$source_repo/agents"')
        text = text.replace('"$source_repo/scripts" "$source_repo/config"', '"$source_repo/scripts" "$source_repo/home" "$source_repo/tools" "$source_repo/services" "$source_repo/agents"')
    path.write_text(text)

# Tools own package declarations, runtime paths, and the generated provider contract.
old = read('modules/home/default.nix')
options = old[old.index('  options.dotfiles ='):old.index('  config =')]
files = old[old.index('        ".config/dotfiles/host"'):old.index('        "Makefile"')]
write('tools/default.nix', '{ config, lib, pkgs, machine, ... }:\n{\n' + options + '''  config = {
    home.packages = lib.unique (builtins.attrValues config.dotfiles.tools);
    home.file = {
''' + files + '''    };
    nix.package = lib.mkDefault pkgs.nix;
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
  };
}
''')
write('home/default.nix', '''{ machine, ... }:
{
  imports = [ ./apps ./shell ./git ];
  home = {
    inherit (machine) username homeDirectory;
    stateVersion = "26.05";
    sessionVariables.EDITOR = "nvim";
  };
  programs.home-manager.enable = true;
  # Reload definitions, but leave running agent sessions alone during a switch.
  systemd.user.startServices = "suggest";
}
''')
(root / 'modules/home/default.nix').unlink()
text = read('home/apps/default.nix')
text = text.replace('      ".config/agents/env.tpl".source = ../../agents/env.tpl;\n', '')
write('home/apps/default.nix', text)
write('home/shell/default.nix', read('home/shell/default.nix').replace('in {\n', 'in {\n  imports = [ ./grok.nix ];\n'))
write('agents/default.nix', '''{ ... }:
{
  home.file = {
    ".config/agents/env.tpl".source = ./env.tpl;
    "Makefile".source = ./Makefile;
  };
}
''')

# Move the machine records out of flake composition into their owning hosts.
flake = read('flake.nix')
for host in ('mac', 'homelab'):
    machine = body(flake, f'        {host} =')
    write(f'hosts/{host}/machine.nix', machine + '\n')
start = flake.index('      machines = {')
end = flake.index('      mkHome =', start)
flake = flake[:start] + '''      machines = {
        mac = import ./hosts/mac/machine.nix;
        homelab = import ./hosts/homelab/machine.nix;
      };
''' + flake[end:]
write('flake.nix', flake)
for host in ('mac', 'homelab'):
    path = f'hosts/{host}/home.nix'
    text = read(path).replace('../../home', '../../home ../../tools ../../agents')
    if host == 'homelab':
        text = text.replace('./services.nix', '../../services/opencode ../../services/t3 ../../services/sync')
    else:
        text = text.replace('../../agents ];', '../../agents ../../services ];')
    write(path, text)

# Complete the service domain, preserving the manually verified OpenCode unit.
sync_unit = body(service, '    process-compose =')
write('services/sync/default.nix', '''{ config, lib, pkgs, ... }:
let runtime = lib.concatStringsSep ":" config.dotfiles.runtimePaths;
in {
  imports = [ ../default.nix ];
  home.file = {
    ".config/process-compose/process-compose.yaml".source = ./process-compose.yaml;
    ".local/bin/dotfiles-sync" = { source = ./dotfiles-sync; executable = true; };
  };
  systemd.user.services.process-compose = ''' + sync_unit + ';\n}\n')
write('services/default.nix', '''{ config, lib, ... }:
{
  options.dotfiles.externalServices = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "User services whose main unit is owned by a vendor.";
  };
  config.home.file.".config/dotfiles/services.json".text = builtins.toJSON
    (lib.unique (builtins.attrNames config.systemd.user.services ++ config.dotfiles.externalServices));
}
''')
write('services/environment.nix', '''{ config, lib }:
let runtime = lib.concatStringsSep ":" config.dotfiles.runtimePaths;
in ''
  [Service]
  Environment="PATH=${runtime}"
  EnvironmentFile=-%h/.config/agents/env
  UnsetEnvironment=CODEX_HOME
''
''')
for directory, unit in [('opencode', 'opencode-web'), ('t3', 't3code')]:
    path = f'services/{directory}/default.nix'
    if directory == 'opencode':
        text = read(path).replace('in {\n', 'in {\n  imports = [ ../default.nix ];\n')
        text = text.replace('  home.file = {\n', '  home.file = {\n    ".config/systemd/user/opencode-web.service.d/runtime.conf".text = import ../environment.nix { inherit config lib; };\n')
    else:
        text = '''{ config, lib, ... }:
{
  imports = [ ../default.nix ];
  dotfiles.externalServices = [ "t3code" ];
  home.file.".config/systemd/user/t3code.service.d/runtime.conf".text =
    import ../environment.nix { inherit config lib; };
}
'''
    write(path, text)
(root / 'hosts/homelab/services.nix').unlink()
(root / 'services/t3/t3code.service.reference').unlink(missing_ok=True)
for command in ('services/opencode/setup.sh', 'services/t3/setup.sh'):
    (root / command).chmod(0o755)

# Keep host selection in the composition layer. Lower domains only read runtime data.
core = read('tools/runtime.sh')
host_fn = core[core.index('host_name()'):].replace('$PLATFORM', '$(uname -s)')
write('hosts/select.sh', '#!/usr/bin/env bash\nsource "$(dirname "${BASH_SOURCE[0]}")/../tools/runtime.sh"\n' + host_fn)
write('tools/runtime.sh', core[:core.index('host_name()')].replace('/../.."', '/.."').replace('PLATFORM="$(uname -s)"\n', ''))
for name in ('bootstrap', 'apply', 'sync'):
    path = f'scripts/{name}.sh'
    helper = 'hosts/select.sh' if name in ('bootstrap', 'apply') else 'tools/runtime.sh'
    write(path, read(path).replace('/lib/core.sh"', '/../' + helper + '"'))
write('tools/install.sh', read('tools/install.sh').replace('/lib/core.sh"', '/runtime.sh"'))
write('services/opencode/setup.sh', read('services/opencode/setup.sh').replace('/../../scripts/lib/core.sh"', '/../../tools/runtime.sh"').replace('scripts/installers.sh', 'tools/install.sh'))

# Agent deployment becomes one operation rather than a command-to-library pass-through.
deploy = read('agents/deploy.sh').replace('/core.sh"', '/../tools/runtime.sh"')
deploy = deploy.replace('# Deploy the agent setup in agents/ with APM at user scope.', '# Deploy the locked agent setup with APM at user scope.\nset -euo pipefail')
deploy += '\n[[ $# -eq 1 ]] || die "Usage: agents/deploy.sh sync|update"\ndeploy_agents "$1"\n'
write('agents/deploy.sh', deploy)
(root / 'agents/deploy.sh').chmod(0o755)
(root / 'scripts/agents.sh').unlink()
write('agents/Makefile', read('agents/Makefile').replace('/scripts/agents.sh', '/agents/deploy.sh'))
environment = read('agents/env.sh').replace('/core.sh"', '/../tools/runtime.sh"')
start = environment.index('# Succeeds when the unit')
refresh = environment[start:environment.index('setup_agents_env()')]
refresh = refresh.replace('  local pid\n', '  local pid env_file="$2"\n')
refresh = refresh.replace('reload_agent_services() {\n', 'reload_agent_services() {\n  local env_file="$1"\n')
refresh = refresh.replace('"$AGENTS_ENV"', '"$env_file"').replace('${AGENTS_ENV}', '${env_file}')
for unit in ('opencode-web.service', 't3code.service'):
    refresh = refresh.replace('agent_service_is_current ' + unit, 'agent_service_is_current ' + unit + ' "$env_file"')
write('services/environment.sh', '#!/usr/bin/env bash\n# Service restart policy belongs to services, not the environment writer.\nsource "$(dirname "${BASH_SOURCE[0]}")/../tools/runtime.sh"\n\n' + refresh.rstrip() + '\n')
write('agents/env.sh', environment[:start].replace('  reload_agent_services\n', ''))
write('scripts/agents-env.sh', '''#!/usr/bin/env bash
# Refresh private agent variables, then apply the service restart policy.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../agents/env.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../services/environment.sh"
[[ $# == 0 || ( $# == 1 && "$1" == --if-configured ) ]] || die 'Usage: scripts/agents-env.sh [--if-configured]'
if [[ "${1:-}" == --if-configured && ! -r "$AGENTS_TOKEN" ]]; then
  info "Skipping agent environment: no 1Password service account token at ${AGENTS_TOKEN}"
  exit 0
fi
write_agents_env
reload_agent_services "$AGENTS_ENV"
''')
text = read('scripts/bootstrap.sh').replace('/scripts/agents.sh', '/agents/deploy.sh')
text = text.replace('source "$DOTFILES_DIR/agents/env.sh"\nsetup_agents_env', '"$DOTFILES_DIR/scripts/agents-env.sh" --if-configured')
write('scripts/bootstrap.sh', text)

# Split the doctor by the state being checked, keeping its public command stable.
check = read('checks/installed.py')
prefix = check[:check.index('for name, executable')]
ending = check[check.index('if failures:'):check.index('print(f"PASS')]
home_checks = check[check.index("require(not (home / '.gitconfig')"):check.index("for name in ('env', '1password-token')")]
agent_checks = check[check.index("for name in ('env', '1password-token')"):check.index("if expected['host'] == 'mac'")]
service_checks = check[check.index("    if expected['host'] == 'homelab'"):check.index('if failures:')]
service_checks = '\n'.join(line[4:] if line.startswith('    ') else line for line in service_checks.splitlines()) + '\n'
service_checks = '\n'.join(line[4:] if line.startswith('    ') else line for line in service_checks.splitlines()[1:]) + '\n'
service_checks = service_checks.replace("for service in ('opencode-web', 't3code', 'process-compose'):", "for service in json.loads((home / '.config/dotfiles/services.json').read_text()):")
minimal = '''#!/usr/bin/env python3
"""Inspect this domain without changing installed state."""
import json
import os
from pathlib import Path
import stat
import subprocess
import sys

home = Path.home()
failures = []

def require(condition, message):
    if not condition:
        failures.append(message)

'''
write('home/check.py', minimal + home_checks + ending + "print('PASS writable home configuration')\n")
write('agents/check.py', minimal + agent_checks + ending + "print('PASS private agent file permissions')\n")
# The service checker reads the same generated runtime contract, but never rewrites PATH.
service_prefix = prefix[prefix.index('home = Path.home()'):]
write('services/check.py', minimal[:minimal.index('home = Path.home()')] + service_prefix + service_checks + ending + "print('PASS declared user services')\n")
check = check.replace(home_checks, '').replace(agent_checks, '')
start = check.index("    if expected['host'] == 'homelab'")
check = check[:start] + check[check.index('if failures:', start):]
check = check.replace("parser.add_argument('--no-services', action='store_true', help='Verify packages in a disposable home without a login user manager.')\n", '')
check = check.replace('import stat\n', '').replace('installed providers, executable tools, mutable files, and private file permissions', 'installed providers and executable tools')
write('tools/check.py', check)
write('scripts/doctor.sh', '''#!/usr/bin/env bash
# Assess each domain using the caller's PATH. Never source the runtime loader here.
set -euo pipefail
repo="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
home_only=()
services=true
for option in "$@"; do
  case "$option" in
    --home-only) home_only=(--home-only); services=false ;;
    --no-services) services=false ;;
    -h|--help) printf '%s\\n' 'Usage: scripts/doctor.sh [--home-only] [--no-services]'; exit 0 ;;
    *) printf 'Unknown option: %s\\n' "$option" >&2; exit 2 ;;
  esac
done
status=0
python3 "$repo/tools/check.py" ${home_only[@]+"${home_only[@]}"} || status=1
python3 "$repo/home/check.py" || status=1
python3 "$repo/agents/check.py" || status=1
if "$services"; then python3 "$repo/services/check.py" || status=1; fi
exit "$status"
''')
for path in (root / 'checks').glob('*'):
    if path.is_file(): path.unlink()

# Move existing behavioral fixtures with their domains and update the integration runner.
for path in (root / 'tools/tests/providers.py', root / 'tests/hosts.py'):
    text = path.read_text().replace('checks/installed.py', 'tools/check.py')
    if path.name == 'providers.py':
        text = text.replace(", '--no-services'", '').replace("['installed.py', '--no-services']", "['check.py']")
    else:
        text = text.replace("doctor = str(repo / 'tools/check.py')", "doctor = str(repo / 'scripts/doctor.sh')")
        text = text.replace("shlex.join(['python3', doctor,", "shlex.join(['bash', doctor,")
    path.write_text(text)
providers = read('tools/tests/providers.py')
start = providers.index('    def test_fish_removes_global')
end = providers.index("\n\nif __name__ == '__main__':")
fixture = providers[providers.index('    def setUp(self):'):providers.index('    def doctor_fixture(self):')]
write('home/tests/runtime.py', '''#!/usr/bin/env python3
"""Check shell startup and file handoff through their public interfaces."""
from pathlib import Path
import json
import os
import shutil
import shlex
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]
FISH = shutil.which('fish')

class Home(unittest.TestCase):
''' + fixture + providers[start:end] + "\n\nif __name__ == '__main__':\n    unittest.main()\n")
write('tools/tests/providers.py', providers[:start] + providers[end:])
text = read('agents/tests/environment.sh').replace('setup() { bash -c \'source "$1/scripts/lib/agents-env.sh"; setup_agents_env\' _ "$repo"; }', 'setup() { bash "$repo/scripts/agents-env.sh" --if-configured; }')
write('agents/tests/environment.sh', text)
write('agents/tests/deploy.sh', read('agents/tests/deploy.sh').replace('/scripts/agents.sh', '/agents/deploy.sh'))
write('tests/check.sh', '''#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$repo/home/tests/migration.py"
python3 "$repo/home/tests/runtime.py"
python3 "$repo/tools/tests/providers.py"
for test in agents/tests/environment.sh agents/tests/deploy.sh home/tests/fish-limits.sh home/tests/grok-completions.sh; do
  bash "$repo/$test"
done
''')
# home/ is now tracked source, not the historical untracked Stow directory.
write('.gitignore', read('.gitignore').replace('/home/\n', '').replace('config/agents/', 'agents/'))
for directory in ('config', 'modules', 'scripts/lib', 'checks'):
    for path in sorted((root / directory).rglob('*'), reverse=True):
        if path.is_dir() and not any(path.iterdir()): path.rmdir()
    path = root / directory
    if path.is_dir() and not any(path.iterdir()): path.rmdir()
print('Moved domain sources, updated callers, and preserved installed paths.')
