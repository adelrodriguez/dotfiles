#!/usr/bin/env bash
# Run from a fresh Fish session on either supported profile.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$repo/scripts/doctor.sh"
source "$repo/scripts/lib/profile.sh"
load_profile

case ":$PATH:" in *linuxbrew*) echo 'Linuxbrew remains on PATH' >&2; exit 1 ;; esac
if [[ "$PLATFORM" == Linux ]] && command -v brew >/dev/null; then echo 'brew remains available' >&2; exit 1; fi

tools=(apm atuin bat btop bun claude codex delta direnv eza fd fish fnm fzf gh git grok jq nvim node opencode pnpm rg starship stow op uv zoxide)
if [[ "$PLATFORM" == Linux ]]; then tools+=(bwrap process-compose t3); fi
for tool in "${tools[@]}"; do
  binary="$(command -v "$tool")"
  printf '\n%s (%s)\n' "$tool" "$binary"
  case "$tool" in
    process-compose) "$binary" version ;;
    *) "$binary" --version ;;
  esac
done

while IFS= read -r name; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  npm ls --global "$name" >/dev/null
done < <(manifest_entries npm.txt)

# Exercise the databases and runtime files, without printing shell history.
atuin history list >/dev/null
zoxide query --list >/dev/null
nvim --headless -u NONE '+lua assert(vim.fn.isdirectory(vim.env.VIMRUNTIME) == 1)' +qa
printf 'hello\n' | bat --plain --paging=never >/dev/null
printf 'hello\n' | rg hello >/dev/null
printf '{"ok":true}\n' | jq -e .ok >/dev/null
fzf --filter hello <<< hello >/dev/null
fish -c 'true'
printf '\nInstalled-tool checks passed\n'
