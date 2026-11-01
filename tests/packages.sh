#!/usr/bin/env bash
# Exercise package commands in an isolated home with APT replaced by a recorder.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
export CALLS="$tmp/calls"
mkdir -p "$HOME/.local/bin" "$tmp/repo/packages/linux"
cp -R "$repo/scripts" "$tmp/repo/scripts"
cp "$repo/packages/linux/"{apt.txt,extras.txt} "$tmp/repo/packages/linux/"
cp "$repo/packages/npm.txt" "$tmp/repo/packages/npm.txt"
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
cat > "$HOME/.local/bin/npm" <<'SH'
#!/bin/bash
printf 'npm %s\n' "$*" >> "$CALLS"
SH
chmod +x "$HOME/.local/bin/"{sudo,brew,npm}
pkg="$tmp/repo/scripts/package.sh"
bash "$pkg" list > "$tmp/list"
grep -q '^upstream:' "$tmp/list"
grep -q '^npm:' "$tmp/list"
bash "$pkg" add hello
bash "$pkg" add hello
[[ "$(grep -cx hello "$tmp/repo/packages/linux/apt.txt")" == 1 ]]
grep -qx 'apt-get install -y hello' "$CALLS"
bash "$pkg" update hello
if APT_EXIT=1 bash "$pkg" add failed-package; then exit 1; fi
if grep -qx failed-package "$tmp/repo/packages/linux/apt.txt"; then exit 1; fi
printf 'n\n' | bash "$pkg" remove hello
if grep -qx hello "$tmp/repo/packages/linux/apt.txt"; then exit 1; fi
if grep -q 'apt-get remove' "$CALLS"; then exit 1; fi
bash "$pkg" remove zoxide
if grep -qx zoxide "$tmp/repo/packages/linux/extras.txt"; then exit 1; fi
bash "$pkg" add @scope/tool npm
bash "$pkg" add @scope/tool npm
[[ "$(grep -cx @scope/tool "$tmp/repo/packages/npm.txt")" == 1 ]]
grep -qx 'npm install --global @scope/tool' "$CALLS"
bash "$pkg" update @scope/tool
grep -qx 'npm install --global @scope/tool@latest' "$CALLS"
printf 'n\n' | bash "$pkg" remove @scope/tool
if grep -qx @scope/tool "$tmp/repo/packages/npm.txt"; then exit 1; fi
if grep -q 'npm uninstall' "$CALLS"; then exit 1; fi
if bash "$pkg" add '../bad' npm; then exit 1; fi
if bash "$pkg" update untracked-package; then exit 1; fi
if bash "$pkg" remove '../bad'; then exit 1; fi
if bash "$pkg" add hello brew; then exit 1; fi
printf 'Package command checks passed\n'
