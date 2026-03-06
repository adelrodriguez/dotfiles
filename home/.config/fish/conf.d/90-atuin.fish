if type -q atuin
    set -gx ATUIN_SYNC_ENABLE false
    atuin init fish | source
end
