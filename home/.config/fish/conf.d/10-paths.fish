if test -d "$HOME/.local/share/fnm"
    fish_add_path "$HOME/.local/share/fnm"
end

if test -d "$HOME/.opencode/bin"
    fish_add_path "$HOME/.opencode/bin"
end

if test -d "$HOME/.npm-global/bin"
    fish_add_path "$HOME/.npm-global/bin"
end

if test -d "$HOME/.bun/bin"
    fish_add_path "$HOME/.bun/bin"
end

if test -d "$HOME/.cargo/bin"
    fish_add_path "$HOME/.cargo/bin"
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
