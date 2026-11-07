# Homebrew initializes login shells before the shared paths take precedence again.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
[[ ! -r "$HOME/.orbstack/shell/init.zsh" ]] || source "$HOME/.orbstack/shell/init.zsh"
source "$HOME/.config/zsh/env.zsh"
