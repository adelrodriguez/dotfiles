#!/usr/bin/env bash
# Run macOS package commands on either host without contacting Homebrew or npm.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" CALLS="$tmp/calls"
mkdir -p "$HOME/.local/bin" "$HOME/.config/dotfiles"
cp -R "$repo/scripts" "$repo/roles" "$repo/profiles" "$tmp/"
printf 'mac\n' > "$HOME/.config/dotfiles/profile"
export PATH="$HOME/.local/bin:$PATH"
cat > "$HOME/.local/bin/uname" <<'SH'
#!/bin/sh
echo Darwin
SH
cat > "$HOME/.local/bin/brew" <<'SH'
#!/bin/sh
printf 'brew %s\n' "$*" >> "$CALLS"
SH
cat > "$HOME/.local/bin/fnm" <<'SH'
#!/bin/sh
printf 'fnm %s\n' "$*" >> "$CALLS"
SH
cat > "$HOME/.local/bin/curl" <<'SH'
#!/bin/sh
printf '[{"version":"v99.0.0-rc.1"},{"version":"v28.0.1"}]\n'
SH
cat > "$HOME/.local/bin/npm" <<'SH'
#!/bin/sh
printf 'npm %s\n' "$*" >> "$CALLS"
SH
chmod +x "$HOME/.local/bin/"*
bash "$tmp/scripts/package.sh" update node
grep -qx 'fnm default v28.0.1' "$CALLS"
if grep -q '^brew upgrade node' "$CALLS"; then
  echo 'Node update still has two package owners' >&2
  exit 1
fi
bash "$tmp/scripts/package.sh" update pnpm
grep -qx 'npm install --global pnpm@latest' "$CALLS"
if grep -q '^brew upgrade pnpm' "$CALLS"; then exit 1; fi
bash "$tmp/scripts/package.sh" add example
grep -qx 'brew install example' "$CALLS"
grep -qx 'brew "example"' "$tmp/roles/base/packages/Brewfile"
bash "$tmp/scripts/package.sh" update
grep -q '^brew bundle --upgrade --file ' "$CALLS"
if grep -qx 'brew upgrade' "$CALLS"; then
  echo 'Updating tracked packages upgraded unrelated Homebrew packages' >&2
  exit 1
fi
printf 'macOS uses fnm for Node, npm for pnpm, and Homebrew for formulae\n'
