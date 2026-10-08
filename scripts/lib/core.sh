#!/usr/bin/env bash
# Repository paths and output helpers. Every module sources this; it sources nothing.

DOTFILES_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PACKAGES_DIR="${DOTFILES_DIR}/packages"
HOME_DIR="${DOTFILES_DIR}/home"
PLATFORM="$(uname -s)"
if [[ "$PLATFORM" == Linux ]]; then
  # Do not let an inherited Linuxbrew PATH satisfy installation checks.
  export PATH="$HOME/.local/bin:$HOME/.local/share/fnm:$HOME/.bun/bin:$HOME/.atuin/bin:$HOME/.opencode/bin:/usr/local/bin:/usr/bin:/bin"
fi

info() {
  printf "%s\n" "$1"
}

warn() {
  printf "warn: %s\n" "$1" >&2
}

die() {
  printf "error: %s\n" "$1" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

confirm() {
  local prompt="${1:-Continue?}"
  local default="${2:-n}"
  local reply=""

  if [[ "$default" == "y" ]]; then
    prompt="$prompt [Y/n]: "
  else
    prompt="$prompt [y/N]: "
  fi

  read -r -p "$prompt" reply
  case "$reply" in
    [yY]|[yY][eE][sS]) return 0 ;;
    [nN]|[nN][oO]) return 1 ;;
    "") [[ "$default" == "y" ]] && return 0 || return 1 ;;
    *) return 1 ;;
  esac
}
