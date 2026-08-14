---
name: monitor-pr
description: Monitor a pull request through review and CI. Use when the user asks to monitor, watch, or babysit a PR.
---

# Monitor PR

All the repos we work in have at least one AI review bot. They've given helpful but sometimes unreliable feedback. Your job is to drive the PR to green and approved by all the bots.

## Monitoring

- If your harness offers tools to monitor a PR, use them so you can respond when comments arrive. Otherwise, poll the PR for new comments and checks.
- Mark comments as resolved if they are no longer relevant or have been addressed.
- Verify every bot finding against the source before changing code.
- Fix real findings and CI failures. Distinguish repository failures from infrastructure flakes.
- If a bot finding is a false positive or not worth addressing, reply with a written reason and resolve the comment.
- Keep an eye on changes to `main` and rebase when needed so the PR stays fresh. Always rebase — never merge `main` in — and force-push with `--force-with-lease`.
- If an overlapping PR makes this one obsolete, stop monitoring, report to the user, and ask before closing — unless closure was explicitly authorized.

## Scope

Do not let review feedback expand the PR beyond the user's original goal. Address real shortcomings, but avoid scope creep.

## Commenting on the user's behalf

Never leave a comment from the user's account without indicating it came from an agent. Format comments left on Adel's behalf as:

> **`model-slug` (on behalf of Adel):**
>
> Actual reply.

<!-- Disabled until startline is ready.

## Media

Screenshots and videos help reviews. Upload them with the startline-publish skill and embed the public URL in the PR. Don't fight GitHub's native upload.

-->

## Success criteria

Loop until the PR is green and approved by all review bots. Do not monitor or wait on human reviewers.
