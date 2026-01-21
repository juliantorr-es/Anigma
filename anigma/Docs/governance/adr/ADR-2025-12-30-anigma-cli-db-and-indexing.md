# ADR: Anigma CLI DB and Indexing (2025-12-30)

## Context
- Anigma CLI needs local-first persistence for runs, receipts, leases, and indexing without adding a new database layer.
- DatabaseCore already provides GRDB-backed SQLite with FTS5-enabled schema files (`Sources/DatabaseCore/Schema_*.sql`); CodeIndexStore.swift uses FTS5 for lexical search.
- Hybrid retrieval (lexical + vector) is required to serve CLI search and tool routing.

## Decision
- Reuse DatabaseCore as the sole persistence layer; no additional DBs or ORMs.
- Store CLI state in new tables/migrations under DatabaseCore: runs, steps, tool receipts, leases, retrieved chunks, index metadata, and vector tables (when vector extension is present).
- Default lexical search: FTS5 with BM25 ranking enabled; ANALYZE run post-migration to maintain stats.
- Default hybrid retrieval: lexical candidates blended with vector scores; lexical-first candidate count default 50 (configurable via `ANIGMA_RETRIEVAL_CANDIDATES`).
- Indexing behavior: incremental by commit and chunk hash; unchanged files at identical commit are not re-embedded.
- Schema migrations tracked via DatabaseCore migrator; migrations must be deterministic and idempotent, with down-migration scripts only when safe.

## Consequences
- Single SQLite file remains the source of truth; operational complexity stays low.
- Indexing pipelines must record chunk params, model id/hash, and embedding dimension to keep caches coherent.
- Praxis/Surface tests need to cover hybrid retrieval stability and incremental indexing behavior.

## Compatibility and migration
- Existing DatabaseCore deployments remain valid; new migrations append tables/columns rather than replacing the DB.
- Migrations must check for presence of vector extension before creating vector tables and fall back to lexical-only mode if absent.
- Backups remain simple (single SQLite file + artifacts).

## Acceptance and rollback criteria
- Acceptance: migrations apply cleanly on fresh and existing DBs; hybrid retrieval works with vector extension present and degrades to lexical-only when absent; indexing avoids duplicate embeddings for unchanged commits.
- Rollback: if migrations corrupt existing data or hybrid retrieval cannot be stabilized, revert to prior schema while preserving the SQLite file and rebuild indexes from repo snapshots.
