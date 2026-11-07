#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/docs" "$tmp/add" "$tmp/list"
env COMPLETION_FILE="$repo/config/fish/completions/grok.fish" FIXTURE="$tmp" fish --no-config -c '
    source "$COMPLETION_FILE"
    cd "$FIXTURE"
    set -l actions (string split -f 1 \t -- (complete -C "grok worktree redirect "))
    for action in list add del fixup unmount help
        contains -- $action $actions; or exit 1
    end
    # Option values that match an action name do not count as the selected action.
    for prefix in "--cwd add" "--add-dir list"
        set -l actions (string split -f 1 \t -- (complete -C "grok $prefix worktree redirect "))
        for action in list add del fixup unmount help
            contains -- $action $actions; or exit 1
        end
    end
    for action in add del
        set -l arguments (string split -f 1 \t -- (complete -C "grok worktree redirect $action "))
        for other_action in list add del fixup unmount help
            if contains -- $other_action $arguments
                echo "Redirect actions leaked into arguments after $action" >&2
                exit 1
            end
        end
        set -l paths (string split -f 1 \t -- (complete -C "grok worktree redirect $action doc"))
        contains -- docs/ $paths; or exit 1
    end
'
printf 'Grok redirect completes actions before selection and paths afterward\n'
