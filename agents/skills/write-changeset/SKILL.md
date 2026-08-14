---
name: write-changeset
description: Write or update a changeset entry for staged changes. Use when the user asks to write, add, or update a changeset.
---

# Write Changeset

Changesets are for the developers consuming the library, so write about what matters to them: new capabilities, fixed bugs, and breaking changes they need to handle.

## Workflow

1. Run `git diff --staged` to see the staged changes. If nothing is staged, ask the user to stage changes with `git add` first.
2. Check `.changeset/` for existing entries (ignore README.md) — update one if it covers this work, otherwise run `bun changeset --empty` to create a new one.
3. Determine the version bump and write the entry focused on user impact.

If the changes span unrelated features or fixes, create separate changesets. If nothing user-facing changed, skip the changeset entirely — no need to document internal shuffling.

## Version bumps

- **Major**: Breaking changes. Something that worked before won't work anymore without code changes.
- **Minor**: New features. Additive changes that don't break existing usage.
- **Patch**: Bug fixes, performance improvements, dependency updates.

If we're still in a v0, do not propose a major unless the user explicitly asks for it.

## Writing style

Write like you're part of the team shipping this change. Direct, technical, no fluff.

- Bad: "This changeset updates the internal implementation to improve code organization" (users don't care)
- Bad: "The system has been enhanced to provide improved functionality" (vague corporate speak)
- Good: "Fix race condition in file watcher when multiple saves occur rapidly"
- Good: "Add `--dry-run` flag to preview changes without writing files"

Include features users can actually use, bugs that were affecting them, breaking changes with migration guidance, and performance improvements they'll notice. Skip internal refactoring, code reorganization, test-only changes, and cosmetic cleanups. If a change is mostly internal cleanup with a small user-facing fix bundled in, just write about the fix.

## Format

```markdown
---
"package-name": patch
---

Fix lint command failing when config file contains comments
```

For bigger changes, add context:

```markdown
---
"package-name": minor
---

Add `--watch` mode for continuous file monitoring

Runs the command once, then re-runs whenever source files change. Uses filesystem events when available, falls back to polling on unsupported platforms.
```
