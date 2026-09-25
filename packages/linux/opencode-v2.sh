#!/usr/bin/env bash

install_opencode_v2() (
  set -euo pipefail
  local tmp asset url checksum
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
  url="$(awk -F '"' -v asset="/$asset" 'index($0, asset) { print $2 }' "$tmp/release")"
  checksum="$(awk -F '"' -v asset="/$asset" 'index($0, asset) { getline; print $2 }' "$tmp/release")"
  [[ "$url" == https://opencode.ai/files/bin/* && "$checksum" =~ ^[0-9a-f]{64}$ ]]
  curl -fsSL "$url" -o "$tmp/opencode.tar.gz"
  printf '%s  %s\n' "$checksum" "$tmp/opencode.tar.gz" | sha256sum --check
  tar -xf "$tmp/opencode.tar.gz" -C "$tmp"
  mkdir -p "$HOME/.opencode/bin"
  install -m 755 "$tmp/opencode" "$HOME/.opencode/bin/opencode.new"
  mv -f "$HOME/.opencode/bin/opencode.new" "$HOME/.opencode/bin/opencode"
)
