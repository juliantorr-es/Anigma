# PostgreSQL First-Class Capability Audit Matrix

Snapshot date: 2026-04-29

This document audits the current PostgreSQL surface in the repository after the SQLite purge. It does not claim architectural completeness; it identifies where the codebase is already PostgreSQL-backed, where it is only PostgreSQL-compatible, and where first-class PostgreSQL features are still missing.

TD is the source of truth for live task state. This matrix is the implementation-planning artifact that feeds TD.

**Primary Epic**: [td-89a996 - PostgreSQL First-Class Implementation](./EPIC_POSTGRESQL_FIRST_CLASS.md)

## Overall Read

- SQLite surface: effectively removed from tracked live code and docs.
- PostgreSQL surface: present, but still mostly a compatibility layer around generic SQL execution.
- First-class PostgreSQL capability: incomplete.
- Main missing pieces: real transactions, migration orchestration, typed query access, operational validation, and feature-specific use of PostgreSQL primitives.

## Target Shape

The end state is a single authoritative PostgreSQL system of record, not multiple competing databases.

- One PostgreSQL connection and transaction strategy shared by the runtime.
- One schema bootstrap and migration model for the whole repository.
- One canonical embedding/vector/search strategy where those capabilities need database support.
- Multiple bounded logical schemas or namespaces on top of the same PostgreSQL system.
- Module-specific adapters are allowed, but module-specific persistence engines are not.
- Composition roots may instantiate the low-level actor or client, but feature modules should consume narrow authorities or `DatabaseExecutor`-style contracts.

This target shape is formalized in [ADR-0017: Single Master PostgreSQL System of Record](/Users/user/Developer/GitHub/Anigma_clean/anigma/Docs/ADR/0017-single-master-postgresql-system.md).

## Audit Matrix

| Capability area | Current state | Evidence | Gap | Epic lane |
|---|---|---|---|---|
| Connection lifecycle | Partial | `DatabaseActor` uses `PostgresConnectionManager` and `PostgresClient` | Pool semantics are still logical rather than fully exercised; no health-aware lifecycle policy | Connection/runtime lane |
| Query execution | Partial | `queryRows`, `executeStatement`, and SQL rendering exist | Parameter binding is string-rendered rather than prepared-statement driven | Query engine lane |
| Transaction control | Missing | `DatabaseActor.transaction(...)` just executes the closure | No real BEGIN/COMMIT/ROLLBACK/savepoint/retry semantics | Transaction lane |
| Schema bootstrap | Partial | `validateBootstrap()` exists and some modules call schema apply routines | Bootstrap validation is a `SELECT 1` check; no catalog/extension/index verification | Bootstrap/migrations lane |
| Migrations | Partial | Repo has migration docs and schema files | No unified Postgres migration runner with versioned application and rollback drills | Migration lane |
| Tenant isolation / RLS | Partial | `RLSContext` and `SET LOCAL app.current_*` hooks exist | No end-to-end policy enforcement verification or failure-mode tests | Security/RLS lane |
| Observability | Partial | `DatabaseMetrics` exists | Several metrics are nil/placeholder; no `pg_stat_*` or statement-level observability integration | Observability lane |
| Bulk ingest | Missing | Current code does row-at-a-time execution | No `COPY`, batch ingest, or server-side import path | Ingest lane |
| Specialized indexing | Missing | Repository docs mention `JSONB`/`GIN`, but code is not broadly wired | No first-class FTS, JSONB, GIN, partial index, or generated-column strategy in the main runtime | Indexing lane |
| Queue primitives | Missing | Some modules hint at queue-like behavior | No `SKIP LOCKED`, advisory-lock, or LISTEN/NOTIFY-backed queue model | Queue lane |
| Typed row decoding | Partial | `DatabaseRow` and `DatabaseValue` exist | Decoding is generic and JSON-shaped in many places; no schema-bound typed row layer | Typed access lane |
| Capability boundaries | Partial | Many call sites route through `DatabaseExecutor` | Several modules still instantiate `DatabaseActor` directly | Boundary cleanup lane |
| Integration testing | Partial | Mock executors and targeted tests exist | Need live Postgres fixture tests for transactions, RLS, migrations, and feature primitives | Verification lane |
| Backup / restore / ops drills | Missing | No visible PostgreSQL operational drill path | No backup, restore, PITR, or schema drift rehearsal tied to the database layer | Operations lane |

## What "First-Class" Means Here

The implementation is not first-class until the database layer can demonstrate:

1. Real transaction boundaries with rollback and retry behavior.
2. Versioned migrations and bootstrap validation against a live PostgreSQL instance.
3. Typed access paths instead of ad hoc SQL string handling for core flows.
4. Explicit use of PostgreSQL primitives where they provide real value:
   - `JSONB`
   - `GIN` / btree / partial indexes
   - row-level security
   - advisory locks
   - `COPY`
   - `SKIP LOCKED`
   - `LISTEN` / `NOTIFY` where queueing or eventing is needed
5. Integration tests that run against a live PostgreSQL target, not only mocks.
6. Complete sealing of the `DatabaseActor` seam. Feature modules must strictly use `DatabaseAuthority`, treating `DatabaseActor` as a private implementation detail injected only at the composition root.

## Recommended Epic Shape

Create a single implementation epic with the following child lanes:

1. Connection and transaction semantics
2. Schema bootstrap and migration runner
3. Typed query and ingest layer
4. RLS, locks, and queue primitives
5. Observability and operational verification
6. Capability-boundary cleanup across modules

## Acceptance Criteria for the Epic

- PostgreSQL is the only supported database backend in tracked runtime code.
- Database runtime supports real transactions, rollback, and retry semantics.
- Core storage surfaces use typed PostgreSQL access patterns, not just generic SQL glue.
- Schema bootstrap and migrations are versioned, validated, and testable against live PostgreSQL.
- RLS, queue, and locking semantics are explicit where the product needs them.
- Integration tests validate the behavior against a live PostgreSQL fixture or container.
- Direct `DatabaseActor` usage is reduced to the approved composition roots or removed.
