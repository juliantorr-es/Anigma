# 11: Concurrency Model: Deep-Dive

## Actor Isolation
- **`World` Actor**: Global authority for entity registry and component storage. Any modification to the `World` must be awaited to prevent race conditions during component joins.
- **System Actor**: ECS Systems conform to `AsyncSystem`. Each system runs its `update()` logic within its own actor scope, enabling concurrent processing of disjoint systems.
- **Non-isolated State**: Restricted to immutable constants or thread-local registries.

## Memory Safety
- **`@Sendable`**: Strictly enforced. All components crossing actor boundaries must be `Sendable`.
- **Native Interop**: Native (C/C++) memory wrappers must explicitly synchronize with Swift Concurrency, typically using `checkedContinuation` or `withTaskGroup` when bridging asynchronous work.
