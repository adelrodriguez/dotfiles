# dotfiles

Personal shell, tool, and agent configuration. Each machine runs a profile, such as `server` or `mac`. A profile lists roles, and each role brings its own packages and the files that GNU Stow links into `$HOME`.

See [Install the dotfiles](docs/install.md) to set up a machine.

See [Deploy the agent setup](docs/agents.md) for the skills, instructions, and MCP servers that APM installs for every coding agent.

See [Host OpenCode and T3 services](docs/agent-services.md) to restore the native
web servers, their systemd services, and the OpenCode homelab proxy route.

## Scripts

Each task is a script in the repository. Run them from any directory.

| Script | Description |
| --- | --- |
| `scripts/install.sh <profile>` | Records the machine's profile in `~/.config/dotfiles/profile`, then installs its packages, links the dotfiles, configures fish, and starts the Process Compose service on Linux. Without a profile name, it uses the recorded profile. Safe to rerun. |
| `scripts/sync.sh` | Fast-forwards the current branch, then links the dotfiles. |
| `scripts/agents.sh sync\|update` | Deploys `agents/` with APM. The `agents:sync` and `agents:update` targets below run it. |
| `scripts/agents-env.sh` | Fills `~/.config/agents/env` from 1Password. Rerun it to pick up rotated keys. |
| `scripts/link.sh` | Backs up existing target files and links the `home/` folder of each role in the profile into `$HOME` with GNU Stow. |
| `scripts/package.sh install` | Installs every tracked package for the current platform. |
| `scripts/package.sh add <name> [apt\|brew\|cask\|npm] [--role <role>]` | Installs and records a package in a role of the profile, `base` by default. Defaults to APT on Ubuntu and a Homebrew formula on macOS. `npm` records a global npm tool for both platforms. |
| `scripts/package.sh remove <name>` | Removes a package from its manifest, then offers to uninstall APT, Homebrew, and npm packages. Upstream tools require manual uninstallation. |
| `scripts/package.sh update [name]` | Updates one tracked package or all packages for the current platform. |
| `scripts/package.sh list` | Lists the profile's tracked packages for the current platform by source. |

`scripts/sync.sh` stops before it changes `$HOME` if `git pull --no-rebase --ff-only` fails. Every command except `scripts/install.sh <profile>` stops with an error until the machine has a recorded profile.

Machine tasks live in `roles/base/home/Makefile`, which Stow links to `~/Makefile`. Run `make <target>` from `~`, or `make -C ~ <target>` from any directory.

| Target | Description |
| --- | --- |
| `agents:sync` | Copies `agents/apm.yml` and `agents/apm.lock.yaml` into `~/.apm`, then installs, prunes, and compiles the agent setup at user scope with APM. Copies the lock back if APM changed it. Rerun it after each change to a skill or instruction. |
| `agents:update` | Does the same with `apm update`, which moves every agent package to the latest commit on its branch. |

## Profiles and roles

A profile in `profiles/<name>.txt` lists roles, one per line, starting with `base`. Today both profiles run only `base`:

| Profile | Machine |
| --- | --- |
| `server` | An Ubuntu server or VPS. |
| `mac` | A macOS workstation. |

A role in `roles/<role>/` may hold these entries, and nothing else:

| Entry | Contents |
| --- | --- |
| `home/` | Files that GNU Stow links into `$HOME`. Stow links each file into real directories, so several roles can add files to one directory. Two roles can't link the same file. |
| `packages/apt.txt` | Ubuntu APT packages, one per line. |
| `packages/extras.txt` | Upstream tools for Ubuntu, one per line. |
| `packages/Brewfile` | Homebrew formulae and casks for macOS. |
| `packages/npm.txt` | Global npm tools for both platforms, one per line. They install into `~/.npm-global`. |

Run `bash tests/roles.sh` to check that the profiles and roles follow these rules.

`scripts/link.sh` removes links into the repository that no longer point at a role's file, and links of roles the profile no longer lists. Machines linked before roles existed record the profile their OS implied, `server` on Linux and `mac` on macOS, on their next sync. It also points each systemd boot link in `~/.config/systemd/user/*.wants/` that targets the repository at the unit's link in `~/.config/systemd/user/`, so a unit stays enabled when its file moves between roles.

## Repository layout

The main paths are:

| Path | Contents |
| --- | --- |
| `scripts/*.sh` | The commands in the table above. They only load modules and call them. |
| `scripts/lib/` | Modules: files that define functions and run nothing when loaded. |
| `scripts/lib/core.sh` | Repository paths, `PATH`, and output helpers. Every module loads it. |
| `scripts/lib/profile.sh` | Reads the machine's profile and finds its roles' manifests. |
| `scripts/lib/home.sh` | Backs up conflicts and links each role's `home/` with GNU Stow. |
| `scripts/lib/fish.sh`, `scripts/lib/process-compose.sh`, `scripts/lib/agents-env.sh`, `scripts/lib/agents.sh` | Machine setup steps. |
| `scripts/lib/packages/` | `packages.sh` picks `linux.sh` or `macos.sh`, then runs `npm.sh` for global npm tools. `linux.sh` uses `extras.sh` for upstream tools, which uses `github-release.sh`, `opencode.sh`, and `node.sh`. `macos.sh` also uses `node.sh`, which installs Node through fnm. |
| `tests/` | Checks for the scripts and the installed tools. |
| `profiles/` | The roles each kind of machine runs. |
| `roles/` | Each role's linked files and package manifests. |
| `agents/` | The APM manifest and lock for the global agent setup. The agent sync copies them into `~/.apm`. |
| `backups/` | Files moved out of the way during a sync. |
| `docs/` | Setup and maintenance guides. |

Dependencies point one way: `tests/` → `scripts/*.sh` → `scripts/lib/` modules → `scripts/lib/core.sh`. A module loads only `core.sh` and modules below it in the list above; it never loads a command or a module that depends on it. `profile.sh` loads only `core.sh`, and every other module may load it. `profiles/`, `roles/*/packages/`, and `agents/` hold data only.

## Local configuration

Linux installation currently supports Ubuntu. APT manages OS dependencies and build tools. Git uses the Git maintainers' PPA; the 1Password CLI uses its official APT repository. Developer tools use the latest stable upstream releases, rather than Ubuntu's older versions. fnm manages Node, and npm installs pnpm. Codex uses OpenAI's standalone installer. Ghostty remains macOS-only in the manifests.

`scripts/package.sh update` updates every tracked tool to the latest stable release from its configured source. On both platforms, Node selects the newest stable release, excludes prereleases, and becomes the fnm default. Existing Node versions and project-specific version files remain available. `scripts/install.sh` resolves the latest GitHub releases and skips other upstream installers when their tools are already present. Atuin must be at least 18.23.0 to read the history database migrated by the previous Linuxbrew installation.

GitHub release binaries live under `~/.local/share/dot-tools/<tool>/<version>` and are linked into `~/.local/bin`. Neovim's runtime files stay alongside its binary. Bubblewrap is built from its upstream release; GNU Stow is built from its latest published tarball. Updates preserve prior version directories. Run `bash tests/packages.sh` and `bash tests/upstream-packages.sh` to check package-command behavior and upstream updates without changing installed packages, and `bash tests/installed-tools.sh` from a fresh fish session to check the installed tools.

To track another upstream tool, add its installer to `scripts/lib/packages/extras.sh` and its name to a role's `packages/extras.txt`. `scripts/package.sh add` on Linux handles APT packages only. The manifests track intended packages, not their transitive dependencies or exact versions.

Fish is the default interactive shell. `scripts/install.sh` installs fish, registers it in `/etc/shells`, and selects it as the account's login shell.

Codex completions are generated from the installed CLI when fish loads them, so
they follow CLI updates automatically.

Tmux and its plugins are no longer configured by this repository. After syncing
an existing installation, remove dangling `~/.tmux.conf` and
`~/.config/tmux/tmux.conf` symlinks left by the previous configuration.

`roles/base/home/.config/fish/conf.d/99-local.fish` loads `~/.config/fish/conf.d/99-local.private.fish` when the file exists. The repository does not track `99-local.private.fish`.

## Agent environment

Agents don't load interactive shell config, so variables they need, such as the `upload` skill's `FILE_UPLOAD_*` settings, live in `~/.config/agents/env`. Every reader loads that file:

- `~/.zshenv` loads it for every zsh, including the non-interactive shells that agents run on macOS.
- `roles/base/home/.config/fish/conf.d/00-env.fish` loads it for fish.
- Drop-ins in `roles/base/home/.config/systemd/user/` load it into `t3code.service` and `opencode-web.service` on Linux.

`roles/base/home/.config/agents/env.tpl` holds only `op://` references. `scripts/agents-env.sh` fills it with the machine's read-only 1Password service account, whose token lives at `~/.config/agents/1password-token` with mode `600`. The script passes the token to that one `op` call, never exports it, and writes the env file with mode `600`. If 1Password fails or a value contains characters that systemd and the shells would read differently, the script keeps the existing file. `scripts/install.sh` runs this step when the token file exists.

To add a variable, add a line to the template and its value to the `Agents` vault, then rerun `scripts/agents-env.sh`. The script restarts `opencode-web.service` when its running process lacks a current value. It only reports when `t3code.service` needs a restart, because restarting T3 ends the sessions it runs. After that restart, start new agent sessions. `scripts/link.sh` creates `~/.config/agents` as a real directory so Stow never links it into the repository, and the script refuses to write if an older link already does. Run `bash tests/agents-env.sh` to check the setup and loaders without 1Password.

## Scheduled sync

Process Compose reads `roles/base/home/.config/process-compose/process-compose.yaml`. The `dotfiles-sync` process runs `scripts/sync.sh` every 15 minutes and permits one run at a time.

On Linux, `scripts/install.sh` enables `roles/base/home/.config/systemd/user/process-compose.service` on port `10080`. The `pc` shell alias attaches to the Process Compose TUI. In the TUI, `F9` pauses the process and `F7` resumes it.
