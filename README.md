# dotfiles

Personal shell, tool, and agent configuration. GNU Stow links the files in this repository into `$HOME`.

See [Install the dotfiles](docs/install.md) to set up a machine.

See [Host OpenCode and T3 services](docs/agent-services.md) to restore the native
web servers, their systemd services, and the OpenCode homelab proxy route.

## Scripts

Each task is a script in the repository. Run them from any directory.

| Script | Description |
| --- | --- |
| `scripts/install.sh` | Installs platform packages, links the dotfiles, configures fish, and starts the Process Compose service on Linux. Safe to rerun. |
| `scripts/sync.sh` | Fast-forwards the current branch, then links the dotfiles. |
| `scripts/link.sh` | Backs up existing target files and links `home/` into `$HOME` with GNU Stow. |
| `scripts/package.sh install` | Installs every tracked package for the current platform. |
| `scripts/package.sh add <name> [apt\|brew\|cask]` | Installs and records a package. Defaults to APT on Ubuntu and a Homebrew formula on macOS. |
| `scripts/package.sh remove <name>` | Removes a package from the platform manifest, then offers to uninstall APT/Homebrew packages. Upstream tools require manual uninstallation. |
| `scripts/package.sh update [name]` | Updates one tracked package or all packages for the current platform. |
| `scripts/package.sh list` | Lists the current platform's tracked packages by source. |

`scripts/sync.sh` stops before it changes `$HOME` if `git pull --no-rebase --ff-only` fails.

## Repository layout

The main paths are:

| Path | Contents |
| --- | --- |
| `scripts/*.sh` | The commands in the table above. They only load modules and call them. |
| `scripts/lib/` | Modules: files that define functions and run nothing when loaded. |
| `scripts/lib/core.sh` | Repository paths, `PATH`, and output helpers. Every module loads it. |
| `scripts/lib/home.sh` | Backs up conflicts and links `home/` with GNU Stow. |
| `scripts/lib/fish.sh`, `scripts/lib/process-compose.sh` | Machine setup steps. |
| `scripts/lib/packages/` | `packages.sh` picks `linux.sh` or `macos.sh`. `linux.sh` uses `extras.sh` for upstream tools, which uses `github-release.sh` and `opencode.sh`. |
| `tests/` | Checks for the scripts and the installed tools. |
| `home/` | Files that GNU Stow links into `$HOME`. |
| `packages/macos/Brewfile` | Homebrew formulae and casks for macOS. |
| `packages/linux/apt.txt` | Ubuntu APT packages, one per line. |
| `packages/linux/extras.txt` | Enabled upstream tools, one per line. |
| `backups/` | Files moved out of the way during a sync. |
| `docs/` | Setup and maintenance guides. |

Dependencies point one way: `tests/` → `scripts/*.sh` → `scripts/lib/` modules → `scripts/lib/core.sh`. A module loads only `core.sh` and modules below it in the list above; it never loads a command or a module that depends on it. `packages/` holds data only.

## Local configuration

Linux installation currently supports Ubuntu. APT manages OS dependencies and build tools. Git uses the Git maintainers' PPA; the 1Password CLI uses its official APT repository. Developer tools use the latest stable upstream releases, rather than Ubuntu's older versions. fnm manages Node, and npm installs pnpm, Graphite, Pi, and Vercel. Codex uses OpenAI's standalone installer. Ghostty remains macOS-only in the manifests.

`scripts/package.sh update` updates every tracked tool to the latest stable release from its configured source. Node uses the latest Current release, not just LTS, and becomes the fnm default. Existing Node versions and project-specific version files remain available. `scripts/install.sh` resolves the latest GitHub releases and skips other upstream installers when their tools are already present. Atuin must be at least 18.23.0 to read the history database migrated by the previous Linuxbrew installation.

GitHub release binaries live under `~/.local/share/dot-tools/<tool>/<version>` and are linked into `~/.local/bin`. Neovim's runtime files stay alongside its binary. Bubblewrap is built from its upstream release; GNU Stow is built from its latest published tarball. Updates preserve prior version directories. Run `bash tests/packages.sh` to check package-command behavior without changing installed packages, and `bash tests/installed-tools.sh` from a fresh fish session to check the installed tools.

To track another upstream tool, add its installer to `scripts/lib/packages/extras.sh` and its name to `packages/linux/extras.txt`. `scripts/package.sh add` on Linux handles APT packages only. The manifests track intended packages, not their transitive dependencies or exact versions.

Fish is the default interactive shell. `scripts/install.sh` installs fish, registers it in `/etc/shells`, and selects it as the account's login shell.

`home/.config/fish/conf.d/99-local.fish` loads `~/.config/fish/conf.d/99-local.private.fish` when the file exists. The repository does not track `99-local.private.fish`.

## Scheduled sync

Process Compose reads `home/.config/process-compose/process-compose.yaml`. The `dotfiles-sync` process runs `scripts/sync.sh` every 15 minutes and permits one run at a time.

On Linux, `scripts/install.sh` enables `home/.config/systemd/user/process-compose.service` on port `10080`. The `pc` shell alias attaches to the Process Compose TUI. In the TUI, `F9` pauses the process and `F7` resumes it.
