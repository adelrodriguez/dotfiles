function c
    opencode $argv
end

function t
    tmux attach
    or tmux new -s Work
end

function jqc
    jq -C $argv
end

function jqf
    jq -C . "$argv[1]" | less -R
end

function obsidian
    Obsidian $argv
end

if status is-interactive
    if type -q eza
        abbr -a ls "eza --group-directories-first --icons=auto"
        abbr -a l "eza -lh --group-directories-first --icons=auto"
        abbr -a la "eza -a --group-directories-first --icons=auto"
        abbr -a ll "eza -lha --group-directories-first --icons=auto"
        abbr -a lsa "eza -a --group-directories-first --icons=auto"
        abbr -a lt "eza --tree --level=2 --long --icons --git"
        abbr -a lta "eza --tree --level=2 --long --icons --git -a"
    else
        abbr -a l "ls -l"
        abbr -a la "ls -a"
        abbr -a ll "ls -la"
        abbr -a ls "ls -G"
    end

    abbr -a pn pnpm
    abbr -a .. "cd .."
    abbr -a ... "cd ../.."
    abbr -a .... "cd ../../.."
    abbr -a d docker
    abbr -a decompress "tar -xzf"
    abbr -a g git
    abbr -a gcm "git commit -m"
    abbr -a gcam "git commit -a -m"
    abbr -a gcad "git commit -a --amend"
    abbr -a z zed
    abbr -a zshrc "c ~/.zshrc"
end

# Ubuntu-specific aliases (bat -> batcat, fd -> fdfind)
if type -q batcat
    alias bat "batcat"
end

if type -q fdfind
    alias fd "fdfind"
end
