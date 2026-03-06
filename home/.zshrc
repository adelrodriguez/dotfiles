# Aliases
alias c="open $1 -a \"Cursor\"" # Open Cursor with the given argument
alias pn="pnpm"
alias l="ls -l"
alias la="ls -a"
alias ll="ls -la"
alias ls="ls -G"
alias z="zed"
alias zshrc="c ~/.zshrc"

fpath=(
  "$HOME/.config/zsh-completions/src"
  /opt/homebrew/share/zsh/site-functions
  $fpath
)

# Initialize completions
autoload -Uz compinit bashcompinit
compinit -i
bashcompinit

# Better completion experience
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

export EDITOR="nvim"

# fnm shell setup
eval "$(fnm env --use-on-cd --shell zsh)"

# # Open a tmux session on startupe
# if command -v tmux &>/dev/null && [ -z "$TMUX" ]; then
#   tmux attach -t default || tmux new -s default
# fi

source "$HOME/.config/zsh/bindings.zsh"

# Starship
eval "$(starship init zsh)"
eval "$(zoxide init --cmd cd zsh)"

[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
