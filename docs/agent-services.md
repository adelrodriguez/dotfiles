# How to operate the homelab agent services

This guide shows you how to run the declared OpenCode and T3 services on Ubuntu. Use the account that owns their data. Home Manager owns the OpenCode and Process Compose units. T3 owns its generated main unit. Home Manager supplies environment drop-ins for both agent services.

## Prepare and start the services

Run `scripts/bootstrap.sh homelab` for a new host. On an existing host after applying the configuration:

```sh
tools/install.sh
bash services/opencode/setup.sh
bash services/t3/setup.sh
systemctl --user enable --now process-compose.service
```

`services/opencode/setup.sh --prepare` prepares the runtime without contacting systemd, which CI uses to verify generated units.

OpenCode setup links `~/services/opencode/bin/opencode` to the writable host CLI at `~/.opencode/bin/opencode`, prepares its existing runtime directories, and enables the Home Manager unit. The service binds to `127.0.0.1:4096`. Its data, state, and cache stay under `~/services/opencode/runtime`, separate from the host CLI database. Existing sessions are preserved.

T3 setup reads the active version from `~/.t3/runtime/service-state.json` when present and calls `t3 service install`. T3 keeps its versioned runtime and settings under `~/.t3`. Use `t3 update` for supported updates. Do not replace its main `t3code.service` with a Nix-managed file.

Restore the existing private `~/.config/opencode/service.json` and `/etc/caddy/secrets/opencode-authorization` before testing the homelab web route. Include `services/opencode/caddy.conf` in the host Caddy configuration. Nix does not own those credentials or change the system Caddy installation.

## Refresh the runtime

Both agent drop-ins use the host's declared PATH, load `~/.config/agents/env` when present, and remove `CODEX_HOME`. Applying Home Manager updates the saved definitions without restarting running sessions. After a runtime or CLI update, restart services when their sessions can stop:

```sh
systemctl --user daemon-reload
systemctl --user restart opencode-web.service
systemctl --user restart t3code.service
scripts/doctor.sh
```

Use `opencode upgrade --method curl` for a vendor-supported CLI update. The service and interactive command share the executable, so restart the service afterward. `scripts/agents-env.sh` restarts OpenCode only if its running environment is stale. It reports when T3 needs a restart, because restarting T3 ends its sessions.

## Verify the deployed services

```sh
systemctl --user status opencode-web.service t3code.service process-compose.service
python3 services/opencode/verify.py
journalctl --user -u opencode-web.service -n 100
```

The OpenCode verifier expects homelab's private route, authentication, and copied session history. A fresh disposable CI host cannot prove those private integrations. The doctor checks active and enabled services plus their running PATH and Codex home policy without printing secret values.

Process Compose listens on port 10080 and runs `dotfiles-sync` every 15 minutes. The `pc` alias attaches to its TUI. Use F9 to pause sync and F7 to resume. Linux bootstrap enables lingering so these user services start at boot without an interactive login.
