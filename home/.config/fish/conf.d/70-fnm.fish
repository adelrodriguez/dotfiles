set -gx PATH (string match -rv -- '.*/fnm_multishells/.*/bin/?$' $PATH)

if type -q fnm
    fnm env --use-on-cd --shell fish | source
end
