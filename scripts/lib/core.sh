#!/usr/bin/env bash
# Repository paths and output helpers. Every module sources this; it sources nothing.

DOTFILES_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROLES_DIR="${DOTFILES_DIR}/roles"
PROFILES_DIR="${DOTFILES_DIR}/profiles"
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

# Print the absolute path a symlink points to, even when the target no longer exists.
resolve_link() {
  local link="$1" target part
  local -a parts=() kept=()
  [[ -L "$link" ]] || return 0
  target="$(readlink "$link")"
  [[ "$target" == /* ]] || target="$(cd -P "$(dirname "$link")" && pwd)/${target}"
  IFS=/ read -r -a parts <<< "$target"
  for part in "${parts[@]}"; do
    case "$part" in
      ""|.) ;;
      ..) [[ ${#kept[@]} -eq 0 ]] || unset "kept[$((${#kept[@]} - 1))]" ;;
      *) kept+=("$part") ;;
    esac
  done
  [[ ${#kept[@]} -gt 0 ]] || kept=("")
  printf '/%s' "${kept[@]}"
  printf '\n'
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
