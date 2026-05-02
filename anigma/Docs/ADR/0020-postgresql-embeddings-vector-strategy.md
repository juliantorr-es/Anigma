# ADR-0020: PostgreSQL Embeddings and Vector Strategy

> **Status:** Proposed
> **Date:** 2026-04-22
> **Supersedes:** None
> **Superseded by:** None

---

## Context

Embeddings and vector search are currently split across several shapes:

- embedding generation is handled by runtime systems
- vector persistence exists in PostgreSQL-compatible forms
- some search paths still compute similarity in Swift
- module behavior can diverge between fallback row storage and native PostgreSQL vector usage

The codebase needs one canonical PostgreSQL strategy for embeddings, vectors, and retrieval so we do not keep two parallel search architectures alive.

---

## Decision

Adopt one canonical PostgreSQL strategy for embeddings, vector storage, and vector-assisted retrieval.

### Strategy Rules

1. The repository uses one documented vector strategy for database-backed embeddings.
2. pgvector is the preferred canonical backend where native vector search is needed.
3. If a module uses a fallback representation, that fallback must be explicit and temporary.
4. Search ranking strategy must be shared, not re-implemented module by module.
5. Embedding persistence schema is shared across CLI and runtime surfaces.
6. Vector search integration must be testable against live PostgreSQL.

### Required Behavior

- Embedding records use one canonical schema.
- Similarity search is not split into incompatible code paths without explicit exception tracking.
- Any non-native representation exists only as a deliberate bridge, not a second strategy.

---

## Rationale

- Embedding/vector logic is one of the easiest places for module drift to reappear.
- PostgreSQL can support native vector features, but only if the repository commits to one strategy.
- Shared schema and retrieval behavior make the CLI, runtime, and tests much easier to align.

---

## Consequences

### Positive

- One vector path to test and optimize.
- Easier eventual adoption of pgvector-native queries.
- Less duplicated similarity logic.

### Negative

- Existing module-local vector helpers will need consolidation.
- A fallback representation may have to be retired or clearly marked as transitional.

---

## References

- [ADR-0017: Single Master PostgreSQL System of Record](/Users/user/Developer/GitHub/Anigma_clean/anigma/Docs/ADR/0017-single-master-postgresql-system.md)
- `td-fb3cea` Canonical PostgreSQL embeddings and vector strategy
- `td-cdc32a` Unify PostgreSQL strategy across codebase
- `td-caed1c` Migrate vector store and CLI surfaces to PostgreSQL

