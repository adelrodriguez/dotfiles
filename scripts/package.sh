#!/usr/bin/env bash
# Install, add, remove, update, or list the current platform's tracked packages.
#
#   scripts/package.sh install
#   scripts/package.sh add <name> [apt|brew|cask]
#   scripts/package.sh remove <name>
#   scripts/package.sh update [name]
#   scripts/package.sh list
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/packages/packages.sh"

packages "$@"
