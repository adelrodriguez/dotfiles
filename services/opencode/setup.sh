#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
root="$HOME/services/opencode"
version=2.0.22
case "$(uname -m)" in
  x86_64) asset=opencode-linux-x64-baseline.tar.gz ;;
  aarch64) asset=opencode-linux-arm64.tar.gz ;;
  *) echo 'Unsupported OpenCode architecture' >&2; exit 1 ;;
esac
mkdir -p "$root/bin" "$HOME/.config/systemd/user"
if [[ ! -x "$root/bin/opencode" ]] || [[ "$("$root/bin/opencode" --version)" != "opencode v$version" ]]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fL "https://opencode.ai/files/bin/$version/$asset" -o "$tmp/opencode.tar.gz"
  tar -xzf "$tmp/opencode.tar.gz" -C "$tmp"
  [[ "$("$tmp/opencode" --version)" == "opencode v$version" ]]
  install -m 755 "$tmp/opencode" "$root/bin/opencode.new"
  mv "$root/bin/opencode.new" "$root/bin/opencode"
fi
for name in data state cache; do
  mkdir -p "$root/runtime/$name" "$root/runtime/xdg-$name"
  chmod 700 "$root/runtime/$name"
  ln -sfnT "../$name" "$root/runtime/xdg-$name/opencode"
done
unit="$HOME/.config/systemd/user/opencode-web.service"
source="$repo/home/.config/systemd/user/opencode-web.service"
if [[ -e "$unit" && ! -L "$unit" ]]; then
  cp -p "$unit" "$unit.backup-$(date +%Y%m%d%H%M%S)"
fi
ln -sfnT "$source" "$unit"
for name in verify.py caddy.conf; do
  ln -sfnT "$repo/services/opencode/$name" "$root/$name"
done
systemctl --user daemon-reload
systemctl --user enable --now opencode-web.service
echo 'OpenCode service enabled. Run services/opencode/verify.py to check the homelab deployment.'
