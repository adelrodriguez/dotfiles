#!/usr/bin/env bash
# Deploy the agent setup in agents/: `sync` installs the locked commits, `update` moves the lock to the latest ones.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/agents.sh"

[[ $# -eq 1 ]] || die "Usage: scripts/agents.sh sync|update"
deploy_agents "$1"
