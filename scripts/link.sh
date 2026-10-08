#!/usr/bin/env bash
# Back up conflicting files and link home/ into $HOME.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/home.sh"

link_home
