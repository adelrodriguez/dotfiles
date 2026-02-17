set -l brew_completions /opt/homebrew/share/fish/vendor_completions.d
if test -d $brew_completions
    if not contains -- $brew_completions $fish_complete_path
        set -gx fish_complete_path $fish_complete_path $brew_completions
    end
end
