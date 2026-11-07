#!/usr/bin/env bash
# Build first, then hand over legacy files and activate the selected host.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../hosts/select.sh"
host="$(host_name "${1:-}")"
[[ $# -le 2 && "${2:-}" =~ ^(--build)?$ ]] || die 'Usage: scripts/apply.sh [mac|homelab] [--build]'
command_exists nix || die 'Nix is required. Run scripts/bootstrap.sh first.'
export NIX_CONFIG="${NIX_CONFIG:-}
experimental-features = nix-command flakes"
cd "$DOTFILES_DIR"
[[ "$DOTFILES_DIR" == "$(nix eval --raw ".#homeConfigurations.$host.config.dotfiles.checkout")" ]] \
  || die "Set hosts/$host's checkout path to $DOTFILES_DIR before applying."
if [[ "${2:-}" != --build ]]; then
  [[ "$HOME" == "$(nix eval --raw ".#homeConfigurations.$host.config.home.homeDirectory")" &&      "$(id -un)" == "$(nix eval --raw ".#homeConfigurations.$host.config.home.username")" ]]     || die 'Run apply as the account declared for this host.'
fi
if [[ "$host" == mac ]]; then
  result="$(nix build --no-link --print-out-paths .#darwinConfigurations.mac.system)"
else
  result="$(nix build --no-link --print-out-paths .#homeConfigurations.homelab.activationPackage)"
fi
[[ "${2:-}" != --build ]] || { info "Built $result"; exit 0; }
manifest="$(mktemp)"
trap 'rm -f "$manifest"' EXIT
nix eval --json ".#homeConfigurations.$host.config.home.file" --apply 'files: builtins.attrNames files' > "$manifest"
if [[ "$host" == mac ]]; then fish="$result/sw/bin/fish"; else fish="$result/home-path/bin/fish"; fi
python3 "$DOTFILES_DIR/home/handoff.py" "$HOME" "$DOTFILES_DIR" "$manifest" "$fish"
if [[ "$host" == mac ]]; then
  info 'Activating nix-darwin. macOS may request administrator access.'
  sudo "$result/sw/bin/darwin-rebuild" switch --flake "$DOTFILES_DIR#mac"
else
  "$result/activate"
fi
load_runtime
"$DOTFILES_DIR/tools/install.sh"
info 'Applied the host configuration. Existing agent services keep their running sessions.'
