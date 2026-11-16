#!/usr/bin/env bash
# Home Manager owns the unit. The vendor executable remains writable.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/runtime.sh"
load_runtime
[[ $# -le 1 && "${1:-}" =~ ^(--prepare)?$ ]] || die "Usage: services/opencode/setup.sh [--prepare]"
root="$HOME/services/opencode"
[[ -x "$HOME/.opencode/bin/opencode" ]] || die 'Run tools/install.sh first.'
mkdir -p "$root/bin"
ln -sfn "$HOME/.opencode/bin/opencode" "$root/bin/opencode"
[[ "${1:-}" != --prepare ]] || { info "OpenCode runtime prepared."; exit 0; }
systemctl --user daemon-reload
systemctl --user enable --now opencode-web.service
info 'OpenCode is enabled. Restart an already-running service to move it onto the shared session database.'
