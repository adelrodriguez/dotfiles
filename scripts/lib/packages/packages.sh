#!/usr/bin/env bash
# Routes package commands to the current platform's module, and to npm.sh for global npm tools.
source "$(dirname "${BASH_SOURCE[0]}")/../core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/linux.sh"
source "$(dirname "${BASH_SOURCE[0]}")/macos.sh"
source "$(dirname "${BASH_SOURCE[0]}")/npm.sh"

platform_packages() {
  case "$PLATFORM" in
    Linux) linux_packages "$@" ;;
    Darwin) macos_packages "$@" ;;
    *) die "Unsupported platform: $PLATFORM" ;;
  esac
}

packages() {
  local action="${1:-}" name="${2:-}" type="${3:-}"
  case "$action" in
    add)
      if [[ "$type" == npm ]]; then
        npm_packages add "$name"
        return
      fi ;;
    remove|update)
      if [[ -n "$name" ]] && npm_tracked "$name"; then
        npm_packages "$action" "$name"
        return
      fi ;;
  esac
  # Platform packages first, so npm.sh finds the Node they install.
  platform_packages "$@"
  case "$action" in
    install|list) npm_packages "$action" ;;
    update) [[ -n "$name" ]] || npm_packages update ;;
  esac
}
