#!/usr/bin/env bash
# Set up this machine: install packages, link the dotfiles, and configure fish and the scheduled sync.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/packages/packages.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/home.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/fish.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/process-compose.sh"

info "Installing packages"
packages install

info "Linking dotfiles"
link_home

setup_fish
setup_process_compose

info "Done"
