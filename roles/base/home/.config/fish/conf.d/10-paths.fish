# Shells and services read the same ordered tool paths.
set -l runtime_paths
set -l platform (uname)
while read -l entry
    test -n "$entry"; or continue
    if test $platform = Linux; and string match -q '/opt/homebrew/*' -- $entry
        continue
    end
    if not string match -q '/*' -- $entry
        set entry "$HOME/$entry"
    end
    set -a runtime_paths $entry
end < "$HOME/.config/agents/runtime.path"
fish_add_path --path --move $runtime_paths

if test -d /Applications/Obsidian.app/Contents/MacOS
    fish_add_path --path /Applications/Obsidian.app/Contents/MacOS
end
