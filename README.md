<div align="center">
  <h1 align="center">🧰 dotfiles</h1>
  <p align="center">
    <strong>Shell + tool config, symlinked into $HOME.</strong>
  </p>
</div>

## Quick start
```sh
ln -s "$HOME/Developer/dotfiles/zsh/.zshrc" "$HOME/.zshrc"
ln -s "$HOME/Developer/dotfiles/git/.gitconfig" "$HOME/.gitconfig"
ln -s "$HOME/Developer/dotfiles/config/atuin/config.toml" "$HOME/.config/atuin/config.toml"
ln -s "$HOME/Developer/dotfiles/config/direnv/direnv.toml" "$HOME/.config/direnv/direnv.toml"
ln -s "$HOME/Developer/dotfiles/config/bat/config" "$HOME/.config/bat/config"
ln -s "$HOME/Developer/dotfiles/rg/ripgreprc" "$HOME/.ripgreprc"
ln -s "$HOME/Developer/dotfiles/fd/ignore" "$HOME/.config/fd/ignore"
```

## Layout
- `zsh/.zshrc`
- `zsh/bindings.zsh`
- `git/.gitconfig`
- `config/atuin/config.toml`
- `config/direnv/direnv.toml`
- `config/bat/config`
- `rg/ripgreprc`
- `fd/ignore`

## Local-only overrides
Put machine-specific or sensitive items in `~/.zshrc.local`.
`~/.zshrc` sources it if present.

## Tools
Install via Homebrew: atuin, fzf, rg, fd, bat, delta, jq, direnv.
