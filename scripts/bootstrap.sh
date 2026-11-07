#!/usr/bin/env bash
# Provision a host. Run from the checkout path declared in its Nix configuration.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/core.sh"
host="$(host_name "${1:-}")"
[[ $# -le 1 ]] || die 'Usage: scripts/bootstrap.sh mac|homelab'
if ! command_exists nix; then
  info 'Installing Nix 2.34.1 in daemon mode. This requests administrator access and creates /nix.'
  installer="$(mktemp)"
  trap 'rm -f "$installer"' EXIT
  curl --proto '=https' --tlsv1.2 -fsSL https://releases.nixos.org/nix/nix-2.34.1/install -o "$installer"
  sh "$installer" --daemon --yes
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
if [[ "$host" == mac ]]; then
  [[ -x /opt/homebrew/bin/brew ]] || die 'Install Homebrew from https://brew.sh, then rerun bootstrap.'
fi
"$DOTFILES_DIR/scripts/apply.sh" "$host"
load_runtime
"$DOTFILES_DIR/scripts/agents.sh" sync
source "$DOTFILES_DIR/scripts/lib/agents-env.sh"
setup_agents_env
if [[ "$host" == homelab ]]; then
  fish_shell="$HOME/.nix-profile/bin/fish"
  grep -qxF "$fish_shell" /etc/shells || printf '%s\n' "$fish_shell" | sudo tee -a /etc/shells >/dev/null
  [[ "$(getent passwd "$(id -un)" | cut -d: -f7)" == "$fish_shell" ]] || sudo chsh -s "$fish_shell" "$(id -un)"
  sudo loginctl enable-linger "$(id -un)"
  "$DOTFILES_DIR/services/opencode/setup.sh"
  "$DOTFILES_DIR/services/t3/setup.sh"
  systemctl --user enable --now process-compose.service
fi
"$DOTFILES_DIR/scripts/doctor.sh"
