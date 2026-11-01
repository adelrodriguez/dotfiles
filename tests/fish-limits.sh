#!/usr/bin/env bash
# Exercise the macOS startup branch with real limits in isolated child shells.
# A child cannot raise its inherited hard limit, so cases above it are skipped.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
snippet="$repo/roles/base/home/.config/fish/conf.d/05-limits.fish"
inherited="$(ulimit -Hn)"

check() {
    local platform="$1" soft="$2" hard="$3" expected="$4" actual
    if [[ "$inherited" != unlimited ]] && (( hard > inherited )); then
        echo "skip $platform: $soft/$hard needs a hard limit above $inherited"
        return
    fi
    if ! actual="$(
        ulimit -Sn "$soft" && ulimit -Hn "$hard" &&
            TEST_OS="$platform" fish --no-config -c '
                function uname; echo $TEST_OS; end
                source $argv[1]
                printf "%s %s\n" (ulimit -Sn) (ulimit -Hn)
            ' -- "$snippet" 2>&1
    )" || [[ "$actual" != "$expected $hard" ]]; then
        echo "$platform: $soft/$hard -> $actual, want $expected/$hard" >&2
        exit 1
    fi
    echo "$platform: $soft/$hard -> $expected/$hard"
}

check Darwin 256 131072 65536
check Darwin 256 32768 32768
check Darwin 65536 131072 65536
check Darwin 131072 131072 131072
check Linux 256 131072 256
