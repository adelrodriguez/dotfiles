# Host OpenCode and T3 services

Both web servers run as user systemd services on Ubuntu. Run the commands below
as the account that owns the services. This setup is opt-in, separate from `scripts/install.sh`.

## OpenCode

```sh
bash services/opencode/setup.sh
python3 services/opencode/verify.py
```

The setup script installs the latest stable OpenCode V2 published in the official
Homebrew formula, verifies its checksum, links the tracked systemd unit, prepares
the runtime directories, and enables and restarts `opencode-web.service`. Stop any
Docker deployment using port 4096 or this database before running it.

Rerun the setup script to update the service. `scripts/package.sh update opencode`
updates the host CLI separately. After updating the CLI, rerun the service setup
to align its binary, then run the verifier. `scripts/doctor.sh` reports a release
difference between the two binaries. The verifier checks that the running service
matches its installed binary rather than requiring a fixed release.

The service binds to `127.0.0.1:4096`. Its executable lives in
`~/services/opencode/bin`, with data, state, and cache in `~/services/opencode/runtime`.
These directories preserve the former container's sessions and remain separate
from the host CLI's database. Configuration comes from `~/.config/opencode`.

`services/opencode/caddy.conf` records the homelab route for
`https://opencode.homelab.adel.wtf`. Caddy supplies the Authorization header from
`/etc/caddy/secrets/opencode-authorization`. On a restored host, restore this file
and the matching `~/.config/opencode/service.json` credentials privately, then
include the route in the host Caddy configuration. The setup script does not
configure Caddy. The verifier expects this homelab route and existing sessions.

## T3 Code

```sh
bash services/t3/setup.sh
```

The Ubuntu dotfiles installer installs the self-contained T3 CLI with the
[official binary installer](https://github.com/pingdotgg/t3code#command-line).
To install it separately, run:

```sh
curl -fsSL https://t3.codes/install.sh | sh
```

The installer puts `t3` in `~/.local/bin` and the versioned runtime in `~/.t3`.
It requires no Node, npm, or npx. To update the CLI through dotfiles, run
`scripts/package.sh update t3`. For a custom installation with no `t3` on PATH,
pass `T3_BIN=/absolute/path/to/t3` to the setup script.
The script reads the active version from `~/.t3/runtime/service-state.json` on an
existing installation, then uses `t3 service install` to generate the user unit.

T3 owns `~/.config/systemd/user/t3code.service` and rewrites it during supported
updates. It is deliberately not a Stow symlink. The reference unit in
`services/t3/t3code.service.reference` records the stable 0.0.45 setup as of
2026-10-03. The live launcher selects the version recorded in T3's runtime state.
Use `t3 update` to change versions rather than editing the unit or runtime state.

Because T3 owns its unit, the agent environment reaches it through the Stow drop-in
`roles/base/home/.config/systemd/user/t3code.service.d/agents-env.conf`. See "Agent environment"
in the README.

`scripts/link.sh` also generates `runtime.conf` drop-ins for both agent services
from the shared `roles/base/home/.config/agents/runtime.path`. These select fnm's
default Node and the same npm and agent tools as a shell. The drop-ins remove
`CODEX_HOME` so Codex uses `~/.codex`. Relinking does not restart either service.
Reload the user units and restart each service when its sessions can stop:

```sh
systemctl --user daemon-reload
systemctl --user restart opencode-web.service
systemctl --user restart t3code.service
```

Run `scripts/doctor.sh` from a fresh Fish session afterward. It checks the running
process environments as well as the saved drop-ins. It prints variable names and
repair instructions, never secret values.

T3 stores its settings and databases under `~/.t3/userdata`. Its observed web port
is 3773, also recorded in `~/.t3/userdata/server-runtime.json` while running.

## Boot and maintenance

Enable lingering once so user services start at boot without an interactive login:

```sh
sudo loginctl enable-linger "$USER"
systemctl --user status opencode-web.service t3code.service
systemctl --user restart opencode-web.service
systemctl --user restart t3code.service
journalctl --user -u opencode-web.service -n 100
tail -n 100 ~/.t3/userdata/logs/boot-service.log
```

Back up `~/services/opencode/runtime`, `~/.config/opencode`, and `~/.t3` privately.
Stop the services before copying live databases, or use database-aware backups.
Dotfiles contains the setup scripts and configuration, not credentials, binaries,
session databases, or logs.
