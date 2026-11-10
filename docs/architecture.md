# Domain ownership and interfaces

The host declarations choose the installed environment. Shared domains implement those choices. Each domain keeps its Nix declarations, configuration, runtime code, and focused tests together.

## Hosts

`flake.nix` composes the records in `hosts/<host>/machine.nix` with each host's `home.nix`. The Mac also has `system.nix` for nix-darwin and `homebrew.nix` for Homebrew. `hosts/select.sh` resolves command arguments and the installed host record, including the legacy `server` alias.

Each host owns its package and installer choices. Node 26 is declared once per host, and runtime paths derive from that package. Mac pnpm belongs to Homebrew. Homelab pnpm belongs to Nix.

## Domain interfaces

| Domain | Public interface | Owned state |
| --- | --- | --- |
| `home/` | `default.nix`, `handoff.py`, `check.py` | Managed home files, local Git includes, writable npm and Grok configuration, and migration backups. |
| `tools/` | `default.nix`, `install.sh`, `runtime.sh`, `check.py` | Package expectations, runtime paths, and writable CLI installation. |
| `agents/` | `default.nix`, `deploy.sh`, `env.sh`, `check.py` | APM deployment and lock reconciliation, private environment generation and permission checks. |
| `services/` | Each service's `default.nix` and `setup.sh`, plus `default.nix`, `environment.sh`, and `check.py` | Unit definitions, runtime preparation, service expectations, and restart policy. OpenCode's `verify.py` checks the private integration on the deployed host. |

Other files are internal to their domain. Host composition imports the Nix entry points. Commands call the domain operations. Focused tests live under each domain's `tests/`. Complete host tests live under `tests/`.

The public orchestration commands are `scripts/bootstrap.sh`, `scripts/apply.sh`, `scripts/sync.sh`, `scripts/doctor.sh`, and `scripts/agents-env.sh`. `make -C ~ agents:sync` and `make -C ~ agents:update` invoke `agents/deploy.sh` through the installed Makefile.

## Dependency direction

Commands and hosts may depend on domain entry points. Home and agents may depend on tools. Services may depend on agents and tools. Tools never imports another domain. Shared domains never import a host or a command implementation.

`python3 tests/boundaries.py` checks Nix paths, repository-relative shell references, and local Python imports. It rejects reversed dependencies, imports of private files, missing targets, and source cycles. The installed sync launcher may execute the public sync command. That scheduled callback is not a source import.

## Installed contracts

`tools/default.nix` generates `~/.config/dotfiles/expected.json` from the host's declarations. It records executable providers, direct npm versions, Homebrew packages, vendor tools, and runtime order. Installation and provider checks consume that same file. `~/.config/agents/runtime.path` supplies the declared PATH to shells, installers, and services.

`services/default.nix` generates `~/.config/dotfiles/services.json` from the declared Home Manager units and externally owned services. T3 declares its vendor-owned main unit there. Nix owns only T3's environment drop-in.

The doctor checks the caller's observed PATH. It aggregates tool, home, agent, and service findings without repairing state. `--home-only` skips runtime packages and services. `--no-services` checks packages without requiring a login user manager.

The environment writer only creates the private environment file. Service refresh policy belongs to `services/environment.sh`. It restarts stale OpenCode processes and reports when T3 needs a deliberate restart. An ordinary apply preserves running sessions.

## Repository migration

`scripts/migrations/domain-layout.py` reproduces the source moves and caller changes from revision `d18ebd6`, or the subsequent OpenCode extraction commit. It never applies a machine configuration. A second run leaves the repository unchanged. Older scripts in that directory record earlier repository conversions and are not bootstrap steps.

Run `bash tests/check.sh` for boundary and domain behavior checks. CI also runs `python3 tests/hosts.py --runtime` on Ubuntu and macOS to activate isolated homes, verify installed providers and project Node selection, and check rollback and profile isolation. The Mac job builds nix-darwin without activating root-level integration.
