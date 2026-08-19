---
name: maintain-verification-skill
description: Audit and repair a project-local verification skill while preserving its harness-agnostic behavior and evidence contracts. Use when a verify skill, feature map, or adapter may have drifted from the product.
---

# Maintain a verification skill

Keep a project-local verification skill honest without making its feature definitions depend on the current harness. Audit behavior, evidence, and adapter mappings separately.

## Outcomes

Choose one:

- **clean:** Every feature received source and live coverage; no correction is needed.
- **changed:** Proven corrections were made within the verification skill.
- **blocked:** Coverage could not finish safely. Name the exact missing capability or prerequisite.

## Scope

Only edit the verification skill directory, including its feature map and owned adapter scripts. Do not edit product code. Treat broken product behavior as a reported product gap, not documentation drift.

Do not commit, push, or open a pull request unless the user explicitly asks.

## Pass

### 1. Locate and validate the target

Find the project-local `verify-*` skill, normally under `.agents/skills/`. If several exist, ask which one. If none exists, stop and recommend `create-verification-skill`.

Confirm that the skill separates:

- behavior and proof requirements;
- capability requirements;
- current adapter mappings.

If feature intent contains harness-specific commands, move those commands into `Current adapter mapping` without changing the behavior being verified.

### 2. Check index and source coverage

Reconcile the feature index with its files. For each feature, inspect source and documentation to identify entry points, observable behavior, prerequisites, and likely drift. Use parallel read-only agents when available, but do not require a particular agent runtime.

Flag a missing feature only with a concrete source or documentation path.

### 3. Audit capabilities and adapters

For every required capability, verify that the selected adapter still provides it:

- launch or invoke;
- readiness or preflight;
- perform user or consumer actions;
- observe results;
- capture durable evidence;
- reset state;
- clean up owned resources.

Prefer repairing an existing adapter. Replace it only when it no longer provides the contract reliably. A replacement must not force behavior or evidence descriptions to change unless the product contract changed too.

### 4. Run the live pass

Exercise every mapped feature at least once through its real user or consumer surface. Follow the verification skill's lifecycle model, whether that means one long-lived instance or isolated short-lived invocations.

Maintain these invariants:

1. Run the doctor procedure before the first action and after surprising failures.
2. Drive only instances and state owned by the verification run.
3. Preserve evidence across resets and cleanup.
4. Clean residue from failed attempts.
5. Confirm side effects through an independent observation when the feature contract requires it.

If an adapter fails, determine whether the problem is adapter drift, a missing capability, an unreachable prerequisite, or a product regression. Repair and re-run adapter drift once. Report product regressions without changing the map to match broken behavior.

### 5. Reconcile and report

Classify corrections as:

- **Behavior drift:** The documented user or consumer contract changed.
- **Evidence drift:** The proof no longer demonstrates the claimed result.
- **Adapter drift:** The mechanism no longer performs a required capability.
- **Product gap:** The product violates the still-valid contract.

Re-run every changed procedure. Report features covered, adapters used, replacements made, unreachable prerequisites, product gaps, evidence location, cleanup result, and the final outcome.
