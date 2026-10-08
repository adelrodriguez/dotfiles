#!/usr/bin/env bash
# Make fish the login shell and install fisher plugins.
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

setup_fish() {
  if ! command_exists fish; then
    warn "Fish is not installed"
    return 0
  fi

  local fish_path installer
  fish_path="$(command -v fish)"

  if ! grep -qF "$fish_path" /etc/shells; then
    info "Adding fish to /etc/shells"
    echo "$fish_path" | sudo tee -a /etc/shells >/dev/null || warn "Failed to update /etc/shells"
  fi

  if [[ "${SHELL:-}" != "$fish_path" ]]; then
    info "Setting fish as default shell"
    if [[ "$PLATFORM" == Linux ]]; then
      sudo chsh -s "$fish_path" "$(id -un)"
    else
      chsh -s "$fish_path" || warn "Failed to change default shell"
    fi
  fi

  info "Ensuring fisher is installed"
  if ! fish -c "type -q fisher"; then
    installer="$(mktemp)"
    curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish -o "$installer"
    fish -c 'source $argv[1]; fisher install jorgebucaran/fisher' -- "$installer"
    rm -f "$installer"
  fi

  info "Updating fisher plugins"
  fish -c "if type -q fisher; fisher update; if test -f ~/.config/fish/fish_plugins; fisher install (cat ~/.config/fish/fish_plugins); end; else; echo 'fisher not found'; end" \
    || warn "Failed to update fisher plugins"
}
