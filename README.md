# Dotfiles

Purpose: keep shell + tool config in one repo, symlink into $HOME.

## Layout
- zsh/.zshrc
- zsh/bindings.zsh
- git/.gitconfig
- config/atuin/config.toml
- config/direnv/direnv.toml
- config/bat/config
- rg/ripgreprc
- fd/ignore

## Local-only overrides
Put machine-specific or sensitive items in ~/.zshrc.local.
.zshrc sources it if present.

## Symlinks (example)
ln -s ~/Developer/dotfiles/zsh/.zshrc ~/.zshrc
ln -s ~/Developer/dotfiles/git/.gitconfig ~/.gitconfig
ln -s ~/Developer/dotfiles/config/atuin/config.toml ~/.config/atuin/config.toml
ln -s ~/Developer/dotfiles/config/direnv/direnv.toml ~/.config/direnv/direnv.toml
ln -s ~/Developer/dotfiles/config/bat/config ~/.config/bat/config
ln -s ~/Developer/dotfiles/rg/ripgreprc ~/.ripgreprc
ln -s ~/Developer/dotfiles/fd/ignore ~/.config/fd/ignore

## Notes
Install tools via Homebrew (atuin, fzf, rg, fd, bat, delta, jq, direnv).
