#!/usr/bin/env bash
# Fill ~/.config/agents/env from 1Password. Rerun to pick up rotated keys.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/agents-env.sh"

write_agents_env
