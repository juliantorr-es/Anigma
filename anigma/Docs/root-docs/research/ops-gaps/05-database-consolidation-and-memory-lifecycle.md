> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Architectural Gap: Database Consolidation and Memory Lifecycle

**Gap ID:** database-consolidation-memory  
**Severity:** High  
**Scope:** Canonical storage, vector search, retention, lifecycle

## Gap statement

The database story is directionally clear, but the lifecycle of memory data is not fully defined: when to consolidate, when to cache, when to partition, when to compact, and when to add specialized stores.

## Research evidence

### Industry / official
- PostgreSQL supports partitioning, parallel-aware planning, memoize, and resource tuning.
- `shared_buffers` and `huge_pages` materially affect performance.
- Repo research recommends PostgreSQL + Redis as the primary stack, with DuckDB for analytics and pgvector for embeddings.

### Repo research
- `database-consolidation-patterns.md` prefers a unified database with specialized layers.
- `memory-backend-options.md` identifies embeddings, vector search, and backend selection as the key gaps.

## What industry does

The common progression is:

1. Start with PostgreSQL as the source of truth.
2. Add Redis for cache and ephemeral state.
3. Add vector search only when semantic retrieval is needed.
4. Add analytics stores only when query shape justifies them.

## Recommended solution

Use a **canonical stack**:

- PostgreSQL for system of record
- Redis for caching, queues, and coordination
- pgvector for embeddings / similarity search
- DuckDB for local analytics and reporting

Define a **memory lifecycle policy**:

- short-term memory expires by TTL
- long-term memory is tenant-scoped and compacted
- persistent memory is release-controlled
- embeddings are regenerated when model/version changes

## Design constraints

- Add new stores only when a measured bottleneck exists.
- Partition large tables before they outrun memory.
- Compact context before it becomes expensive to retrieve.

## Acceptance criteria

- The canonical stack is explicitly chosen.
- Memory tiers have retention and compaction policies.
- Vector search is supported without over-splitting the stack.
- Database growth has a partition and memory plan.