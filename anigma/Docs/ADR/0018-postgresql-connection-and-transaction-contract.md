# ADR-0018: PostgreSQL Connection and Transaction Contract

> **Status:** Proposed
> **Date:** 2026-04-22
> **Supersedes:** None
> **Superseded by:** None

---

## Context

The codebase now routes through PostgreSQL, but the runtime still exposes a thin compatibility layer instead of a fully standardized connection and transaction model. Several modules can still call into the low-level actor directly, and the current transaction methods do not yet enforce real BEGIN/COMMIT/ROLLBACK/savepoint behavior.

Without one shared contract, each module can invent its own assumptions about opening connections, running statements, retrying failures, and handling transactional boundaries.

---

## Decision

Adopt one canonical PostgreSQL connection and transaction contract for the runtime.

### Contract Rules

1. One shared connection path exists for all runtime code.
2. Transaction boundaries are explicit and support rollback.
3. Retry behavior is defined once, not per module.
4. Savepoints are part of the contract where nested work needs them.
5. Query execution uses the shared contract instead of direct ad hoc client access.
6. Composition roots may build the low-level client or actor, but feature modules consume the contract.

### Required Behavior

- `BEGIN` / `COMMIT` / `ROLLBACK` are real database operations, not no-op closures.
- Transaction failures surface clearly and do not silently succeed.
- Retry policy is shared and observable.
- Connection lifecycle and metrics are owned centrally.

### Canonical Runtime Contract

`DatabaseCore.PostgresConnectionContract` is the executable form of this ADR.

- `PostgresConnectionContract.canonical()` defines the one supported runtime contract ID, approved composition roots, query shapes, actor boundary rule, and default transaction rule.
- Feature modules consume `DatabaseExecutor`; only approved composition roots may construct the low-level PostgreSQL actor or client.
- Read and write query shapes require parameterized execution and do not permit ad hoc raw SQL. Schema and maintenance work may use raw SQL through the same executor boundary.
- The default transaction rule is `readCommitted`, requires savepoints for nested work, and uses the shared retry policy for transient connection failures, serialization failures, and deadlocks.
- Downstream transaction-manager work must implement this contract with real PostgreSQL `BEGIN`, `COMMIT`, `ROLLBACK`, and savepoint behavior instead of changing the contract per module.

### Approved Composition Roots

The following modules are approved composition roots that may construct `DatabaseActor` directly:

| Composition Root | Module Path | `PostgresCompositionRoot` Case | Description |
|------------------|-------------|---------------------------------|-------------|
| Anigma Daemon | `Packages/AnigmaDaemonCore`, `Packages/AnigmaDaemon` | `.anigmaDaemon` | Core daemon server and kernel |
| Anigma App | `Sources/AnigmaAppMac` | `.anigmaApp` | macOS application |
| Command Line Tools | `Packages/HarmoniaCLI`, `Packages/AnigmaCLI`, `Packages/AccessumFlow` | `.commandLineTool` | All CLI entry points |
| MCP Server | `Sources/AnigmaMCPModule` | `.mcpServer` | Model Context Protocol server |
| Platform Runtime | `Packages/AnigmaCore` | `.platformRuntime` | Core integration layer (PlatformRuntime) |
| Test Harness | Test targets, `Packages/AnigmaDaemonCore/Jobs/ContextumWorkerBootstrap.swift` (test mode) | `.testHarness` | Testing infrastructure |

**All other modules must consume `DatabaseExecutor` via dependency injection, typically through `DatabaseAuthority`.**

### Current Violations (td-317bbb Tracking)

As of td-317bbb completion:
- **Phase 1**: ✅ Documented approved composition roots in PostgresConnectionContract and ADR-0018
- **Phase 2**: ✅ Refactored all feature modules to use `DatabaseExecutor` via dependency injection
- **Phase 2**: ✅ Added runtime contract enforcement in DatabaseActor.init with warnings for non-approved modules
- **Remaining**: ~25 `DatabaseActor(path:)` invocations, ALL in approved composition roots (CLI tools, daemon, app, test harness, MCP server)

See `grep -r "DatabaseActor(path:" anigma/` for current list. All remaining violations are intentional and correct per the approved composition root list.

### Migration Path

1. **Phase 1 (td-317bbb)**: ✅ Document composition roots, add runtime warnings for direct `DatabaseActor` creation from non-roots
2. **Phase 2**: ✅ Refactor high-priority modules to use `DatabaseExecutor` injection  
3. **Phase 3**: Restrict `DatabaseActor.init` visibility to DatabaseCore package (breaking change)
4. **Phase 4**: All modules consume `DatabaseExecutor`/`DatabaseAuthority` exclusively

**Current Status**: Phase 2 complete. All feature modules properly use DI. Only approved composition roots create DatabaseActor directly.

---

## Rationale

- Shared transactional semantics prevent each module from inventing its own error handling.
- Centralizing the contract makes testing and observability much easier.
- A single contract is the prerequisite for live PostgreSQL verification across the runtime.

---

## Consequences

### Positive

- Fewer duplicated connection helpers.
- Clearer failure semantics.
- Better basis for live integration tests.

### Negative

- Some modules will need small refactors to stop using direct actor instantiation.
- The runtime contract will be stricter than the current compatibility shim.

---

## References

- [ADR-0017: Single Master PostgreSQL System of Record](/Users/user/Developer/GitHub/Anigma_clean/anigma/Docs/ADR/0017-single-master-postgresql-system.md)
- [td-89a996 - PostgreSQL First-Class Implementation Epic](../../architecture-guides/EPIC_POSTGRESQL_FIRST_CLASS.md)
- [PostgreSQL First-Class Capability Audit Matrix](../../architecture-guides/POSTGRESQL_FIRST_CLASS_CAPABILITY_AUDIT_MATRIX.md)
- `td-7a398c` Canonical PostgreSQL connection, query, and transaction contract
- `td-8d467c` PostgreSQL transaction manager and retry semantics
