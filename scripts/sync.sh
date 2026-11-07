#!/usr/bin/env bash
# A scheduled sync only applies pinned declarations. Updating inputs is deliberate.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../tools/runtime.sh"
git -C "$DOTFILES_DIR" pull --no-rebase --ff-only || die 'Failed to fast-forward the dotfiles checkout.'
exec "$DOTFILES_DIR/scripts/apply.sh"
