#!/usr/bin/env bash
# Service restart policy belongs to services, not the environment writer.
source "$(dirname "${BASH_SOURCE[0]}")/../tools/runtime.sh"

# Succeeds when the unit is stopped or its running process already holds every line of the env file.
agent_service_is_current() {
  local pid env_file="$2"
  pid="$(systemctl --user show -p MainPID --value "$1")"
  [[ "$pid" == 0 ]] && return 0
  ! grep -vE '^(#.*)?$' "$env_file" | grep -vxF -f <(tr '\0' '\n' <"/proc/${pid}/environ") >/dev/null
}

# Restart OpenCode when it runs without the current values. Restarting T3 would end its sessions, so only report it.
reload_agent_services() {
  local env_file="$1"
  command_exists systemctl && systemctl --user show-environment >/dev/null 2>&1 || return 0
  systemctl --user daemon-reload
  agent_service_is_current opencode-web.service "$env_file" || systemctl --user restart opencode-web.service
  agent_service_is_current t3code.service "$env_file" \
    || info "Restart t3code.service and start new agent sessions to load ${env_file}"
}
