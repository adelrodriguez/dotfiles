#!/usr/bin/env bash
set -euo pipefail
[[ "$(cat "$HOME/.config/dotfiles/host")" == mac ]]
exec "$(dirname "${BASH_SOURCE[0]}")/../scripts/doctor.sh" "$@"
