set -l orbstack_completions /Applications/OrbStack.app/Contents/Resources/completions/fish

if test -d $orbstack_completions
    if not contains -- $orbstack_completions $fish_complete_path
        set -g --unexport fish_complete_path $fish_complete_path $orbstack_completions
    end
end
