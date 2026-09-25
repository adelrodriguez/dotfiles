set -gx CODEX_HOME ~/.config/codex
set -gx OPENCODE_LOG_LEVEL warn
set -gx pnpm_config_pm_on_fail download

if status is-interactive
# Commands to run in interactive sessions can go here
end

# pnpm
if test (uname) = Darwin
  set -gx PNPM_HOME "$HOME/Library/pnpm"
else if set -q XDG_DATA_HOME; and test -n "$XDG_DATA_HOME"
  set -gx PNPM_HOME "$XDG_DATA_HOME/pnpm"
else
  set -gx PNPM_HOME "$HOME/.local/share/pnpm"
end
if not string match -q -- "$PNPM_HOME/bin" $PATH
  set -gx PATH "$PNPM_HOME/bin" $PATH
end
# pnpm end
