if type -q starship
    starship init fish | source
else if test -x /opt/homebrew/bin/starship
    /opt/homebrew/bin/starship init fish | source
end
