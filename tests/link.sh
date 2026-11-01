#!/usr/bin/env bash
# Link role homes into isolated homes: migrate links from the home/ layout, rerun, back up conflicts, and switch profiles.
set -euo pipefail
source_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(cd -P "$(mktemp -d)" && pwd)"
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/dotfiles"
mkdir -p "$repo"
cp -R "$source_repo/scripts" "$source_repo/roles" "$source_repo/profiles" "$repo/"
base="$repo/roles/base/home"
link() { bash "$repo/scripts/link.sh"; }
snapshot() { find "$HOME" | sort | while IFS= read -r path; do printf '%s %s\n' "$path" "$(readlink "$path" || true)"; done; }

# A home linked by the home/ layout: file links and folded directories that now dangle, and a folded
# directory that still holds untracked files.
export HOME="$tmp/home"
mkdir -p "$HOME/.config" "$HOME/.local/bin" "$repo/home/.config/fish" "$repo/home/.config/tmux/plugins"
printf 'SETUVAR x:1\n' > "$repo/home/.config/fish/fish_variables"
ln -s ../dotfiles/home/.gitconfig "$HOME/.gitconfig"
ln -s ../../dotfiles/home/.config/fish "$HOME/.config/fish"
ln -s ../../dotfiles/home/.config/ghostty "$HOME/.config/ghostty"
ln -s ../../dotfiles/home/.config/tmux "$HOME/.config/tmux"
ln -s ../../../dotfiles/home/.local/bin/dotfiles-sync "$HOME/.local/bin/dotfiles-sync"
ln -s "$tmp" "$HOME/.config/elsewhere"
link >/dev/null

case "$(uname -s)" in Linux) expected=server ;; Darwin) expected=mac ;; esac
[[ "$(cat "$HOME/.config/dotfiles/profile")" == "$expected" ]]
[[ "$(cd -P "$(dirname "$(readlink -f "$HOME/.gitconfig")")" && pwd)/.gitconfig" == "$base/.gitconfig" ]]
[[ -d "$HOME/.config/fish" && ! -L "$HOME/.config/fish" ]]
[[ "$(cat "$HOME/.config/fish/fish_variables")" == 'SETUVAR x:1' && ! -L "$HOME/.config/fish/fish_variables" ]]
[[ ! -e "$repo/home/.config/fish/fish_variables" ]]
[[ -f "$HOME/.config/fish/config.fish" && -L "$HOME/.config/fish/conf.d/00-env.fish" ]]
[[ -d "$HOME/.config/ghostty" && ! -L "$HOME/.config/ghostty" && -f "$HOME/.config/ghostty/config" ]]
[[ -x "$HOME/.local/bin/dotfiles-sync" ]]
[[ -d "$HOME/.config/agents" && ! -L "$HOME/.config/agents" ]]
# Paths no role links stay as they were.
[[ -L "$HOME/.config/tmux" && -L "$HOME/.config/elsewhere" ]]
[[ ! -e "$repo/backups" ]]
printf 'Linking migrates a home linked by the home/ layout\n'

before="$(snapshot)"
link >/dev/null
[[ "$(snapshot)" == "$before" ]]
printf 'A second link changes nothing\n'

rm "$HOME/.zshrc"
printf 'local edit\n' > "$HOME/.zshrc"
link >/dev/null
[[ -L "$HOME/.zshrc" ]]
[[ "$(cat "$repo"/backups/*/.zshrc)" == 'local edit' ]]
printf 'A conflicting file moves to backups/\n'

# Roles in one profile share directories. Leaving a role removes its links.
mkdir -p "$repo/roles/extra/home/.config/fish/conf.d"
printf '# extra\n' > "$repo/roles/extra/home/.config/fish/conf.d/zz-extra.fish"
printf 'base\nextra\n' > "$repo/profiles/both.txt"
printf 'both\n' > "$HOME/.config/dotfiles/profile"
link >/dev/null
[[ -L "$HOME/.config/fish/conf.d/zz-extra.fish" && -L "$HOME/.config/fish/conf.d/00-env.fish" ]]
printf '%s\n' "$expected" > "$HOME/.config/dotfiles/profile"
link >/dev/null
[[ ! -e "$HOME/.config/fish/conf.d/zz-extra.fish" && ! -L "$HOME/.config/fish/conf.d/zz-extra.fish" ]]
[[ -L "$HOME/.config/fish/conf.d/00-env.fish" ]]
printf 'Roles share directories, and leaving a role removes its links\n'

# A file that moves to another role is relinked there.
mkdir -p "$repo/roles/extra/home/.config/ghostty"
mv "$base/.config/ghostty/config" "$repo/roles/extra/home/.config/ghostty/config"
printf 'both\n' > "$HOME/.config/dotfiles/profile"
link >/dev/null
[[ "$(readlink -f "$HOME/.config/ghostty/config")" == "$repo/roles/extra/home/.config/ghostty/config" ]]
[[ -z "$(ls "$repo/backups" | sed -n 2p)" ]]
printf 'A file that moves between roles is relinked\n'

export HOME="$tmp/fresh"
mkdir -p "$HOME"
if link 2>"$tmp/err"; then exit 1; fi
grep -q 'No profile recorded. Run: scripts/install.sh <' "$tmp/err"
[[ -z "$(ls -A "$HOME")" ]]
printf 'A fresh home without a profile is left untouched\n'
