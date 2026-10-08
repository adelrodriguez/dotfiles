#!/usr/bin/env bash
# Enable the Process Compose user service that runs the scheduled sync.
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

setup_process_compose() {
  if ! command_exists process-compose || ! command_exists systemctl; then
    return 0
  fi
  if ! systemctl --user show-environment >/dev/null 2>&1; then
    return 0
  fi

  info "Enabling Process Compose scheduler"
  systemctl --user daemon-reload
  systemctl --user enable --now process-compose.service
}
