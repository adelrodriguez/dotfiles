#!/usr/bin/env bash
# Exercise package commands in an isolated home with APT replaced by a recorder.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
export CALLS="$tmp/calls"
mkdir -p "$HOME/.local/bin" "$tmp/repo/packages/linux"
cp "$repo/dot" "$tmp/repo/dot"
cp "$repo/packages/linux/"{manage.sh,apt.txt,extras.txt} "$tmp/repo/packages/linux/"
cat > "$HOME/.local/bin/sudo" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >> "$CALLS"
exit "${APT_EXIT:-0}"
SH
cat > "$HOME/.local/bin/brew" <<'SH'
#!/bin/bash
echo 'Linux must not invoke brew' >&2
exit 99
SH
chmod +x "$HOME/.local/bin/"{sudo,brew}
dot="$tmp/repo/dot"
bash "$dot" package list > "$tmp/list"
grep -q '^upstream:' "$tmp/list"
bash "$dot" package add hello
bash "$dot" package add hello
[[ "$(grep -cx hello "$tmp/repo/packages/linux/apt.txt")" == 1 ]]
grep -qx 'apt-get install -y hello' "$CALLS"
bash "$dot" package update hello
if APT_EXIT=1 bash "$dot" package add failed-package; then exit 1; fi
if grep -qx failed-package "$tmp/repo/packages/linux/apt.txt"; then exit 1; fi
printf 'n\n' | bash "$dot" package remove hello
if grep -qx hello "$tmp/repo/packages/linux/apt.txt"; then exit 1; fi
if grep -q 'apt-get remove' "$CALLS"; then exit 1; fi
bash "$dot" package remove vercel
if grep -qx vercel "$tmp/repo/packages/linux/extras.txt"; then exit 1; fi
if bash "$dot" package update untracked-package; then exit 1; fi
if bash "$dot" package remove '../bad'; then exit 1; fi
if bash "$dot" package add hello brew; then exit 1; fi
printf 'Package command checks passed\n'
