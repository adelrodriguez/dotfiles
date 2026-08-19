---
name: architect
description: Design caller usage, types, signatures, and module boundaries before implementation. Use for durable APIs, cross-module changes, ownership decisions, or work where coding first could lock in the wrong shape.
license: MIT
---

# Architect

Settle the shape before filling in implementation. Start from caller experience and domain constraints, compare genuinely different designs, and treat implementation friction as evidence that the design may be wrong.

Respect the requested scope. Produce only a design when the user asks for architecture; continue into implementation only when implementation is requested.

## 1. Ground

Trace every existing subsystem the design touches:

- current callers and user-facing behavior;
- ownership, state, and data flow;
- public and persisted contracts;
- validation and effect boundaries;
- compatibility constraints and expected migration path.

For greenfield work, ground in user needs, runtime constraints, and repository conventions instead. Record uncertainty explicitly.

## 2. Write caller usage first

Sketch two or three realistic call sites before defining types. Include normal use, an important failure path, and composition with surrounding code. The API exists to make these call sites clear and difficult to misuse.

## 3. Compare designs

For durable or one-way decisions, produce at least two structurally different candidates. Small local changes may use one candidate plus one rejected alternative.

Each candidate includes:

- caller usage;
- core data types and invariants;
- function or method signatures;
- module ownership and dependency direction;
- validation, error, state, and concurrency boundaries;
- migration and deletion steps;
- accepted tradeoffs.

Use independent design passes when available, without requiring a particular model or orchestration tool. Screen candidates with [`references/design-red-flags.md`](references/design-red-flags.md).

## 4. Choose and record

Prefer the design that hides necessary complexity behind the smallest coherent interface. Reject designs that are merely easier to implement but harder to call, test, or change.

Write the decision using [`references/rationale-template.md`](references/rationale-template.md). Name what was taken from alternatives and why the others lost.

Pause for approval only when the user requested a checkpoint or when the decision is irreversible outside the repository. Otherwise continue within the requested scope.

## 5. Implement and test the shape

When implementation is requested, establish the selected types, signatures, and module boundaries before filling in behavior. Keep each step verifiable.

Record deviations from the sketch. A missing parameter or awkward edge case may be an implementation detail; repeated casts, optional fields that are always required, pass-through layers, shared-state locks, or caller knowledge of internals indicate a design problem.

## 6. Redesign when evidence changes

Do not protect a failing sketch with compatibility wrappers or special cases. When the same workaround appears in multiple places:

1. Capture the newly learned constraint.
2. Remove scaffolding tied to the rejected shape.
3. Redesign as if the constraint had existed from the start.
4. Re-run the comparison and verification.

Report the chosen shape, alternatives, tradeoffs, open risks, implementation deviations, and verification evidence.
