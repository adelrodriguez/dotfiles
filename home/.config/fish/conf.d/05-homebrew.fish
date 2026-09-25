if test (uname) != Darwin
    # Clean inherited paths in existing tmux sessions as well as new logins.
    set -gx PATH (string match -rv '(^/home/linuxbrew/|/\.linuxbrew/)' -- $PATH)
    return
end

for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew
    if test -x $brew_bin
        eval ($brew_bin shellenv fish)
        break
    end
end
