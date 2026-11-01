#!/usr/bin/env bash
# OpenCode V2 from the release published in its official Homebrew formula.

install_opencode_v2() (
  set -euo pipefail
  local tmp asset url checksum version install_dir="${1:-$HOME/.opencode/bin}"
  case "$(uname -m)" in
    x86_64) asset=opencode-linux-x64-baseline.tar.gz ;;
    aarch64) asset=opencode-linux-arm64.tar.gz ;;
    *) echo 'Unsupported OpenCode architecture' >&2; exit 1 ;;
  esac
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  # The official V2 formula publishes its release URL and checksum. The generic
  # opencode.ai/install script still installs V1; do not downgrade fresh machines.
  curl -fsSL https://raw.githubusercontent.com/anomalyco/homebrew-tap/HEAD/opencode-v2.rb -o "$tmp/release"
  version="$(awk -F '"' '/^ *version / { print $2 }' "$tmp/release")"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
  if [[ -x "$install_dir/opencode" ]] && [[ "$("$install_dir/opencode" --version)" == "opencode v$version" ]]; then
    return
  fi
  url="$(awk -F '"' -v asset="/$asset" 'index($0, asset) { print $2 }' "$tmp/release")"
  checksum="$(awk -F '"' -v asset="/$asset" 'index($0, asset) { getline; print $2 }' "$tmp/release")"
  [[ "$url" == https://opencode.ai/files/bin/* && "$checksum" =~ ^[0-9a-f]{64}$ ]]
  curl -fsSL "$url" -o "$tmp/opencode.tar.gz"
  printf '%s  %s\n' "$checksum" "$tmp/opencode.tar.gz" | sha256sum --check
  tar -xf "$tmp/opencode.tar.gz" -C "$tmp"
  [[ "$("$tmp/opencode" --version)" == "opencode v$version" ]]
  mkdir -p "$install_dir"
  install -m 755 "$tmp/opencode" "$install_dir/opencode.new"
  mv -f "$install_dir/opencode.new" "$install_dir/opencode"
)
