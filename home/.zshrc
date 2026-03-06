# Aliases
alias c="opencode"
alias pn="pnpm"
alias t='tmux attach || tmux new -s Work'
alias z="zed"
alias zshrc="c ~/.zshrc"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias d="docker"
alias decompress="tar -xzf"
alias g="git"
alias gcm="git commit -m"
alias gcam="git commit -a -m"
alias gcad="git commit -a --amend"

if command -v eza >/dev/null 2>&1; then
  alias ls="eza --group-directories-first --icons=auto"
  alias l="eza -lh --group-directories-first --icons=auto"
  alias la="eza -a --group-directories-first --icons=auto"
  alias ll="eza -lha --group-directories-first --icons=auto"
  alias lsa="eza -a --group-directories-first --icons=auto"
  alias lt="eza --tree --level=2 --long --icons --git"
  alias lta="eza --tree --level=2 --long --icons --git -a"
else
  alias l="ls -l"
  alias la="ls -a"
  alias ll="ls -la"
  alias ls="ls -G"
fi

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
