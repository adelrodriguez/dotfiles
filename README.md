<div align="center">
  <h1 align="center">🧰 dotfiles</h1>
  <p align="center">
    <strong>Shell + tool config, symlinked into $HOME.</strong>
  </p>
</div>

## Quick start
```sh
brew bundle --file packages/bundle
stow -t ~ home
```

## Layout
- `home/.zshrc`
- `home/.config/zsh/bindings.zsh`
- `home/.gitconfig`
- `home/.ripgreprc`
- `home/.config/atuin/config.toml`
- `home/.config/direnv/direnv.toml`
- `home/.config/bat/config`
- `home/.config/fd/ignore`
- `home/.config/fish/`
- `home/.config/starship.toml`
- `home/.local/bin/`

## Local-only overrides
Put machine-specific or sensitive items in `~/.zshrc.local`.
`~/.zshrc` sources it if present.

## Tools
Install via Homebrew Brewfile: `packages/bundle`.
