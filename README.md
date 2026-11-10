# dotfiles

Personal shell, tool, and agent configuration for an Apple Silicon Mac and an Ubuntu homelab. Nix and Home Manager own the declared environment. The Mac also uses nix-darwin and Homebrew. Ubuntu remains Ubuntu.

[Install or migrate a machine](docs/install.md). [Deploy the agent setup](docs/agents.md). [Operate the agent services](docs/agent-services.md). The [trial results](docs/nix-trial-results.md) record the earlier installer experiment and its limits.

## Repository layout

| Path | Ownership |
| --- | --- |
| `flake.nix`, `flake.lock` | Host composition and pinned Nix inputs. |
| `hosts/<host>/machine.nix` | The host's account, checkout, and architecture. |
| `hosts/<host>/home.nix` | The host's packages, installers, runtime order, and service selection. |
| `hosts/mac/system.nix`, `hosts/mac/homebrew.nix` | Mac system integration and Homebrew declarations. pnpm stays in Homebrew. |
| `home/` | Home Manager declarations, shell and app config, writable exceptions, and file handoff. |
| `tools/` | Generated package expectations, runtime paths, installers, and provider checks. |
| `agents/` | APM manifest and lock, deployment, and private environment generation. |
| `services/` | Service declarations, setup, verification, and restart policy. |
| `scripts/` | Bootstrap, apply, sync, doctor, and environment orchestration. |
| `tests/` | Domain boundary checks and complete host integration tests. Focused tests stay with their domain. |

Host modules import the shared Home Manager modules. Shared modules never import host modules. Each host declares its own installers and packages. Adding another distribution means adding a host declaration, rather than adding distribution branches to a shared package manager.

The [architecture reference](docs/architecture.md) lists the domain interfaces and allowed dependencies.

## Commands

| Command | Result |
| --- | --- |
| `scripts/bootstrap.sh mac` | Install Nix if missing, apply nix-darwin and Home Manager, install the Mac's npm tools, and deploy agents. |
| `scripts/bootstrap.sh homelab` | Apply Home Manager, install homelab's runtime CLIs, deploy agents, and enable the Linux services. `server` remains an alias. |
| `scripts/apply.sh [mac\|homelab] --build` | Build the complete host configuration without activating it. |
| `scripts/apply.sh [mac\|homelab]` | Build, back up legacy file conflicts, and activate the recorded host. |
| `scripts/sync.sh` | Fast-forward the checkout and apply its pinned configuration. |
| `tools/install.sh` | Install the active host's npm packages and missing writable vendor tools. |
| `scripts/doctor.sh` | Check installed providers, executable tools, mutable files, private permissions, and Linux service state. |
| `make -C ~ agents:sync` | Deploy APM's locked agent setup. |
| `make -C ~ agents:update` | Update the APM lock and deploy it. |
| `scripts/agents-env.sh` | Inject `op://` references into the private agent environment. |

Nix inputs change only when `flake.lock` changes. Homebrew packages follow their host declarations without fixed versions. Each host pins direct npm package versions. npm resolves their transitive dependencies. Vendor CLIs retain their supported self-update mechanisms. Nix generations roll back managed files and Nix packages. They do not roll back Homebrew, npm, credentials, databases, or vendor runtime state.

## Runtime and writable state

Each host generates `~/.config/agents/runtime.path`. Fish, zsh, installers, and Linux services use that order. Nix owns the default Node 26. fnm owns project versions. Each host declares its base package once in `dotfiles.tools.node`, and its runtime path follows that declaration. The Mac Home Manager profile precedes Homebrew for Nix-owned tools. Homebrew pnpm resolves to `/opt/homebrew/bin/pnpm`, ahead of old npm-global installations. Homelab uses Nix pnpm and excludes old Linuxbrew directories.

Home Manager replaces GNU Stow. It links individual files into real directories, leaving private and generated files writable. The migration backs up conflicting files under `~/.local/state/dotfiles/backups/` before activation. `~/.gitconfig` remains a regular local file with a managed include. `~/.npmrc` remains a regular local file so `npm login` can store tokens. Activation sets only its `prefix`. `home/default.nix` fails the build when `home.file` links a file that its tool writes, such as `~/.npmrc` or `~/.config/gh/hosts.yml`. Grok's completion remains a regular copy because its updater rewrites it.

APM owns `~/.apm`, generated agent files, and shared skills. These remain outside the Nix store. Paper remains a Mac integration. Its absence on Linux is accepted. Codex uses `~/.codex`. Shells and Linux service drop-ins remove `CODEX_HOME`, and old authentication is not copied.

`agents/env.tpl` contains only `op://` references. `scripts/agents-env.sh` writes `~/.config/agents/env` with mode 0600 using the machine's private `~/.config/agents/1password-token`. These runtime files never belong in the checkout or the Nix store. Environment refreshes restart OpenCode only when needed and report when T3 needs a deliberate restart.

## Verification

`bash tests/check.sh` enforces domain exports and dependency direction, checks doctor composition, and verifies migration behavior, observed executable providers, Fish variable scopes, APM workflows, environment loaders, fish limits, and Grok completion. `python3 tests/hosts.py --runtime` activates the complete host Home Manager configuration in a temporary home, installs that host's declared runtime packages, and checks executable providers. The Mac run also builds the full nix-darwin system and installs its generated Brewfile. CI runs both Ubuntu 24.04 x86_64 and macOS 15 arm64.

The harness isolates `HOME`, XDG directories, `NIX_STATE_DIR`, and `NIX_STATE_HOME`, and checks that account profiles remain unchanged. Temporary homes have no login user manager, so CI checks package state and generated service definitions. Run `scripts/doctor.sh` on a deployed host to check the caller's executable providers and active services. The doctor accepts the fnm Node selected by a project version file. The Mac CI build does not activate root-level nix-darwin integration.

Process Compose runs `scripts/sync.sh` every 15 minutes on homelab. The Mac has no scheduled sync. A sync fast-forwards and applies pinned Nix configuration. Apply also installs missing runtime tools and changed direct npm versions. Existing agent sessions are not restarted during an apply.
