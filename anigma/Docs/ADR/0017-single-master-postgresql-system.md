# ADR-0017: Single Master PostgreSQL System of Record

> **Status:** Proposed
> **Date:** 2026-04-22
> **Supersedes:** None
> **Superseded by:** None

---

## Context

SQLite removal made the repository textually PostgreSQL-only in tracked live code, but the architecture is still split across module-specific persistence shapes, compatibility shims, and varying levels of query abstraction. Without a shared end-state, individual modules can drift into their own persistence conventions and reintroduce duplication around connection handling, migrations, vector/search handling, and operational checks.

The implementation effort needs a clear target shape so that the PostgreSQL work converges on one system of record instead of many module-local database patterns.

---

## Decision

Adopt a **single master PostgreSQL system of record** for Anigma.

This means:

1. One authoritative PostgreSQL backend for tracked runtime state.
2. One shared connection, transaction, and bootstrap contract.
3. One canonical schema/migration model.
4. One canonical PostgreSQL strategy for embeddings, vectors, and search where those capabilities live in the database.
5. Multiple bounded logical schemas or namespaces on top of the same PostgreSQL system.
6. Module-specific adapters are allowed, but module-specific competing persistence engines are not.

### Boundary Rule

PostgreSQL owns:

- relational truth
- metadata and registries
- receipts and audit-visible records
- queue state and coordination primitives
- queryable search/index state
- bounded embedding/vector state when database-backed search is the right fit

PostgreSQL does not own:

- large sealed artifact bytes by default
- GPU residency or memory atlas layout
- per-frame runtime state
- feature-local storage engines that duplicate the canonical backend

### Operational Shape

- Composition roots may construct the low-level `DatabaseActor` or client wrapper.
- Feature modules should consume narrow authorities or `DatabaseExecutor`-style contracts.
- Migrations and schema bootstrap must be shared, versioned, and verifiable.
- PostgreSQL features should be used intentionally, not accidentally:
  - transactions
  - savepoints
  - RLS
  - advisory locks
  - `COPY`
  - `SKIP LOCKED`
  - `JSONB`
  - `GIN` / partial indexes
  - `LISTEN` / `NOTIFY` where queueing or eventing needs it

---

## Rationale

1. A single authoritative backend reduces duplication and hidden drift.
2. Shared contracts make it possible to improve PostgreSQL usage once and benefit many modules.
3. The repo already has enough PostgreSQL surface to justify a convergence target.
4. Embeddings, vector search, and operational features need a deliberate canonical strategy instead of ad hoc module-level decisions.
5. The architecture becomes easier to verify if composition roots are the only place where the low-level database actor is instantiated.

---

## Consequences

### Positive

- Shared database behavior across the codebase.
- Less duplicated setup, migration, and search logic.
- Clearer test strategy for live PostgreSQL verification.
- Easier to reason about security, RLS, and operational drills.

### Negative

- Requires coordinated refactoring across multiple modules.
- May force some features to move from local helpers to shared authorities.
- Raises the bar for schema discipline and migration hygiene.

### Neutral

- Module adapters may remain, but only as thin wrappers over the shared backend.
- The low-level actor still exists, but its ownership is narrowed to approved composition roots.

---

## References

- [td-89a996 - PostgreSQL First-Class Implementation Epic](../../architecture-guides/EPIC_POSTGRESQL_FIRST_CLASS.md)
- [PostgreSQL First-Class Capability Audit Matrix](../../architecture-guides/POSTGRESQL_FIRST_CLASS_CAPABILITY_AUDIT_MATRIX.md)

- [PostgreSQL First-Class Capability Audit Matrix](/Users/user/Developer/GitHub/Anigma_clean/anigma/Docs/architecture-guides/POSTGRESQL_FIRST_CLASS_CAPABILITY_AUDIT_MATRIX.md)
- [ADR-0018: PostgreSQL Connection and Transaction Contract](/Users/user/Developer/GitHub/Anigma_clean/anigma/Docs/ADR/0018-postgresql-connection-and-transaction-contract.md)
- [ADR-0019: PostgreSQL Schema Bootstrap and Migration Contract](/Users/user/Developer/GitHub/Anigma_clean/anigma/Docs/ADR/0019-postgresql-schema-bootstrap-and-migration-contract.md)
- [ADR-0020: PostgreSQL Embeddings and Vector Strategy](/Users/user/Developer/GitHub/Anigma_clean/anigma/Docs/ADR/0020-postgresql-embeddings-vector-strategy.md)
- [ADR-0021: PostgreSQL Boundary and Instantiation Rule](/Users/user/Developer/GitHub/Anigma_clean/anigma/Docs/ADR/0021-postgresql-boundary-and-instantiation-rule.md)
- `td-d3be16` PostgreSQL First-Class Capability Integration Track
- `td-cdc32a` Unify PostgreSQL strategy across codebase
