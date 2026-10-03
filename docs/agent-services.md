# Host OpenCode and T3 services

Both web servers run as user systemd services on Ubuntu. Run the commands below
as the account that owns the services. This setup is opt-in, separate from `dot init`.

## OpenCode

```sh
bash services/opencode/setup.sh
python3 services/opencode/verify.py
```

The setup script installs OpenCode V2.0.22, links the tracked systemd unit, prepares
the runtime directories, and enables `opencode-web.service`. Stop any Docker
deployment using port 4096 or this database before running it.

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

Install T3 Code first or restore `~/.t3` from backup. On a fresh installation with
no `t3` on PATH, pass `T3_BIN=/absolute/path/to/t3` to the setup script.
The script reads the active version from `~/.t3/runtime/service-state.json` on an
existing installation, then uses `t3 service install` to generate the user unit.

T3 owns `~/.config/systemd/user/t3code.service` and rewrites it during supported
updates. It is deliberately not a Stow symlink. The reference unit in
`services/t3/t3code.service.reference` records the stable 0.0.45 setup as of
2026-10-03. The live launcher selects the version recorded in T3's runtime state.
Use `t3 update` to change versions rather than editing the unit or runtime state.

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
