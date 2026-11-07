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
        fnm use --silent-if-unchanged system
    end
    __dotfiles_node
end
