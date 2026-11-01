# AGENTS.md

This folder is the user's global agent setup. `make -C ~ agents:sync` deploys it with APM to every agent on the machine, so a sync changes every agent at once.

## Sync

- Sync only from `main` in the checkout that Stow links into `~`. `~/Makefile` resolves to that checkout. On a feature branch or in a worktree, check changes by reading the files and the diff, and report them as landing on the next sync after merge. Don't run `make agents:sync`, `make agents:update`, `scripts/agents.sh`, or `apm` until the PR merges.
- Run `make -C ~ agents:sync` for a sync and `make -C ~ agents:update` to move the lock to the latest commits. Never run `apm install` or `apm update` yourself. APM reads only `~/.apm/apm.yml`, and the sync copies `apm.yml` and `apm.lock.yaml` from this folder into `~/.apm`, then copies them back if APM changed them.

## Update after a pull

APM checks each deployed file against its hash in the lock in `~/.apm`. Once a pull changes `agents/apm.lock.yaml`, `make -C ~ agents:sync` stops with "differs from the deployed lock" until you finish these steps. A plain copy of the new lock would make APM get two things wrong. It would leave installed every file that the pull removed from the lock. It would also treat every file that the pull changed as a user edit and skip it with "no trustworthy local deployment baseline". Fix both yourself:

1. Copy `~/.apm/apm.lock.yaml` to `/tmp/apm-old.lock.yaml`. It is the old lock, which records what is deployed. The new lock is `agents/apm.lock.yaml`. List the `deployed_files` paths that the old lock records and the new lock does not. This step is done when you have that list. If the two locks are identical, skip to step 4.
2. For each file in that list, delete `~/<path>` if its contents still match its hash under `deployed_file_hashes` in the old lock. Report each file whose hash differs, because the user edited it, and leave it in place. The list also holds folder paths, which have no hash. Delete a folder only when it is empty, and never delete a folder with what it contains. This step is done when every file in the list is gone or reported, and every listed folder is gone or still holds a reported file.
3. Compare every other file under `deployed_file_hashes` in the old lock with its hash there. A file whose contents differ is a user edit. Every file under `deployed_file_hashes` in the new lock that exists in `~` but is absent from the old lock is a local file at a path the pull adds, so treat it as a user edit too. Copy each edited file to `/tmp/apm-edits/<path>`. Copy `agents/apm.yml` and `agents/apm.lock.yaml` into `~/.apm`, then run `apm install --global --force` from `~/.apm` to replace the files that the pull changed. Copy each edited file back and report it. `--force` overwrites edited files too, so the copy is what keeps the user's version. This step is done when the command exits with code 0 and every edited file holds the contents it had before the command.
4. Run `make -C ~ agents:sync`. This step is done when it exits with code 0, its output has no "Skipped" or "Kept user-edited file" line for a file you didn't report, and `git status` shows no change in `agents/`.

## Check the update

- Every file that the pull removed from the lock is gone from `~`, or the report names it as edited. No folder was deleted with files in it.
- Every file under `deployed_file_hashes` in the new lock matches its hash, or the report names it as edited.
- `make -C ~ agents:sync` exited with code 0, and `agents/apm.lock.yaml` did not change.
