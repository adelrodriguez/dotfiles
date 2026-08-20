# dotfiles

Personal shell, tool, and agent configuration. GNU Stow links the files in this repository into `$HOME`.

See [Install the dotfiles](docs/install.md) to set up a machine.

## Commands

`dot` provides these commands:

| Command | Description |
| --- | --- |
| `dot init` | Installs Homebrew packages, links the dotfiles, installs TPM, configures fish, and starts the Process Compose service on Linux. |
| `dot update` | Fast-forwards the current branch. The command rejects changes to tracked files. |
| `dot sync` | Fast-forwards the current branch, backs up existing target files, and links the dotfiles. |
| `dot package add <name> [brew\|cask]` | Adds and installs a Homebrew formula or cask. |
| `dot package remove <name>` | Removes a formula or cask from `packages/bundle`, then offers to uninstall it. |
| `dot package update [name]` | Updates one package or all Homebrew packages. |
| `dot package list` | Lists the taps, formulae, and casks in `packages/bundle`. |
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
| `packages/bundle` | The Homebrew Brewfile. |
| `backups/` | Files moved out of the way during a sync. |
| `docs/` | Setup and maintenance guides. |

## Local configuration

Fish is the default interactive shell. `dot init` installs fish, registers it in `/etc/shells`, and selects it as the account's login shell. New tmux panes also start fish.

`home/.config/fish/conf.d/99-local.fish` loads `~/.config/fish/conf.d/99-local.private.fish` when the file exists. The repository does not track `99-local.private.fish`.

## Scheduled sync

Process Compose reads `home/.config/process-compose/process-compose.yaml`. The `dotfiles-sync` process runs `dot sync` every 15 minutes and permits one run at a time.

On Linux, `dot init` enables `home/.config/systemd/user/process-compose.service` on port `10080`. The `pc` shell alias attaches to the Process Compose TUI. In the TUI, `F9` pauses the process and `F7` resumes it.
