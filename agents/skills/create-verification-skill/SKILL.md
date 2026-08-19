---
name: create-verification-skill
description: Generate a project-local, harness-agnostic verification skill that proves behavior through a project's real user-facing surfaces. Use when a repository lacks a repeatable way to verify its application, service, CLI, library, or integration.
---

# Create a verification skill

Generate a project-local verification skill for the next agent to use cold. The skill defines what must be launched, driven, observed, proved, isolated, and cleaned up without coupling those requirements to a particular browser driver, test runner, shell wrapper, agent, or vendor.

## 1. Interview the repository

Answer these from the repository before asking the user:

- **Surfaces:** What does a user or consumer touch: UI, CLI/TUI, desktop app, API, mobile app, library API, protocol, package artifact, or several of these?
- **Run:** How does each relevant surface start? Prefer documented project commands. Record environment, seed data, authentication, ports, and readiness signals.
- **Capabilities:** How can automation perform actions, observe results, reset state, and stop what it started?
- **Existing adapters:** Which project tools already provide those capabilities? Prefer existing scripts, tests, debug protocols, package examples, and standard command-line interfaces.
- **Evidence:** Which observable artifacts prove behavior: responses, output, exit status, screenshots, accessibility snapshots, files, package contents, persisted records, logs, or events?
- **Isolation:** Which ports, directories, profiles, accounts, namespaces, or process IDs prevent concurrent runs from sharing state?

Do not pick a harness by habit. Select the smallest adapter set that exposes the required capabilities. Different surfaces may use different adapters in one verification run.

If the repository cannot build or start, repair that only when it is within the user's requested scope. Otherwise report the blocker instead of generating instructions against a broken baseline.

## 2. Define the verification contract

Create `.agents/skills/verify-<project>/SKILL.md`. Include valid frontmatter and these sections:

- **Scope:** Surfaces and behaviors covered, plus explicit exclusions.
- **Preconditions:** Required build, environment, fixtures, credentials, and isolation.
- **Adapters:** A capability table with `Capability`, `Selected mechanism`, `Invocation`, and `Fallback or limitation`. Cover launch, readiness, action, observation, evidence capture, reset, and cleanup. Name tools only here so an adapter can be replaced without rewriting feature intent.
- **Launch:** Exact commands, ownership markers, readiness checks, and teardown. Short-lived programs may launch once per action instead of maintaining an instance.
- **Doctor:** One read-only procedure that identifies the target, build or version, ownership, dependencies, and whether it is safe to drive.
- **Verification procedure:** How to execute an action and observe its result through real user or consumer surfaces. Prefer stable semantic handles over coordinates, timing assumptions, or internal implementation details.
- **Evidence:** What each proof must capture and where durable artifacts go. Capture the action and resulting state. Confirm side effects independently when they are part of the contract.
- **Cleanup:** Stop only owned resources and remove scratch state without deleting evidence.
- **Limitations:** Unavailable surfaces, unsafe operations, shared resources, and cases requiring manual verification.

The generated skill may include adapter scripts, but scripts are optional. Every included helper must be executable, documented, replaceable, and limited to translating the capability contract into project-specific actions.

## 3. Seed a harness-agnostic feature map

Create `features/README.md` and one file for each of the three to five most important user-facing features. Follow [`references/feature-map-template.md`](references/feature-map-template.md).

Feature files describe intent independently of tooling. Each contains:

1. `Behaviors`
2. `User or consumer entry points`
3. `Verification procedure`
4. `Required evidence`
5. `Gotchas`

Use capability names from the parent skill, not commands tied to one harness. Put exact adapter invocations in a clearly labeled `Current adapter mapping` subsection so replacing an adapter does not alter the behavior or proof contract.

## 4. Prove the generated skill

Execute the generated instructions end to end:

1. Establish an isolated run.
2. Launch and pass the doctor procedure.
3. Verify one mapped feature through its real surface.
4. Capture the required evidence.
5. Clean up owned resources.
6. Confirm the evidence remains available.

Fix the skill or its owned adapter when the instructions fail. Clean up after every failed attempt. A generated skill that has not verified one feature is a draft.

## 5. Report

Report the generated path, selected adapters, feature exercised, evidence captured, limitations, and cleanup result. Do not commit, push, or open a pull request unless the user explicitly asks.
