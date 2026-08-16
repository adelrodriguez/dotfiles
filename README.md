<div align="center">
  <h1 align="center">🧰 dotfiles</h1>
  <p align="center">
    <strong>Shell + tool config, symlinked into $HOME.</strong>
  </p>
</div>

## Quick start
```sh
git clone https://github.com/adelrodriguez/dotfiles.git ~/Developer/dotfiles
cd ~/Developer/dotfiles
./install.sh
dot init
```

## Commands
- `dot init` installs brew deps, syncs dotfiles and global agent skills, sets fish as default, and updates fisher plugins
- `dot sync` runs GNU Stow with backups, exposes `agents/skills/` as the global skill store, and links those skills into detected agent harnesses
- `dot package add|remove|update|list` manages `packages/bundle`

## Layout
- `home/.zshrc`
- `agents/skills/`
- `home/.config/zsh/bindings.zsh`
- `home/.gitconfig`
- `home/.ripgreprc`
- `home/.tmux.conf`
- `home/.config/atuin/config.toml`
- `home/.config/direnv/direnv.toml`
- `home/.config/bat/config`
- `home/.config/fd/ignore`
- `home/.config/fish/`
- `home/.config/ghostty/config`
- `home/.config/starship.toml`
- `home/.local/bin/`

## Local-only overrides
Put machine-specific or sensitive items in `~/.zshrc.local`.
`~/.zshrc` sources it if present.

## Agent skills
GNU Stow folds `agents/skills/` onto `~/.agents/skills`, so global Skills CLI installs and updates are written directly into this repository. Add skills from their remote source, then review and commit the resulting changes:

```sh
npx skills add owner/repo -g -a opencode codex claude-code -s skill-name -y
```

Do not install from the local `agents/skills/` path because it is the canonical global destination.

Create a personal skill directly in the canonical store:

```sh
mkdir -p ~/dotfiles/agents/skills/my-skill
$EDITOR ~/dotfiles/agents/skills/my-skill/SKILL.md
dot sync
```

Each skill needs YAML frontmatter with at least `name` and `description`. Commit the new directory to share it across machines.

## Tools
Install via Homebrew Brewfile: `packages/bundle`.
