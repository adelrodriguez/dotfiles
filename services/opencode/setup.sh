#!/usr/bin/env bash
# Home Manager owns the unit. The vendor executable and runtime remain writable.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/runtime.sh"
load_runtime
[[ $# -le 1 && "${1:-}" =~ ^(--prepare)?$ ]] || die "Usage: services/opencode/setup.sh [--prepare]"
root="$HOME/services/opencode"
[[ -x "$HOME/.opencode/bin/opencode" ]] || die 'Run tools/install.sh first.'
mkdir -p "$root/bin"
ln -sfn "$HOME/.opencode/bin/opencode" "$root/bin/opencode"
for name in data state cache; do
  mkdir -p "$root/runtime/$name" "$root/runtime/xdg-$name"
  chmod 700 "$root/runtime/$name"
  ln -sfnT "../$name" "$root/runtime/xdg-$name/opencode"
done
[[ "${1:-}" != --prepare ]] || { info "OpenCode runtime prepared."; exit 0; }
systemctl --user daemon-reload
systemctl --user enable --now opencode-web.service
info 'OpenCode is enabled. An existing process keeps its sessions until a deliberate restart.'
