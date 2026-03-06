# Fish completions for opencode (yargs-based CLI)
function __fish_opencode_get_completions
    set -l tokens (commandline -opc)
    set -l current (commandline -ct)
    opencode --get-yargs-completions $tokens $current 2>/dev/null
end

complete -c opencode -f -a '(__fish_opencode_get_completions)'
