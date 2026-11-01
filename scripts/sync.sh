#!/usr/bin/env bash
# Fast-forward the current branch, then relink with the pulled scripts. Stops before touching $HOME if the pull fails.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/core.sh"

info "Pulling latest changes"
git -C "$DOTFILES_DIR" pull --no-rebase --ff-only || die "Failed to pull latest changes"
# A new process loads the pulled modules, so a pull that changes the layout links with code that knows it.
"$DOTFILES_DIR/scripts/link.sh"
info "Done"
