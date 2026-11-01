#!/usr/bin/env bash
# Exercise the home Makefile's agents-sync target in an isolated home with dotagents and apm replaced by stubs.
set -euo pipefail
source_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"
mkdir -p "$repo"
cp -R "$source_repo/scripts" "$source_repo/home" "$repo/"
stow="$(command -v stow)"
export HOME="$tmp/home"
export CALLS="$tmp/calls"
# A PATH of system directories and stubs keeps the machine's apm out of the test.
mkdir -p "$HOME/bin"
ln -s "$stow" "$HOME/bin/stow"
export PATH="$HOME/bin:/usr/bin:/bin"

# Linking moves an existing ~/Makefile to backups/ and links the tracked one.
printf 'old:\n' > "$HOME/Makefile"
bash "$repo/scripts/link.sh" >/dev/null
[[ -L "$HOME/Makefile" && "$(readlink -f "$HOME/Makefile")" == "$repo/home/Makefile" ]]
grep -qx 'old:' "$repo"/backups/*/Makefile

sync() { make --no-print-directory "$@" agents-sync; }

# Without dotagents, the target fails with a clear message.
if sync -C "$HOME" 2>"$tmp/err"; then exit 1; fi
grep -q 'dotagents is not cloned at' "$tmp/err"

# The stub dotagents Makefile records its sync and fails when SYNC_MODE=fail.
mkdir -p "$HOME/.apm"
printf 'sync:\n\techo sync >> "$$CALLS"\n\ttest "$$SYNC_MODE" != fail\n' > "$HOME/.apm/Makefile"

# Without apm, the target fails with a clear message before it syncs.
if sync -C "$HOME" 2>"$tmp/err"; then exit 1; fi
grep -q 'the apm command is not installed' "$tmp/err"
[[ ! -e "$CALLS" ]]

printf '#!/bin/sh\n' > "$HOME/bin/apm"
chmod +x "$HOME/bin/apm"

# Both entry points run the dotagents sync.
(cd "$HOME" && sync) >/dev/null
(cd "$tmp" && sync -C "$HOME") >/dev/null
[[ "$(grep -c '^sync$' "$CALLS")" == 2 ]]

# A failing sync fails the target.
if SYNC_MODE=fail sync -C "$HOME" >/dev/null 2>&1; then exit 1; fi

echo "agents-sync checks passed"
