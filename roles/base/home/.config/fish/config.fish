set -eg CODEX_HOME
set -eU CODEX_HOME
set -gx OPENCODE_LOG_LEVEL warn
set -gx pnpm_config_pm_on_fail download

if status is-interactive
# Commands to run in interactive sessions can go here
end
