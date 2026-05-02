# 03: Core ECS Pattern: Implementation Deep-Dive

## Entity Management
- **EntityId**: A `UUID`-backed struct. Entity destruction is deferred, pending observer notifications (`entityDestroyed` on `WorldObserver`).
- **Storage**: `ComponentStorage<C>` uses a `[EntityId: C]` dictionary. This is O(1) for lookup, but O(N) for multi-component joins.
- **Join Logic**: Multi-arity queries (`query<C1, C2>`) perform a nested iteration, starting from the smallest storage to minimize complexity.

## Actor Isolation & Safety
- **World**: A global actor protecting all entity metadata. 
- **System Execution**: Registered systems are wrapped in `AnySystem`, allowing the world to handle synchronous and asynchronous logic execution uniformly.
- **Race Condition Prevention**: All component writes (`set`, `remove`) are executed within the `World` actor context, preventing concurrent entity state corruption during update cycles.
