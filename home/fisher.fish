# Read only the files registered to plugins this repository previously installed.
for plugin in patrickf1/fzf.fish franciscolourenco/done laughedelic/pisces nyarly/fish-bang-bang jorgebucaran/fisher
    set -l variable _fisher_(string escape --style=var -- $plugin)_files
    if set -q $variable
        printf '%s\0' $$variable
    end
end
