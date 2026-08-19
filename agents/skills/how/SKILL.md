---
name: how
description: Explain how a subsystem, feature flow, or module works from source evidence. Use for code walkthroughs, runtime traces, ownership questions, layering questions, and architectural critiques.
license: MIT
---

# How

Build a working mental model from the codebase. Explain the system at the level needed to change it safely, not as annotated source code.

## Choose the mode

- **Explain** is the default. Describe architecture and runtime behavior without judging the design.
- **Critique** applies only when the user asks for problems, risks, or improvements. Explain first, then critique.

## Scope the question

State a reasonable interpretation when the question is ambiguous and continue unless a wrong interpretation would waste substantial work. Identify whether the answer is:

- local to one symbol or module;
- a flow spanning several components;
- a cross-cutting subsystem or ownership question.

Use the smallest exploration strategy that can answer the question. Read directly for local questions. For broad questions, divide exploration by distinct concerns such as entry points, state, control flow, external boundaries, and observability.

## Explore from evidence

Parallelize independent exploration when the active agent supports it, but do not require a particular model, agent type, or tool. Every exploration pass must:

1. Find concrete entry points, important types, and ownership boundaries.
2. Trace callers, callees, state changes, and effects from trigger to observable result.
3. Read implementations rather than infer behavior from names.
4. Identify validation, retries, concurrency, persistence, and external boundaries when relevant.
5. Record exact file and symbol references.
6. Mark uncertainty instead of filling gaps with plausible behavior.

Reconcile contradictions against source. Use runtime evidence when static inspection cannot settle behavior.

## Explain

Adapt this structure to the question:

- **Overview:** What the subsystem does and where its boundary lies.
- **Key concepts:** Only the types, services, or abstractions required for the mental model.
- **How it works:** A trigger-to-result walkthrough with decision points and state transitions.
- **Where it lives:** The few files and directories a maintainer should open first.
- **Gotchas:** Surprising behavior, hidden coupling, operational constraints, and unresolved uncertainty.

Reference concrete files and symbols. Include snippets only when prose cannot communicate the mechanism precisely.

## Critique

Explain the system before evaluating it. Then inspect:

- whether ownership and boundaries match the knowledge each module holds;
- whether callers coordinate internals that should be hidden;
- whether state, ordering, or concurrency assumptions are implicit;
- whether validation and error translation occur at appropriate boundaries;
- whether abstractions reduce or merely relocate reader effort;
- whether tests and observability prove the important behavior.

Use independent review passes when available. Synthesize findings as:

- **Act on:** Concrete correctness, security, operability, or maintainability problems.
- **Consider:** Real tradeoffs whose benefit may not justify change now.
- **Noted:** Valid but low-impact observations.
- **Dismissed:** Incorrect or context-free suggestions, with a short reason.

Keep the explanation usable on its own before presenting critique.
