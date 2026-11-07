# The host declares one ordered runtime for shells and services.
set -l runtime_paths
while read -l entry
    test -n "$entry"; and set -a runtime_paths $entry
end < "$HOME/.config/agents/runtime.path"
set -gx PATH $runtime_paths
set -eg CODEX_HOME
set -eU CODEX_HOME
if test -d /Applications/Obsidian.app/Contents/MacOS
    set -a PATH /Applications/Obsidian.app/Contents/MacOS
end
