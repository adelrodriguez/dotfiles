if type -q fzf
    if type -q fd
        set -gx FZF_DEFAULT_COMMAND 'fd --hidden --exclude .git --type f'
        set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
        set -gx FZF_ALT_C_COMMAND 'fd --hidden --exclude .git --type d'
    else if type -q rg
        set -gx FZF_DEFAULT_COMMAND 'rg --files --hidden --glob "!.git/*"'
        set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
    end

    set -gx FZF_DEFAULT_OPTS "$FZF_DEFAULT_OPTS --height=40% --layout=reverse --border"

    set -l fzf_preview 'if command -v git >/dev/null 2>&1 && git -C . rev-parse --is-inside-work-tree >/dev/null 2>&1; then if git -C . ls-files --error-unmatch "{}" >/dev/null 2>&1; then if command -v delta >/dev/null 2>&1; then git -C . diff --color=always -- "{}" | delta; else git -C . diff --color=always -- "{}"; fi; exit 0; fi; fi; if command -v bat >/dev/null 2>&1; then bat --style=numbers --color=always --line-range :200 "{}"; else sed -n "1,200p" "{}"; fi'
    set -gx FZF_CTRL_T_OPTS "$FZF_CTRL_T_OPTS --preview='$fzf_preview' --preview-window=right:60%:wrap"
end
