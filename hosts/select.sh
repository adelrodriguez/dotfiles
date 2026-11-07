#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../tools/runtime.sh"
host_name() {
  local host="${1:-}"
  if [[ -z "$host" ]]; then
    if [[ -r "$HOME/.config/dotfiles/host" ]]; then
      read -r host < "$HOME/.config/dotfiles/host"
    elif [[ -r "$HOME/.config/dotfiles/profile" ]]; then
      read -r host < "$HOME/.config/dotfiles/profile"
    fi
  fi
  [[ "$host" != server ]] || host=homelab
  case "$host:$(uname -s)" in
    mac:Darwin|homelab:Linux) printf '%s\n' "$host" ;;
    *) die 'Choose mac on macOS or homelab on Linux. The server alias is also accepted.' ;;
  esac
}
