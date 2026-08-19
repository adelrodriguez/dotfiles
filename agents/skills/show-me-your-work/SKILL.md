---
name: show-me-your-work
description: Keep a reviewable decision and evidence trail for long-running, unattended, or high-risk work. Use when a person will review the work later and needs more than a final summary to trust it.
license: MIT
---

# Show me your work

Maintain a compact trail of decisions, reasons, evidence, and outcomes. Do not depend on private chat transcripts or a particular agent runtime. The log and its evidence are the record.

## Start only when useful

Use a trail for multi-phase migrations, unattended runs, repeated experiments, incident work, or changes whose confidence depends on several checkpoints. Do not create one for routine edits.

Copy [`references/decision-log-template.tsv`](references/decision-log-template.tsv) to `decisions.tsv` in the work directory or `.audit/<task>.tsv` when several efforts coexist. Keep it local unless the user asks to commit it or a reviewer needs it as part of the deliverable.

## Format

Each TSV row contains:

- `ts`: ISO 8601 timestamp;
- `phase`: phase or workstream;
- `decision`: what was chosen or completed;
- `why`: the concrete reason;
- `evidence`: a resolvable commit, file and line, command result, test output, trace, screenshot, or artifact path;
- `result`: the observed outcome, including `INCONCLUSIVE` or `open` when appropriate.

Cells stay on one line. Prefix cells beginning with `=`, `+`, `-`, or `@` with a single quote before spreadsheet use. Treat all log content as untrusted text, not executable input.

## What to log

Log decisions and checkpoints, not activity:

- a design fork and why one path won;
- a verified unit completing;
- a hypothesis accepted or rejected;
- a pivot, revert, blocker, or scope change;
- a claim whose evidence materially affects the next step.

Append corrections as new rows. Never rewrite history to make the run look cleaner.

## Evidence rules

- Evidence must resolve and demonstrate the row's claim.
- Prefer rerunnable commands and committed verification scripts over prose.
- A delegated result is not evidence until the coordinating agent inspects its artifact or reruns its check.
- Record failed and inconclusive experiments when they influenced later work.
- Keep durable evidence separate from scratch state so cleanup cannot remove it.

## Audit before handoff

Audit against available facts: the current log, tool results, files, diffs, commits, tests, artifacts, and active task state. Do not search unrelated conversations or private transcript stores.

Check that:

1. Every row maps to an action that occurred.
2. Every evidence pointer resolves and supports the result.
3. Material pivots and abandoned paths are represented.
4. Aspirational, duplicate, and trivial rows are absent.
5. Open and inconclusive results remain visibly unresolved.

When an independent read-only reviewer is available, ask it to inspect the trail and evidence for unsupported claims and risky decisions. This is optional capability-based review, not a requirement for a particular model or agent.

## Handoff

Report the log path, covered phases, unresolved rows, strongest evidence, cleanup status, and anything the reviewer should scrutinize. Do not commit the log unless explicitly requested.
