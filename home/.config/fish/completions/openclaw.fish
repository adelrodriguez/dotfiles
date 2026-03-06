set -l openclaw_completion_file

for candidate in \
    "$HOME/.openclaw/completions/openclaw.fish" \
    "$HOME/.config/openclaw/completions/openclaw.fish"
    if test -f $candidate
        set openclaw_completion_file $candidate
        break
    end
end

if test -n "$openclaw_completion_file"
    source $openclaw_completion_file
end
