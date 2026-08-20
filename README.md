# dotfiles

Personal shell, tool, and agent configuration. GNU Stow links the files in this repository into `$HOME`.

See [Install the dotfiles](docs/install.md) to set up a machine.

## Commands

`dot` provides these commands:

| Command | Description |
| --- | --- |
| `dot init` | Installs Homebrew packages, links the dotfiles, installs TPM, configures fish, and starts the Process Compose service on Linux. |
| `dot update` | Fast-forwards the current branch. The command rejects changes to tracked files. |
| `dot sync` | Fast-forwards the current branch, backs up existing target files, and links the dotfiles and agent skills. |
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
| `agents/skills/` | The agent skills that GNU Stow exposes at `~/.agents/skills`. |
| `packages/bundle` | The Homebrew Brewfile. |
| `backups/` | Files moved out of the way during a sync. |
| `docs/` | Setup and maintenance guides. |

## Local configuration

`home/.zshrc` loads `~/.zshrc.local` when the file exists. The repository does not track `~/.zshrc.local`.

## Agent skills

`~/.agents/skills` points to `agents/skills/`. Changes made by a global Skills CLI command therefore appear in this repository.

See [Manage agent skills](docs/manage-agent-skills.md) to add or create a skill.

## Scheduled sync

Process Compose reads `home/.config/process-compose/process-compose.yaml`. The `dotfiles-sync` process runs `dot sync` every 15 minutes and permits one run at a time.

On Linux, `dot init` enables `home/.config/systemd/user/process-compose.service` on port `10080`. The `pc` shell alias attaches to the Process Compose TUI. In the TUI, `F9` pauses the process and `F7` resumes it.
