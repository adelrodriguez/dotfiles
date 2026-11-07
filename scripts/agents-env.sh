#!/usr/bin/env bash
# Refresh private agent variables, then apply the service restart policy.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../agents/env.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../services/environment.sh"
[[ $# == 0 || ( $# == 1 && "$1" == --if-configured ) ]] || die 'Usage: scripts/agents-env.sh [--if-configured]'
if [[ "${1:-}" == --if-configured && ! -r "$AGENTS_TOKEN" ]]; then
  info "Skipping agent environment: no 1Password service account token at ${AGENTS_TOKEN}"
  exit 0
fi
write_agents_env
reload_agent_services "$AGENTS_ENV"
