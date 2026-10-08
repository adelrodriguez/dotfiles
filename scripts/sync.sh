#!/usr/bin/env bash
# Fast-forward the current branch, then relink. Stops before touching $HOME if the pull fails.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/home.sh"

info "Pulling latest changes"
git -C "$DOTFILES_DIR" pull --no-rebase --ff-only || die "Failed to pull latest changes"
link_home
info "Done"
