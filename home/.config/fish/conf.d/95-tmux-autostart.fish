if status is-interactive; and not set -q TMUX; and not set -q SSH_TTY; and command -q tmux
    if tmux ls >/dev/null 2>&1
        tmux attach
    else
        tmux new -s main
    end
end
