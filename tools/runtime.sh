#!/usr/bin/env bash
# Repository paths and common command helpers. Do not rewrite the caller's PATH.
DOTFILES_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
unset CODEX_HOME
info() { printf '%s\n' "$1"; }
warn() { printf 'warn: %s\n' "$1" >&2; }
die() { printf 'error: %s\n' "$1" >&2; exit 1; }
command_exists() { command -v "$1" >/dev/null 2>&1; }
load_runtime() {
  local entry runtime=""
  [[ -r "$HOME/.config/agents/runtime.path" ]] || die 'Apply the Home Manager configuration first.'
  while IFS= read -r entry || [[ -n "$entry" ]]; do
    [[ -n "$entry" ]] && runtime="${runtime:+$runtime:}$entry"
  done < "$HOME/.config/agents/runtime.path"
  export PATH="$runtime"
}
