# Feature map template

Use this structure for each feature. Keep behavior and evidence stable when an adapter changes.

```markdown
# <Feature name>

<One paragraph describing user-visible or consumer-visible behavior.>

## Behaviors

- `<behavior-id>`: <observable behavior>

## User or consumer entry points

- <How a real user or consumer reaches this behavior.>

## Verification procedure

Preconditions:

- <Required state expressed without naming a harness.>

1. **<Action>.** <User or consumer action.>
   Expected observation: <Observable result.>
2. **<Independent confirmation>.** <Second observation when persistence or a side effect matters.>
   Expected observation: <Observable result.>

### Current adapter mapping

| Step | Capability | Invocation |
| --- | --- | --- |
| 1 | `<capability>` | `<project-specific command or procedure>` |

## Required evidence

- <Artifact or observation proving the action and result.>

## Gotchas

- <Condition that can invalidate or mislead a verification run.>
```

The adapter mapping may name any suitable mechanism. The rest of the file must remain meaningful if that mechanism is replaced.
