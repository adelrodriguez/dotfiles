# fnm owns project versions. Nix owns the default Node outside projects.
if type -q fnm
    fnm env --shell fish | source
    function __dotfiles_node --on-variable PWD
        set -l directory $PWD
        while test $directory != /
            if test -f "$directory/.node-version"; or test -f "$directory/.nvmrc"
                fnm use --silent-if-unchanged --version-file-strategy recursive
                return $status
            end
            set directory (path dirname $directory)
        end
        # A version file avoids interpreting system as a path in the current directory.
        fnm use --silent-if-unchanged (printf 'system\n' | psub)
    end
    __dotfiles_node
end
