# ADR-0021: PostgreSQL Boundary and Instantiation Rule

> **Status:** Proposed
> **Date:** 2026-04-22
> **Supersedes:** None
> **Superseded by:** None

---

## Context

The low-level `DatabaseActor` still exists as the PostgreSQL implementation, but several modules instantiate it directly. That makes the database layer harder to govern because connection details, transaction assumptions, and schema lifecycle concerns leak into feature code.

The repository needs a clear boundary so the actor remains available without becoming a module-local integration pattern.

---

## Decision

Allow direct low-level PostgreSQL actor instantiation only in approved composition roots.

### Boundary Rules

1. Composition roots may construct the actor/client wrapper.
2. Feature and capability modules **must strictly** consume `DatabaseAuthority` (or its adapter interfaces).
3. The `DatabaseActor` is an invisible **adapter** sitting behind the `DatabaseAuthority` seam. Direct instantiation or calling of `DatabaseActor` in feature modules is strictly prohibited.
4. Modules should not depend on actor internals for persistence behavior.
5. Instantiation boundaries must remain narrow enough to support testing, governance, and future refactoring.

### Approved Intent

- The actor is an implementation detail of the shared PostgreSQL stack.
- The actor is not the preferred module-level API.

---

## Rationale

- Narrow boundaries reduce architecture drift.
- Centralized instantiation makes policy enforcement easier.
- The runtime becomes easier to test with mocks and live fixtures if feature code depends on abstractions rather than construction details.

---

## Consequences

### Positive

- Less direct coupling to connection implementation details.
- Easier to swap or refine the low-level Postgres stack.
- Cleaner module ownership boundaries.

### Negative

- Some existing module code will need to be rewritten to use injected contracts.
- Direct construction patterns must be reviewed and possibly removed.

---

## References

- [ADR-0017: Single Master PostgreSQL System of Record](/Users/user/Developer/GitHub/Anigma_clean/anigma/Docs/ADR/0017-single-master-postgresql-system.md)
- `td-9d55c9` Capability-boundary cleanup and direct DatabaseActor removal
- `td-cdc32a` Unify PostgreSQL strategy across codebase

