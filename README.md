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
- `dot init` installs brew deps, syncs dotfiles, sets fish as default, and updates fisher plugins
- `dot sync` runs GNU Stow with backups
- `dot package add|remove|update|list` manages `packages/bundle`

## Layout
- `home/.zshrc`
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

## Tools
Install via Homebrew Brewfile: `packages/bundle`.
