---
name: no-comments
description: Audit comments and suppressions for stale narration, hidden design debt, and constraints that should be encoded in code. Use when asked to review, reduce, or remove comments without losing essential rationale or public contracts.
license: MIT
---

# No comments

Review comments with fresh eyes. The goal is not zero comments; it is code that explains itself where possible and precise documentation where prose carries information code cannot.

Default to a read-only report. Apply accepted changes only when the user asks for edits.

## Scope

Use the files, diff, or commit range supplied by the user. Otherwise inspect the current change against its appropriate base, including relevant working-tree changes. Do not widen scope silently.

## Review independently

Use an independent read-only review pass when the active agent supports it, but do not require a named subagent or model. Inspect comments, doc comments, disabled code, TODOs, lint suppressions, type suppressions, and nearby implementation.

Classify each item:

- **Keep:** It preserves information code cannot express reliably.
- **Encode:** A type, name, function boundary, test, lint rule, runtime assertion, or generated metadata should enforce the claim.
- **Delete:** It is narration, stale history, commented-out code, boilerplate, duplication, or an unsupported warning.
- **Rewrite:** The information is necessary but inaccurate, vague, or much longer than the constraint requires.
- **Investigate:** The claim may protect behavior, but available evidence cannot yet prove whether it is current.

## Comments that normally survive

- legal and license headers;
- public API contracts and usage constraints;
- security boundaries and threat-model rationale;
- concurrency, ordering, and memory-model constraints not visible from local code;
- external platform, vendor, protocol, or compatibility behavior the repository cannot reshape;
- issue, specification, or decision links that preserve otherwise unavailable rationale;
- generated-code markers and tool directives;
- suppressions with a documented, current reason and the narrowest possible scope.

Ambiguity is not permission to delete. Investigate the symbol, history, tests, dependency behavior, or authoritative specification. If evidence remains unavailable, report the uncertainty.

## Suppressions

For every lint or type suppression:

1. Identify the exact rule or diagnostic.
2. Determine whether it protects correctness, security, compatibility, or style.
3. Try the narrowest root-cause correction.
4. Keep the suppression only when the rule is inapplicable or the correction would be worse, and require a precise reason.

Do not remove a suppression merely to make the diff cleaner.

## Root-cause improvements

When a comment compensates for confusing code, propose the smallest structural improvement: rename a symbol, introduce a domain type, extract a coherent operation, move validation to a boundary, add a test, or encode a machine-checkable rule.

Do not turn every comment into an abstraction. A short accurate explanation can impose less reader load than another layer.

## Output

Report findings ordered by risk with file and line references. Include:

- classification and rationale;
- proposed deletion, rewrite, or encoding;
- evidence supporting keeps and investigations;
- suppression details;
- counts by classification;
- residual uncertainty.

When editing was requested, apply only accepted findings, inspect the final diff, and run relevant checks. Never alter application behavior as an incidental comment cleanup.
