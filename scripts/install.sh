#!/usr/bin/env bash
# Set up this machine for a profile: install packages, link the dotfiles, and configure fish, the scheduled sync, and the agent environment.
#
#   scripts/install.sh <profile>   Record the profile, then set up the machine.
#   scripts/install.sh             Set up the machine for the recorded profile.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/profile.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/packages/packages.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/home.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/fish.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/process-compose.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/agents-env.sh"

[[ $# -le 1 ]] || die "Usage: scripts/install.sh [$(profile_names)]"
[[ $# -eq 0 ]] || profile_set "$1"
load_profile

info "Installing packages for the ${PROFILE} profile"
packages install

info "Linking dotfiles"
link_home

setup_fish
setup_process_compose
setup_agents_env

info "Done"
