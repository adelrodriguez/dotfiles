# dotfiles

Personal shell, tool, and agent configuration. GNU Stow links the files in this repository into `$HOME`.

See [Install the dotfiles](docs/install.md) to set up a machine.

## Commands

`dot` provides these commands:

| Command | Description |
| --- | --- |
| `dot init` | Installs platform packages, links the dotfiles, installs TPM, configures fish, and starts the Process Compose service on Linux. |
| `dot update` | Fast-forwards the current branch. The command rejects changes to tracked files. |
| `dot sync` | Fast-forwards the current branch, backs up existing target files, and links the dotfiles. |
| `dot package add <name> [apt\|brew\|cask]` | Installs and records a package. Defaults to APT on Ubuntu and a Homebrew formula on macOS. |
| `dot package remove <name>` | Removes a package from the platform manifest, then offers to uninstall APT/Homebrew packages. Upstream tools require manual uninstallation. |
| `dot package update [name]` | Updates one tracked package or all packages for the current platform. |
| `dot package list` | Lists the current platform's tracked packages by source. |
| `dot --version` | Prints the `dot` version. |
| `dot --help` | Prints command usage. |

`dot sync` stops before it changes `$HOME` if `git pull --no-rebase --ff-only` fails.

## Repository layout

The main paths are:

| Path | Contents |
| --- | --- |
| `dot` | The command-line interface. |
| `install.sh` | The script that links `dot` into `~/.local/bin`. |
| `home/` | Files that GNU Stow links into `$HOME`. |
| `packages/macos/Brewfile` | Homebrew formulae and casks for macOS. |
| `packages/linux/apt.txt` | Ubuntu APT packages, one per line. |
| `packages/linux/extras.txt` | Enabled upstream tools, one per line. |
| `packages/linux/install-extras.sh` | Upstream installers for tools outside APT. |
| `backups/` | Files moved out of the way during a sync. |
| `docs/` | Setup and maintenance guides. |

## Local configuration

Linux installation currently supports Ubuntu. APT manages OS dependencies and build tools. Git uses the Git maintainers' PPA; the 1Password CLI uses its official APT repository. Developer tools use the latest stable upstream releases, rather than Ubuntu's older versions. fnm manages Node, and npm installs pnpm, Graphite, Pi, Vercel, and Codex. Ghostty remains macOS-only in the manifests.

`dot package update` updates every tracked tool to the latest stable release from its configured source. Node uses the latest Current release, not just LTS, and becomes the fnm default. Existing Node versions and project-specific version files remain available. `dot init` resolves the latest GitHub releases and skips other upstream installers when their tools are already present. Atuin must be at least 18.23.0 to read the history database migrated by the previous Linuxbrew installation.

GitHub release binaries live under `~/.local/share/dot-tools/<tool>/<version>` and are linked into `~/.local/bin`. Neovim's runtime files stay alongside its binary. tmux and Bubblewrap are built from their upstream releases; GNU Stow is built from its latest published tarball. Updates preserve prior version directories. Run `bash packages/linux/verify.sh` to check package-command behavior without changing installed packages.

To track another upstream tool, add its installer to `packages/linux/install-extras.sh` and its name to `extras.txt`. `dot package add` on Linux handles APT packages only. The manifests track intended packages, not their transitive dependencies or exact versions.

Fish is the default interactive shell. `dot init` installs fish, registers it in `/etc/shells`, and selects it as the account's login shell. New tmux panes also start fish.

`home/.config/fish/conf.d/99-local.fish` loads `~/.config/fish/conf.d/99-local.private.fish` when the file exists. The repository does not track `99-local.private.fish`.

## Scheduled sync

Process Compose reads `home/.config/process-compose/process-compose.yaml`. The `dotfiles-sync` process runs `dot sync` every 15 minutes and permits one run at a time.

On Linux, `dot init` enables `home/.config/systemd/user/process-compose.service` on port `10080`. The `pc` shell alias attaches to the Process Compose TUI. In the TUI, `F9` pauses the process and `F7` resumes it.
