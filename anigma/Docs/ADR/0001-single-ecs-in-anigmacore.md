# ADR-0001: Single ECS in AnigmaCore

> **Status:** Accepted  
> **Date:** 2025-12-06  
> **Supersedes:** None  
> **Superseded by:** None

---

## Context

Multiple legacy repositories each developed their own ECS-like patterns:

- **Harmonia/OrchestrumCore**: Actor-based World, UInt64 entity IDs, component storage via dictionaries
- **Apertum_Accesum**: UUID-based EntityId, WorldProtocol abstraction, persistence hooks
- **Outlineum**: Python ECS with dataclass components, system ordering

This fragmentation caused:
- Duplicated code and concepts
- Inconsistent APIs between projects
- Difficulty sharing components and systems across domains
- Higher maintenance burden

---

## Decision

**AnigmaCore provides the single ECS implementation for the entire Anigma ecosystem.**

The design consolidates the best patterns from legacy implementations:

| Aspect | Decision | Source |
|--------|----------|--------|
| Entity ID | UUID-based `EntityId` struct | Apertum Accesum (persistence-friendly) |
| World | Actor for thread safety | Harmonia (proven pattern) |
| Component | Protocol with Sendable, typically Codable | Both (merged) |
| System | Protocol with async `update(world:)` | Both (merged) |
| Component Storage | Type-erased dictionary per component type | Harmonia (efficient) |
| Queries | Multi-arity query methods | Both (merged API) |

Domain modules (HarmoniaModule, AltMediaModule, AccessumModule, OutlineumModule) **must not**:
- Define their own World or Engine types
- Define their own Component or System protocols
- Create parallel entity ID types

Domain modules **may only**:
- Define component structs conforming to `AnigmaCore.Component`
- Define system structs conforming to `AnigmaCore.System`
- Register systems and workflows with AnigmaCore infrastructure

---

## Rationale

### Why Single ECS?

1. **Consistency**: One set of APIs, one mental model
2. **Interoperability**: Components from any module work in the same World
3. **Maintenance**: Bug fixes and improvements benefit all modules
4. **Testing**: Shared test infrastructure and patterns

### Why Actor-Based World?

Swift concurrency with actors provides:
- Thread safety without manual locking
- Clear ownership semantics
- Integration with async/await

### Why UUID EntityId?

- Globally unique without coordination
- Serializable for persistence
- Human-readable in logs
- Compatible with network distribution

### Alternatives Considered

1. **Keep separate ECS per module**: Rejected (defeats purpose of unification)
2. **Integer entity IDs**: Rejected (harder to persist, coordinate, debug)
3. **Class-based World**: Rejected (harder to make thread-safe)

---

## Consequences

### Positive

- All modules share one proven ECS implementation
- Cross-module component queries become possible
- Reduced code duplication
- Consistent developer experience

### Negative

- Legacy repos need migration to new API
- Some legacy patterns may not map cleanly
- Learning curve for developers used to old APIs

### Neutral

- AnigmaCore becomes a critical dependency for all modules

---

## Migration

### From Harmonia/OrchestrumCore

```swift
// Before
import OrchestrumCore
let entity = Entity(id: 1)  // UInt64

// After
import AnigmaCore
let entity = EntityId()  // UUID-based
```

Key changes:
- `Entity` type → `EntityId`
- World API mostly compatible
- Move domain components to HarmoniaModule

### From Apertum_Accesum

```swift
// Before
import ApertumCore
let id = EntityID()
world.setComponent(id, component)

// After
import AnigmaCore
let id = EntityId()
await world.addComponent(id, component)
```

Key changes:
- `EntityID` → `EntityId` (typealias available)
- Sync methods → async methods
- `WorldProtocol` → use `World` actor directly

### From Outlineum (Python)

Complete reimplementation in Swift:
- Python dataclasses → Swift structs conforming to Component
- Python System classes → Swift structs conforming to System
- Python World → AnigmaCore.World

---

## References

- Constitution: `Docs/AnigmaConstitution.md` Section 2.1
- Core types: `Sources/AnigmaCore/ECS/`
- Implementation rules: `Docs/ImplementationRules.md`
