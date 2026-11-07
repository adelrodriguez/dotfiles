# Deploy the agent setup

`agents/` lists the skills, instructions, and MCP servers I use with every coding agent. [APM](https://github.com/microsoft/apm) installs them for Claude Code, Codex, Cursor, OpenCode, and Grok.

My own skills and instructions live in their own repos:

- [adelrodriguez/instructions](https://github.com/adelrodriguez/instructions) holds my global instructions. Installing it also installs the few skills they name.
- [adelrodriguez/skills](https://github.com/adelrodriguez/skills) holds my skills. `agents/apm.yml` lists each one I use globally, so a skill added to that repo stays out of my setup until I list it here.

## Install APM

`scripts/install.sh` installs APM on both profiles. macOS uses `roles/base/packages/Brewfile`. Linux installs uv with its standalone installer and installs `apm-cli` with `uv tool install --upgrade apm-cli`.

Then sync. APM fetches the packages with your git credentials:

```sh
make -C ~ agents:sync
```

## Move from dotagents

The setup used to live in [adelrodriguez/dotagents](https://github.com/adelrodriguez/dotagents), cloned at `~/.apm`. The sync refuses to run while `~/.apm` is still that clone. Do these steps once on each machine that has the clone.

1. If the machine synced the layout from before [dotagents#20](https://github.com/adelrodriguez/dotagents/pull/20), follow [How to upgrade from the old layout](https://github.com/adelrodriguez/dotagents/blob/main/docs/how-to-upgrade-from-the-old-layout.md) first. Its scripts read the clone's history.
2. Check that the clone has nothing unpushed. This prints nothing when the clone is clean and matches `origin/main`:

	```sh
	git -C ~/.apm status --porcelain && git -C ~/.apm log --oneline origin/main..
	```

3. Remove the clone's git folder and tracked files. APM's own files, such as `apm_modules/`, `deployment-receipts/`, and the deployed `apm.lock.yaml`, stay:

	```sh
	rm -rf ~/.apm/.git ~/.apm/.github ~/.apm/docs ~/.apm/AGENTS.md ~/.apm/README.md ~/.apm/Makefile ~/.apm/.gitignore
	```

4. Sync. If `agents/apm.lock.yaml` matches the lock that the clone deployed, the sync copies only `apm.yml` and `apm.lock.yaml` and changes no deployed file:

	```sh
	make -C ~ agents:sync
	```

## What a sync does

`make -C ~ agents:sync` runs `scripts/agents.sh sync`, which does these steps:

1. Copies `agents/apm.yml` and `agents/apm.lock.yaml` into `~/.apm`. APM reads its user-scope manifest only from `~/.apm`, and it refuses a symlinked `apm.yml`, so Stow can't link them. If `agents/apm.lock.yaml` differs from the lock in `~/.apm`, which happens after a pull changes it, the sync stops before it copies anything. The deployed lock is the only record of the files to remove, so follow "Update after a pull" in `agents/AGENTS.md` first.
2. `apm install --global` installs everything in the lock, at the commits it records. If `apm.yml` and the lock disagree, it updates the lock to match.
3. `apm prune` deletes packages in `~/.apm/apm_modules/` that `apm.yml` no longer lists, and removes their records from the lock. Global compile reads every instruction in `apm_modules/`, so a removed package's instructions would otherwise stay in `AGENTS.md`.
4. `apm compile --global` merges the instructions into `~/.codex/AGENTS.md` and `~/.config/opencode/AGENTS.md`.

After each APM step, even one that fails, the sync copies `apm.yml` and `apm.lock.yaml` back into `agents/` if APM changed them, so check `git status` after a sync. The repository's lock then always matches the deployed lock, and the check in step 1 stops only after a pull.

`make -C ~ agents:update` runs `apm update --global --yes` in place of `apm install --global`, then runs `apm install --global` once more. APM 0.35.0 can delete skill files that an update changes ([microsoft/apm#3422](https://github.com/microsoft/apm/issues/3422)), and the second install restores them. Drop it once a release includes [microsoft/apm#3440](https://github.com/microsoft/apm/pull/3440).

Never run `apm install` or `apm update` without `--global`. Inside `~/.apm`, a plain `apm install` installs at project scope, which writes `.claude/`, `.agents/`, `.cursor/`, `.grok/`, and `agent-data/` there and adds project-scope entries to the lock.

Run `bash tests/agents.sh` to check the sync with APM replaced by a stub.

## Where each agent reads them

| Agent | Skills | Instructions |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `~/.claude/rules/<name>.md` |
| Codex | `~/.agents/skills/` | `~/.codex/AGENTS.md` |
| Cursor | `~/.agents/skills/` | None. APM doesn't support Cursor instructions at user scope. |
| OpenCode | `~/.config/opencode/skills/` | `~/.config/opencode/AGENTS.md` |
| Grok Build | `~/.grok/skills/` | `~/.grok/rules/` |
| Grok Bot | `~/agent-data/workflows/` | None. Grok Bot takes skills only. |

The merged `AGENTS.md` files drop `applyTo` scoping, so every instruction applies everywhere in Codex and OpenCode.

## Add a skill

1. Add the skill's name to the `adelrodriguez/skills` list in `agents/apm.yml`. For a third-party skill, add it to its repo's list, or add the repo with the `git:` and `skills:` form.
2. Run `make -C ~ agents:update`. A plain sync installs the repo at the commit in the lock, which may predate the skill.
3. Commit `agents/apm.yml` and the changed `agents/apm.lock.yaml`.

## Change a skill or an instruction

1. Push the change to `main` in [adelrodriguez/skills](https://github.com/adelrodriguez/skills) or [adelrodriguez/instructions](https://github.com/adelrodriguez/instructions).
2. Run `make -C ~ agents:update`. It moves every package in the lock, including the third-party skills, to the latest commit on its branch and deploys them.
3. Commit the changed `agents/apm.lock.yaml`.

## Files

| Path | Contents |
|---|---|
| `agents/apm.yml` | The targets, the packages and skills to install, and the MCP servers |
| `agents/apm.lock.yaml` | The resolved commits and deployed files. APM writes it, so don't edit it by hand. |
| `agents/AGENTS.md` | Steps for agents that sync, including the cleanup after a pull changes the lock |
| `scripts/agents.sh`, `scripts/lib/agents.sh` | The `sync` and `update` commands |
| `roles/base/home/Makefile` | The `agents:sync` and `agents:update` targets |
