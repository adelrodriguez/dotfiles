if command -v fzf >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --hidden --exclude .git --type f'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --hidden --exclude .git --type d'
  export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+$FZF_DEFAULT_OPTS }--height=40% --layout=reverse --border"

  FZF_FILE_PREVIEW='if command -v git >/dev/null 2>&1 && git -C . rev-parse --is-inside-work-tree >/dev/null 2>&1; then if git -C . ls-files --error-unmatch "{}" >/dev/null 2>&1; then if command -v delta >/dev/null 2>&1; then git -C . diff --color=always -- "{}" | delta; else git -C . diff --color=always -- "{}"; fi; exit 0; fi; fi; if command -v bat >/dev/null 2>&1; then bat --style=numbers --color=always --line-range :200 "{}"; else sed -n "1,200p" "{}"; fi'
  export FZF_CTRL_T_OPTS="${FZF_CTRL_T_OPTS:+$FZF_CTRL_T_OPTS }--preview='$FZF_FILE_PREVIEW' --preview-window=right:60%:wrap"

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
