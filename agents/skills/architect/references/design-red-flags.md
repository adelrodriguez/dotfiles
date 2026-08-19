# Design red flags

## Shallow modules

A shallow module exposes a large interface while hiding little complexity. Callers coordinate several methods, choose internal stages, or still need to understand the implementation.

Prefer a small coherent interface that owns the complete operation. Do not confuse a deep module with a deep call chain: deep modules concentrate knowledge; deep call chains scatter it.

## Information leakage

Representation, storage, framework, transport, or protocol decisions appear across several modules. Changing one decision requires coordinated edits in unrelated places.

Parse external forms into domain types at a boundary. Keep internal representations and policies private unless consumers genuinely own them.

## Temporal decomposition

Modules are split by execution order rather than knowledge ownership. Separate load, validate, transform, and save layers often repeat one representation and its invariants.

Group behavior around the domain decisions it protects, even when methods execute at different times.

## Pass-through layers

A method forwards the same arguments and result without adding policy, adaptation, ownership, or a distinct abstraction. Remove the layer or move responsibility to the module that can complete the operation.

## Invalid-state escape hatches

The design relies on casts, broad option bags, loosely related optional fields, stringly typed states, or comments explaining which combinations are legal. Encode the invariant in data structures and constructors.

## Shared-state reflexes

The first concurrency answer is a lock, queue, or global coordinator without asking whether actors can own separate state. Eliminate unnecessary sharing before serializing access.
