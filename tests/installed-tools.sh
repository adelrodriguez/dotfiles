#!/usr/bin/env bash
# Run from a fresh Fish session so fnm and user-local paths match normal use.
set -euo pipefail

case ":$PATH:" in *linuxbrew*) echo 'Linuxbrew remains on PATH' >&2; exit 1 ;; esac
if command -v brew >/dev/null; then echo 'brew remains available' >&2; exit 1; fi

for tool in atuin bat btop bwrap bun claude codex delta direnv eza fd fish fnm fzf gh git grok jq nvim node opencode pnpm process-compose rg starship stow t3 op zoxide; do
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
done < "$(dirname "${BASH_SOURCE[0]}")/../packages/npm.txt"

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
