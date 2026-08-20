set -gx CODEX_HOME ~/.config/codex
set -gx pnpm_config_pm_on_fail download

if status is-interactive
# Commands to run in interactive sessions can go here
end

# pnpm
set -gx PNPM_HOME '/Users/adelrodriguez/Library/pnpm'
if not string match -q -- "$PNPM_HOME/bin" $PATH
  set -gx PATH "$PNPM_HOME/bin" $PATH
end
# pnpm end
