set -l normalized_completion_paths

# fish_complete_path must stay unexported; exported list variables are inherited
# by child shells as a single space-delimited string, which breaks autoloading.
for completion_path in $fish_complete_path
    if test -d "$completion_path"
        set -a normalized_completion_paths $completion_path
    else if string match -q "* *" -- $completion_path
        for split_path in (string split ' ' -- $completion_path)
            if test -d "$split_path"
                set -a normalized_completion_paths $split_path
            end
        end
    end
end

if test (count $normalized_completion_paths) -gt 0
    set -g --unexport fish_complete_path $normalized_completion_paths
end

for brew_completions in \
    /opt/homebrew/share/fish/vendor_completions.d \
    /usr/local/share/fish/vendor_completions.d \
    /home/linuxbrew/.linuxbrew/share/fish/vendor_completions.d \
    $HOME/.linuxbrew/share/fish/vendor_completions.d
    if test -d $brew_completions
        if not contains -- $brew_completions $fish_complete_path
            set -g --unexport fish_complete_path $fish_complete_path $brew_completions
        end
    end
end
