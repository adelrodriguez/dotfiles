if command -v fzf >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --hidden --exclude .git --type f'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --hidden --exclude .git --type d'
  export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+$FZF_DEFAULT_OPTS }--height=40% --layout=reverse --border"

  if command -v bat >/dev/null 2>&1; then
    export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --preview='bat --style=numbers --color=always --line-range :200 {}'"
  fi

  if [[ -r "/opt/homebrew/opt/fzf/shell/completion.zsh" ]]; then
    source "/opt/homebrew/opt/fzf/shell/completion.zsh"
  fi

  if [[ -r "/opt/homebrew/opt/fzf/shell/key-bindings.zsh" ]]; then
    source "/opt/homebrew/opt/fzf/shell/key-bindings.zsh"
  fi
fi

if command -v atuin >/dev/null 2>&1; then
  export ATUIN_SYNC_ENABLE=false
  eval "$(atuin init zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

alias fd="fd --hidden --exclude .git"
alias jqc="jq -C"

jqf() {
  jq -C . "$1" | less -R
}
