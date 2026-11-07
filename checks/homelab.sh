#!/usr/bin/env bash
set -euo pipefail
[[ "$(cat "$HOME/.config/dotfiles/host")" == homelab ]]
exec "$(dirname "${BASH_SOURCE[0]}")/../scripts/doctor.sh" "$@"
