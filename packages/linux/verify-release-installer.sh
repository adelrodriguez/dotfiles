#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/github-release.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
mkdir -p "$HOME/.local/bin" "$tmp/payload/btop/bin"
printf '#!/bin/sh\necho "btop version: 9.9.9"\n' > "$tmp/payload/btop/bin/btop"
chmod +x "$tmp/payload/btop/bin/btop"
tar -czf "$tmp/release.tar.gz" -C "$tmp/payload" btop
cat > "$tmp/release.json" <<EOF
{"tag_name":"v9.9.9","assets":[{"name":"btop-$(uname -m)-unknown-linux-musl.tar.gz","browser_download_url":"https://example.invalid/release.tar.gz"}]}
EOF
curl() {
  local url="" output=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o) output="$2"; shift 2 ;;
      https://*) url="$1"; shift ;;
      *) shift ;;
    esac
  done
  case "$url" in
    */releases/latest) cp "$fixture/release.json" "$output" ;;
    */release.tar.gz) cp "$fixture/release.tar.gz" "$output" ;;
    *) return 1 ;;
  esac
}
fixture="$tmp"
install_github_release btop
[[ "$("$HOME/.local/bin/btop")" == 'btop version: 9.9.9' ]]
first="$(readlink "$HOME/.local/bin/btop")"
install_github_release btop
[[ "$(readlink "$HOME/.local/bin/btop")" == "$first" ]]
[[ -f "$HOME/.local/bin/btop" ]]
printf 'Release layout and repeat-install checks passed\n'
