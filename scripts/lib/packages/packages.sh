#!/usr/bin/env bash
# Routes package commands to the current platform's module.
source "$(dirname "${BASH_SOURCE[0]}")/../core.sh"
source "$(dirname "${BASH_SOURCE[0]}")/linux.sh"
source "$(dirname "${BASH_SOURCE[0]}")/macos.sh"

packages() {
  case "$PLATFORM" in
    Linux) linux_packages "$@" ;;
    Darwin) macos_packages "$@" ;;
    *) die "Unsupported platform: $PLATFORM" ;;
  esac
}
