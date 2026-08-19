---
name: interrogate
description: Run an adversarial, independent review of a diff or code selection and synthesize a lead verdict. Use when asked to challenge, stress-test, interrogate, tear apart, or find blind spots in code or a design.
license: MIT
---

# Interrogate

Challenge a change from independent angles, then apply lead judgment. The deliverable is a review verdict. Do not edit code unless the user separately asks to address accepted findings.

## 1. Establish scope and intent

Use the user-provided diff, files, commit range, branch comparison, or design. Include only the surrounding context needed to evaluate it.

Write one paragraph stating what the work intends to accomplish. Derive it from the request, specification, commit history, pull-request description, and code. Ask only when competing interpretations would produce materially different reviews.

## 2. Run independent reviews

Run three independent read-only reviews when parallel agents or separate review contexts are available. Two are enough for a small change. If only one review context exists, perform one rigorous pass and state that agreement could not be measured.

Give every reviewer the same intent, scope, evidence, and rubric. Do not assign theatrical personas. Independence should come from separate reasoning passes, not different standards.

Each reviewer checks:

- correctness, edge cases, failure modes, concurrency, and cleanup;
- security, trust boundaries, validation, and information exposure;
- compatibility, public contracts, serialization, packaging, and downstream consumers;
- whether tests prove the intended behavior and important regressions;
- unnecessary complexity, shallow abstractions, hidden coupling, and reader load;
- scope drift, speculative infrastructure, dead compatibility paths, and missing deletion;
- repository-specific standards and documented constraints.

Every finding must include severity, location, failure scenario, evidence, and the smallest credible correction. Reviewers must distinguish observed defects from questions and preferences.

## 3. Synthesize

Deduplicate findings by underlying failure. Track which independent passes found each issue. Agreement raises confidence but does not replace evidence; one well-proven finding can outrank weak consensus.

Resolve disagreements by checking source, tests, runtime behavior, or authoritative documentation. Do not decide by vote.

## 4. Apply lead judgment

Classify every finding:

- **Act on:** A demonstrated correctness, security, compatibility, or maintainability problem that should block the change.
- **Consider:** A legitimate concern with an uncertain cost-benefit tradeoff.
- **Noted:** Valid context with little immediate action value.
- **Dismissed:** Incorrect, unsupported, duplicative, or purely stylistic.

## Output

Present:

1. **Intent**
2. **Review coverage** including the number of independent passes and any limitations
3. **Act on** findings ordered by severity
4. **Consider**
5. **Noted**
6. **Dismissed** with brief reasons
7. **Agreement map** describing corroboration and meaningful disagreements

Findings come first. If no actionable issue survives lead review, say so and name residual testing or context gaps.
