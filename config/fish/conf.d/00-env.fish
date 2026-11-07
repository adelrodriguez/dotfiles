set -gx EDITOR nvim

# Variables for agents, written by scripts/agents-env.sh.
if test -r "$HOME/.config/agents/env"
    while read -l line
        string match -qr '^[A-Za-z_][A-Za-z0-9_]*=' -- $line; or continue
        set -l pair (string split -m 1 = -- $line)
        set -gx $pair[1] $pair[2]
    end <"$HOME/.config/agents/env"
end
