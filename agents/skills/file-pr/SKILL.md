---
name: file-pr
description: File a concise pull request. Use when the user asks to file, open, or create a PR.
---

# File PR

- Before filing, check whether a PR for this branch already exists.
- Review the diff locally against `origin/main` to make sure its contents match the goal. Assume the PR is not part of a stack unless the user mentions a "stack"; when stacking, diff against the PR's base branch instead.

## Titles

PR titles usually become commit messages, so follow the repository's title conventions. Look at recently merged PRs and git history for examples. Prefer a concise, human-readable title that explains why the changes matter.

- Bad: `perf(server): negotiate per-message deflate on the websocket`
- Good: `perf(server): cut websocket frame size by 70% with per-message deflate`

## Descriptions

Open the description with a simple explanation of the problem, based on the user's original prompt, then briefly explain the solution. **Do not lead with an implementation inventory.**

- Bad: "Removed implicit workspace carryover from every new thread entry point. New threads inherit only the project from context; branch, worktree, audio…"
- Good: "My new worktree default was ignored when starting new threads on existing worktrees — super unintuitive. Now your preference is always applied."

Another good example:

> **fix(release): skip scripts during Vercel installs**
>
> The hosted web deployment runs its filtered Vercel install command twice. Both installs invoke the root `prepare` lifecycle, so the persistent build cache accumulated Effect TS backups until it hit the 100-file limit and blocked releases. Now we run installs with `--ignore-scripts`.

And another:

> Stashing a prompt, switching providers, and restoring it didn't work. The stash was bucketed per provider instance, so after a switch the badge disappeared and the stash looked lost. Restoring also dragged the stash's model selection back, defeating the point of moving a prompt to a different provider. Now the stash lives in one global bucket and restoring keeps whatever model is currently selected.

Add a blurb to the end of the PR description noting which model and harness made the changes.

## Drafts

Open a real PR, not a draft, so automatic reviews and deployments are triggered.

If the user also asked to monitor or babysit, continue with the monitor-pr skill.
