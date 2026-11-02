#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
root="$HOME/services/opencode"
source "$repo/scripts/lib/packages/opencode.sh"
mkdir -p "$root/bin" "$HOME/.config/systemd/user"
install_opencode_v2 "$root/bin"
for name in data state cache; do
  mkdir -p "$root/runtime/$name" "$root/runtime/xdg-$name"
  chmod 700 "$root/runtime/$name"
  ln -sfnT "../$name" "$root/runtime/xdg-$name/opencode"
done
unit="$HOME/.config/systemd/user/opencode-web.service"
source="$repo/roles/base/home/.config/systemd/user/opencode-web.service"
if [[ -e "$unit" && ! -L "$unit" ]]; then
  cp -p "$unit" "$unit.backup-$(date +%Y%m%d%H%M%S)"
fi
ln -sfnT "$source" "$unit"
for name in verify.py caddy.conf; do
  ln -sfnT "$repo/services/opencode/$name" "$root/$name"
done
systemctl --user daemon-reload
systemctl --user enable opencode-web.service
systemctl --user restart opencode-web.service
echo 'OpenCode service enabled. Run services/opencode/verify.py to check the homelab deployment.'
