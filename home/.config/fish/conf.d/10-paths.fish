if test -d "$HOME/.bun/bin"
    fish_add_path "$HOME/.bun/bin"
end

if test -d "$HOME/.local/bin"
    fish_add_path "$HOME/.local/bin"
end

if test -d /Applications/Obsidian.app/Contents/MacOS
    fish_add_path /Applications/Obsidian.app/Contents/MacOS
end

if test -d "$HOME/.atuin/bin"
    fish_add_path "$HOME/.atuin/bin"
end
