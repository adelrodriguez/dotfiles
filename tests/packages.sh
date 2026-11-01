#!/usr/bin/env bash
# Exercise package commands in an isolated home with APT replaced by a recorder.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
export CALLS="$tmp/calls"
mkdir -p "$HOME/.local/bin" "$HOME/.config/dotfiles" "$tmp/repo/roles/base/packages" "$tmp/repo/roles/extra" "$tmp/repo/profiles"
cp -R "$repo/scripts" "$tmp/repo/scripts"
cp "$repo/roles/base/packages/"{apt.txt,extras.txt,npm.txt} "$tmp/repo/roles/base/packages/"
printf 'base\n' > "$tmp/repo/profiles/server.txt"
printf 'base\nextra\n' > "$tmp/repo/profiles/both.txt"
base="$tmp/repo/roles/base/packages"
extra="$tmp/repo/roles/extra/packages"
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
# Without a recorded profile, package commands stop before they change anything.
if bash "$pkg" list 2>"$tmp/err"; then exit 1; fi
grep -q 'No profile recorded' "$tmp/err"
printf 'server\n' > "$HOME/.config/dotfiles/profile"
bash "$pkg" list > "$tmp/list"
grep -q '^upstream:' "$tmp/list"
grep -q '^npm:' "$tmp/list"
bash "$pkg" add hello
bash "$pkg" add hello
[[ "$(grep -cx hello "$base/apt.txt")" == 1 ]]
grep -qx 'apt-get install -y hello' "$CALLS"
bash "$pkg" update hello
if APT_EXIT=1 bash "$pkg" add failed-package; then exit 1; fi
if grep -qx failed-package "$base/apt.txt"; then exit 1; fi
printf 'n\n' | bash "$pkg" remove hello
if grep -qx hello "$base/apt.txt"; then exit 1; fi
if grep -q 'apt-get remove' "$CALLS"; then exit 1; fi
bash "$pkg" remove zoxide
if grep -qx zoxide "$base/extras.txt"; then exit 1; fi
bash "$pkg" add @scope/tool npm
bash "$pkg" add @scope/tool npm
[[ "$(grep -cx @scope/tool "$base/npm.txt")" == 1 ]]
grep -qx 'npm install --global @scope/tool' "$CALLS"
bash "$pkg" update @scope/tool
grep -qx 'npm install --global @scope/tool@latest' "$CALLS"
printf 'n\n' | bash "$pkg" remove @scope/tool
if grep -qx @scope/tool "$base/npm.txt"; then exit 1; fi
if grep -q 'npm uninstall' "$CALLS"; then exit 1; fi
if bash "$pkg" add '../bad' npm; then exit 1; fi
if bash "$pkg" update untracked-package; then exit 1; fi
if bash "$pkg" remove '../bad'; then exit 1; fi
if bash "$pkg" add hello brew; then exit 1; fi

# --role writes to that role's manifests, which must belong to the profile. Later commands find the package there.
if bash "$pkg" add hello --role extra 2>"$tmp/err"; then exit 1; fi
grep -q "Role extra is not in the server profile" "$tmp/err"
printf 'both\n' > "$HOME/.config/dotfiles/profile"
bash "$pkg" add hello --role extra
# A package belongs to one role, so remove and update always find the only manifest that tracks it.
if bash "$pkg" add jq --role extra 2>"$tmp/err"; then exit 1; fi
grep -q 'jq is already tracked in roles/base/packages/apt.txt' "$tmp/err"
if bash "$pkg" add vercel npm --role extra 2>"$tmp/err"; then exit 1; fi
grep -q 'vercel is already tracked in roles/base/packages/npm.txt' "$tmp/err"
[[ ! -e "$extra/npm.txt" ]] || ! grep -qx vercel "$extra/npm.txt"
bash "$pkg" add @scope/tool npm --role extra
grep -qx hello "$extra/apt.txt"
grep -qx @scope/tool "$extra/npm.txt"
if grep -qx hello "$base/apt.txt"; then exit 1; fi
bash "$pkg" list > "$tmp/list"
grep -qx '  hello' "$tmp/list"
grep -qx '  @scope/tool' "$tmp/list"
printf 'n\n' | bash "$pkg" remove hello
printf 'n\n' | bash "$pkg" remove @scope/tool
if grep -qx hello "$extra/apt.txt"; then exit 1; fi
if grep -qx @scope/tool "$extra/npm.txt"; then exit 1; fi
printf 'Package command checks passed\n'
