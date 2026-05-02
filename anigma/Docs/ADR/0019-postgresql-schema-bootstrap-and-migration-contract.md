# ADR-0019: PostgreSQL Schema Bootstrap and Migration Contract

> **Status:** Proposed
> **Date:** 2026-04-22
> **Supersedes:** None
> **Superseded by:** None

---

## Context

The repository has many schema creation and migration entry points, but they do not yet converge on one formally defined PostgreSQL migration contract. Some surfaces still bootstrap schema opportunistically, and bootstrap validation is not yet strong enough to prove the live PostgreSQL shape is correct.

If each module keeps its own schema habits, the codebase will drift back into duplicated setup and incompatible migration assumptions.

---

## Decision

Adopt one shared PostgreSQL schema bootstrap and migration contract.

### Contract Rules

1. Schema versioning is repository-wide, not module-local.
2. Bootstrap order is explicit and deterministic.
3. Migration application is idempotent and auditable.
4. Validation checks the live PostgreSQL catalog, extensions, and required objects.
5. Rollback and recovery drills are part of the contract, not an afterthought.
6. Modules register schema needs through shared contracts rather than creating their own migration worlds.

### Required Behavior

- Schema bootstrap can prove the target database is ready for runtime.
- Migration steps can be replayed, audited, and rolled forward safely.
- Drift detection is part of the verification story.

### Canonical Runtime Contract

`DatabaseCore.PostgresSchemaBootstrapContract` is the executable form of this ADR.

- `PostgresMigrationStep` defines repository-wide migration order, module owner, required live objects, and rollback or recovery expectations.
- `PostgresSchemaBootstrapContract.canonical()` defines the shared bootstrap sequence for the schema registry, runtime job tables, receipt tables, artifact tables, and vault tables.
- `validateLiveCatalog(using:)` checks the live PostgreSQL catalog through `DatabaseExecutor` for applied contract version, required tables, and required extensions.
- Module-local schema setup must either register through this contract or remain a narrow adapter over it.

---

## Rationale

- A single migration contract prevents schema divergence.
- Live catalog validation is necessary for a PostgreSQL-first-class system.
- Rollback and recovery planning are part of operational maturity, not optional extras.

---

## Consequences

### Positive

- Shared bootstrap logic.
- More reliable deployment and cutover behavior.
- Easier to reason about schema drift.

### Negative

- Existing module-local schema setup will need consolidation.
- Migration tooling must become a first-class part of the runtime story.

---

## References

- [ADR-0017: Single Master PostgreSQL System of Record](/Users/user/Developer/GitHub/Anigma_clean/anigma/Docs/ADR/0017-single-master-postgresql-system.md)
- `td-70ce4e` Canonical PostgreSQL schema bootstrap and migration contract
- `td-d80f2b` Schema bootstrap, migrations, and validation runner
