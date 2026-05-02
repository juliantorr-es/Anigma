# EPIC: PostgreSQL First-Class Implementation

> **Epic ID**: `td-89a996`
> **Status**: Open
> **Priority**: P0 (Highest)
> **Start Date**: 2026-04-29
> **Epic Owner**: Database Team
> **Stakeholders**: Engineering, Architecture, QA, DevOps

---

## Executive Summary

This epic elevates PostgreSQL from a compatibility layer to the **fully-first-class, only supported database backend** for Anigma. Building on the SQLite deprecation work, this epic systematically implements real PostgreSQL capabilities: transactions with savepoints, versioned migrations, typed queries, row-level security, queue primitives, advanced indexing, and comprehensive observability.

**Reference Documents:**
- [PostgreSQL First-Class Capability Audit Matrix](./POSTGRESQL_FIRST_CLASS_CAPABILITY_AUDIT_MATRIX.md)
- [ADR-0017: Single Master PostgreSQL System of Record](../ADR/0017-single-master-postgresql-system.md)
- [ADR-0018: PostgreSQL Connection and Transaction Contract](../ADR/0018-postgresql-connection-and-transaction-contract.md)
- [DatabaseConfiguration Migration Notes](../database/POSTGRESQL_MIGRATION_GUIDE.md)

---

## Epic Goals

### Primary Objectives
1. **Achieve First-Class PostgreSQL Status**: Close all gaps in the PostgreSQL First-Class Capability Audit Matrix
2. **Real Transaction Semantics**: Implement BEGIN/COMMIT/ROLLBACK with savepoints for nested transactions
3. **Versioned Schema Management**: Unified migration runner with rollback support
4. **Type-Safe Database Access**: Typed queries and row decoding instead of ad-hoc SQL strings
5. **Advanced PostgreSQL Features**: Full utilization of JSONB, GIN, pgvector, SKIP LOCKED, LISTEN/NOTIFY, advisory locks
6. **Production-Ready Observability**: Complete metrics, health checks, and slow query logging
7. **Clean Architecture**: Enforce capability boundaries with authority-based access patterns

### Success Metrics
- **Audit Matrix Completion**: 100% of identified gaps closed
- **Code Coverage**: 80%+ test coverage for database layer
- **Type Safety**: 90% of core database operations use typed queries
- **Migration Reliability**: 100% idempotent migrations with verified rollback
- **Performance**: No regression from string parameters to prepared statements
- **Boundary Compliance**: Direct `DatabaseActor` usage limited to approved composition roots

---

## Epic Scope

### In Scope
- ✅ All 12 gap areas from the PostgreSQL Audit Matrix
- ✅ Core database infrastructure (DatabaseCore package)
- ✅ All modules using DatabaseActor
- ✅ Migration tooling and schema management
- ✅ Integration testing with live PostgreSQL
- ✅ Operational tooling (backup, health checks)
- ✅ Documentation and ADR updates

### Out of Scope
- ❌ Frontend/macOS app database changes (separate effort)
- ❌ CoreData-backed stores (AnigmaSystem.db)
- ❌ Non-PostgreSQL persistence engines
- ❌ Application-level business logic

---

## Work Breakdown Structure

### Phase 1: Connection & Transaction Semantics (Week 1-4)
**6 tasks | 26 points**

| Task ID | Title | Priority | Points | Status |
|---------|-------|----------|--------|--------|
| td-ceb563 | Implement savepoint support in PostgresConnectionManager | P0 | 8 | Open |
| td-46ebac | Enhance DatabaseActor.transaction() to use real savepoints | P0 | 5 | Open |
| td-87802d | Replace string parameter rendering with prepared statements | P0 | 5 | Open |
| td-ec6cd2 | Implement connection health checks and auto-reconnect | P0 | 3 | Open |
| td-e014ac | Add connection lifecycle metrics | P0 | 2 | Open |
| td-317bbb | Enforce PostgresConnectionContract at composition roots | P0 | 3 | Open |

**Phase 1 Acceptance Criteria:**
- [ ] All transactions use real PostgreSQL BEGIN/COMMIT/ROLLBACK
- [ ] Nested transactions use savepoints
- [ ] Parameters use prepared statements (not string interpolation)
- [ ] Connection health is monitored
- [ ] All database access respects the canonical contract

---

### Phase 2: Schema Bootstrap & Migration Runner (Week 5-8)
**7 tasks | 27 points**

| Task ID | Title | Priority | Points | Status |
|---------|-------|----------|--------|--------|
| td-c4f77f | Create SchemaMigrationRunner actor | P0 | 8 | Open |
| td-16f76f | Define migration manifest format | P0 | 3 | Open |
| td-5fad41 | Implement version table and drift detection | P0 | 5 | Open |
| td-9c771a | Implement rollback support with transaction savepoints | P0 | 5 | Open |
| td-c337c5 | Add extension verification (pgvector, pg_trgm) | P0 | 2 | Open |
| td-5c5644 | Integrate migration runner into DaemonServer | P0 | 3 | Open |
| td-3e7233 | Add migration testing against live PostgreSQL | P0 | 3 | Open |

**Phase 2 Acceptance Criteria:**
- [ ] Migration runner can apply migrations in order
- [ ] Version table tracks applied migrations
- [ ] Drift detection prevents out-of-sync schemas
- [ ] Rollback works via savepoints
- [ ] Required extensions verified before migration
- [ ] DaemonServer runs migrations on startup
- [ ] Migration tests pass against live PostgreSQL

---

### Phase 3: Typed Query & Ingest Layer (Week 9-12)
**6 tasks | 25 points**

| Task ID | Title | Priority | Points | Status |
|---------|-------|----------|--------|--------|
| td-a1d1c9 | Create TypedQueryBuilder with strongly-typed columns | P0 | 8 | Open |
| td-cbb1b3 | Generate row types from schema definitions | P0 | 5 | Open |
| td-ad1f60 | Implement COPY FROM bulk ingest | P0 | 5 | Open |
| td-fbcd6c | Create typed decoders for JSONB columns | P0 | 3 | Open |
| td-0982de | Add vector column type support | P0 | 3 | Open |
| td-8e5529 | Migrate ModelRegistryStore to typed queries | P0 | 3 | Open |

**Phase 3 Acceptance Criteria:**
- [ ] TypedQueryBuilder supports all CRUD operations
- [ ] Row types generated for all core tables
- [ ] COPY FROM used for bulk operations
- [ ] JSONB columns have type-safe coders
- [ ] Vector types supported in queries
- [ ] At least one module (ModelRegistryStore) migrated to typed queries

---

### Phase 4: RLS, Locks & Queue Primitives (Week 13-15)
**7 tasks | 24 points**

| Task ID | Title | Priority | Points | Status |
|---------|-------|----------|--------|--------|
| td-bc0466 | Implement RLS policy definitions as Swift types | P0 | 5 | Open |
| td-35468c | Create RLS policy application and verification | P0 | 5 | Open |
| td-d8ad3a | Implement SKIP LOCKED for job queue claiming | P0 | 3 | Open |
| td-a53d9f | Create JobQueue abstraction using SKIP LOCKED | P0 | 5 | Open |
| td-6ba323 | Implement advisory locks for cross-process coordination | P0 | 3 | Open |
| td-a22b0c | Add LISTEN/NOTIFY for database events | P0 | 3 | Open |
| td-cfa52e | Create EventBus abstraction on LISTEN/NOTIFY | P0 | 3 | Open |

**Phase 4 Acceptance Criteria:**
- [ ] RLS policies defined as Swift types
- [ ] RLS policies applied and verified on tables
- [ ] Job queue uses SKIP LOCKED for concurrent claims
- [ ] JobQueue abstraction available for modules
- [ ] Advisory locks available for coordination
- [ ] LISTEN/NOTIFY working for events
- [ ] EventBus abstraction available

---

### Phase 5: Observability & Operations (Week 16-18)
**7 tasks | 19 points**

| Task ID | Title | Priority | Points | Status |
|---------|-------|----------|--------|--------|
| td-659c7e | Integrate pg_stat_statements for query metrics | P0 | 3 | Open |
| td-c074e2 | Populate DatabaseMetrics with live PostgreSQL stats | P0 | 3 | Open |
| td-0cb394 | Add slow query logging (>100ms) | P0 | 2 | Open |
| td-f4513d | Implement connection pool metrics | P0 | 3 | Open |
| td-36edb3 | Add health check endpoint for PostgreSQL | P0 | 2 | Open |
| td-03413f | Create backup/restore utilities | P0 | 3 | Open |
| td-c9cb45 | Add migration test fixtures | P0 | 3 | Open |

**Phase 5 Acceptance Criteria:**
- [ ] Query metrics tracked via pg_stat_statements
- [ ] DatabaseMetrics populated with real data
- [ ] Slow queries logged with thresholds
- [ ] Connection pool metrics available
- [ ] Health check endpoint functional
- [ ] Backup/restore utilities available
- [ ] Migration tests have fixtures

---

### Phase 6: Capability Boundary Cleanup (Week 19-20)
**5 tasks | 21 points**

| Task ID | Title | Priority | Points | Status |
|---------|-------|----------|--------|--------|
| td-8cd968 | Audit all DatabaseActor instantiations across codebase | P0 | 2 | Open |
| td-21b6d4 | Create DatabaseAuthority protocols for module boundaries | P0 | 5 | Open |
| td-1eacd3 | Replace direct actor usage with authority injection | P0 | 8 | Open |
| td-4f92a0 | Document approved composition roots | P0 | 2 | Open |
| td-7dffff | Add compile-time checks for contract compliance | P0 | 3 | Open |

**Phase 6 Acceptance Criteria:**
- [ ] All DatabaseActor instantiations audited
- [ ] DatabaseAuthority protocols defined
- [ ] 80% of direct actor usage replaced with authority injection
- [ ] Approved composition roots documented
- [ ] Compile-time checks verify compliance

---

### Phase 7: Specialized Indexing (Week 21-22)
**6 tasks | 14 points**

| Task ID | Title | Priority | Points | Status |
|---------|-------|----------|--------|--------|
| td-18fed9 | Create index advisor for query patterns | P0 | 3 | Open |
| td-dee103 | Implement partial indexes for common filtered queries | P0 | 2 | Open |
| td-ee96df | Add BRIN indexes for time-series data | P0 | 2 | Open |
| td-916342 | Implement generated columns for computed values | P0 | 2 | Open |
| td-b3b58d | Create index usage monitoring | P0 | 3 | Open |
| td-ad6d52 | Optimize JSONB query patterns with GIN | P0 | 2 | Open |

**Phase 7 Acceptance Criteria:**
- [ ] Index advisor analyzes query patterns
- [ ] Partial indexes created for common filters
- [ ] BRIN indexes on time-series columns
- [ ] Generated columns for computed values
- [ ] Index usage monitoring active
- [ ] JSONB queries optimized with GIN

---

### Phase 8: Integration Testing (Ongoing, Week 23+)
**7 tasks | 18 points**

| Task ID | Title | Priority | Points | Status |
|---------|-------|----------|--------|--------|
| td-8643ef | Set up Testcontainers for PostgreSQL | P0 | 3 | Open |
| td-d12908 | Create fixture loader for test data | P0 | 3 | Open |
| td-aab089 | Add transaction rollback tests | P0 | 3 | Open |
| td-713724 | Add RLS enforcement tests | P0 | 3 | Open |
| td-c8f84b | Add migration idempotency tests | P0 | 2 | Open |
| td-9842d2 | Add concurrency stress tests | P0 | 3 | Open |
| td-f4e3bb | Add performance benchmark tests | P0 | 2 | Open |

**Phase 8 Acceptance Criteria:**
- [ ] Testcontainers configured for PostgreSQL
- [ ] Fixture loader functional
- [ ] Transaction rollback tests pass
- [ ] RLS enforcement tests pass
- [ ] Migration idempotency verified
- [ ] Concurrency stress tests pass
- [ ] Performance benchmarks established

---

## Dependency Graph

```
─────────────────────────────────────────────────────────────────
                    EPIC: td-89a996
                    PostgreSQL First-Class Implementation
─────────────────────────────────────────────────────────────────
                          │
    ┌─────────────────────┼─────────────────────┐
    ▼                     ▼                     ▼
Phase 1              Phase 2              Phase 3
Connection &       Schema &            Typed & 
Transaction       Migration            Ingest
    │                     │                     │
    └─────────────────────┼─────────────────────┘
                          ▼
                    Phase 4 RLS, Locks, Queues
                          │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
    Phase 5           Phase 6             Phase 7
  Observability   Boundaries       Specialized
                         │                   Indexing
                         │                    
          ┌───────────────────┘
          ▼
      Phase 8: Integration Testing
          │
          ▼
    All Phases Complete → PostgreSQL is First-Class
```

### Phase Dependencies
- **Phase 1** → No dependencies (foundational)
- **Phase 2** → Phase 1 (needs connection infrastructure)
- **Phase 3** → Phase 1 (needs transaction/connection)
- **Phase 4** → Phase 1 (needs connection)
- **Phase 5** → Phase 1, Phase 4 (needs RLS)
- **Phase 6** → Phase 2, Phase 3 (needs migrations and types)
- **Phase 7** → Phase 3 (needs typed queries)
- **Phase 8** → All phases (integration)

---

## File Changes Summary

| Directory | Phases | Changes |
|-----------|--------|---------|
| `DatabaseCore/` | All | Core infrastructure |
| `PostgresNIOIntegration.swift` | 1, 3, 4, 5, 7 | Connection, transactions, primitives |
| `DatabaseActor.swift` | 1, 4, 5 | Transactions, SKIP LOCKED, metrics |
| `DatabaseConfiguration.swift` | 2, 5 | Migration config, health |
| `PostgresConnectionContract.swift` | 1, 6 | Contract enforcement |
| `DaemonServer.swift` | 2, 5, 6 | Migration integration, health |
| `MigrationRunner.swift` | 2 | New file |
| `TypedQuery.swift` | 3, 7 | New file |
| `RowTypes.swift` | 3 | New file |
| `DatabaseCore/RLS/` | 4 | New directory |
| `DatabaseCore/Queue/` | 4 | New directory |
| `DatabaseCore/Events/` | 4 | New directory |
| `DatabaseCore/Indexing/` | 7 | New directory |
| `DatabaseCore/Operations/` | 5 | New directory |
| `Tests/` | 8 | Integration tests |
| `Docs/ADR/` | 6 | Authority documentation |

---

## Audit Matrix Tracking

Below is the tracking of how each subtask maps to gaps identified in the [PostgreSQL First-Class Capability Audit Matrix](./POSTGRESQL_FIRST_CLASS_CAPABILITY_AUDIT_MATRIX.md):

| Audit Matrix Gap | Phase | Task IDs | Status |
|-------------------|-------|---------|--------|
| Connection lifecycle | Phase 1 | td-ec6cd2, td-e014ac | Not Started |
| Query execution (prepared statements) | Phase 1 | td-87802d | Not Started |
| Transaction control | Phase 1 | td-ceb563, td-46ebac | Not Started |
| Schema bootstrap | Phase 2 | td-c4f77f, td-5fad41, td-5c5644 | Not Started |
| Migrations | Phase 2 | td-c4f77f, td-16f76f, td-9c771a, td-c337c5, td-3e7233 | Not Started |
| Tenant isolation / RLS | Phase 4 | td-bc0466, td-35468c | Not Started |
| Observability | Phase 5 | td-659c7e, td-c074e2, td-0cb394, td-f4513d, td-36edb3 | Not Started |
| Bulk ingest (COPY) | Phase 3 | td-ad1f60 | Not Started |
| Specialized indexing | Phase 7 | td-18fed9, td-dee103, td-ee96df, td-916342, td-b3b58d, td-ad6d52 | Not Started |
| Queue primitives (SKIP LOCKED) | Phase 4 | td-d8ad3a, td-a53d9f | Not Started |
| Typed row decoding | Phase 3 | td-a1d1c9, td-cbb1b3, td-fbcd6c, td-0982de, td-8e5529 | Not Started |
| Capability boundaries | Phase 6 | td-8cd968, td-21b6d4, td-1eacd3, td-4f92a0, td-7dffff | Not Started |
| Integration testing | Phase 8 | All Phase 8 tasks | Not Started |
| Backup / restore / ops | Phase 5 | td-03413f, td-36edb3 | Not Started |

---

## Resource Planning

### Team Allocation
- **Database Team**: 3-4 developers (Phases 1-5, 7)
- **Module Owners**: Part-time (Phase 6 - boundary cleanup in their modules)
- **QA Team**: 1-2 test engineers (Phase 8)
- **Architecture**: 1 architect (oversight across all phases)

### Estimated Velocity
- **Points per sprint (2 weeks)**: ~20-25
- **Total points**: 174
- **Estimated sprints**: 8-9 (16-18 weeks)

### Parallel Work Streams
- **Stream A** (Database Team): Phases 1, 2, 3, 4, 5, 7
- **Stream B** (All Teams): Phase 6 (boundary cleanup)
- **Stream C** (QA Team): Phase 8 (testing)

---

## Risk Management

| Risk | Probability | Impact | Mitigation | Owner |
|------|-------------|--------|------------|-------|
| Migration runner breaks production data | Medium | High | Backup before migration, dry-run mode, extensive testing | Database Team |
| Transaction semantics differ from current behavior | Low | High | Comprehensive integration tests, comparison testing | Database Team |
| Performance regression from prepared statements | Low | Medium | Benchmark before/after, optimize parameter binding | Database Team |
| Module resistance to boundary cleanup | Medium | Medium | Phased enforcement, module support, education | Architecture |
| PostgreSQL version compatibility | Medium | High | Matrix testing (13, 14, 15, 16), discover capability detection | Database Team |
| Savepoint implementation complexity | Medium | Medium | Research PostgreSQL savepoint semantics, incremental implementation | Database Team |

---

## Monitoring & Metrics

### Epic Progress Tracking
```bash
# View epic and all subtasks
td show td-89a996

# View subtasks by phase
td query "epic:td-89a996 AND phase:Phase 1"

# View open tasks
td query "epic:td-89a996 AND status:open"

# View blocked tasks
td query "epic:td-89a996 AND status:blocked"
```

### Success Metrics Dashboard
- **Audit Matrix Completion**: X/14 gaps closed
- **Test Coverage**: X%
- **Typed Query Adoption**: X% of operations
- **Migration Success Rate**: X%
- **Performance Benchmarks**: All within SLA

---

## Acceptance Criteria for Epic Completion

### Technical Acceptance
1. [ ] All 14 gaps in the PostgreSQL First-Class Capability Audit Matrix are closed
2. [ ] PostgreSQL is the only database backend in tracked runtime code
3. [ ] Database runtime supports real transactions with BEGIN/COMMIT/ROLLBACK and savepoints
4. [ ] Core storage surfaces use typed PostgreSQL access patterns
5. [ ] Schema bootstrap and migrations are versioned, validated, and testable against live PostgreSQL
6. [ ] RLS, queue, and locking semantics are explicit where the product needs them
7. [ ] Integration tests validate behavior against a live PostgreSQL fixture
8. [ ] Direct `DatabaseActor` usage is reduced to approved composition roots only

### Quality Acceptance
1. [ ] All Phase 8 integration tests pass
2. [ ] Performance benchmarks show no regression
3. [ ] Security review of prepared statements and RLS implementation
4. [ ] Documentation complete and reviewed
5. [ ] Rollback procedures tested for all migrations

---

## Related Documents

- [PostgreSQL First-Class Capability Audit Matrix](./POSTGRESQL_FIRST_CLASS_CAPABILITY_AUDIT_MATRIX.md)
- [ADR-0017: Single Master PostgreSQL System of Record](../ADR/0017-single-master-postgresql-system.md)
- [ADR-0018: PostgreSQL Connection and Transaction Contract](../ADR/0018-postgresql-connection-and-transaction-contract.md)
- [DatabaseConfiguration Migration Guide](../database/POSTGRESQL_MIGRATION_GUIDE.md)
- [DatabaseCore Package Documentation](../database/DATABASE_CORE/README.md)

---

## Appendix: Task Quick Reference

### All Tasks by Phase

| Phase | Task Count | Total Points | Task IDs |
|-------|-----------|--------------|---------|
| Phase 1 | 6 | 26 | td-ceb563, td-46ebac, td-87802d, td-ec6cd2, td-e014ac, td-317bbb |
| Phase 2 | 7 | 27 | td-c4f77f, td-16f76f, td-5fad41, td-9c771a, td-c337c5, td-5c5644, td-3e7233 |
| Phase 3 | 6 | 25 | td-a1d1c9, td-cbb1b3, td-ad1f60, td-fbcd6c, td-0982de, td-8e5529 |
| Phase 4 | 7 | 24 | td-bc0466, td-35468c, td-d8ad3a, td-a53d9f, td-6ba323, td-a22b0c, td-cfa52e |
| Phase 5 | 7 | 19 | td-659c7e, td-c074e2, td-0cb394, td-f4513d, td-36edb3, td-03413f, td-c9cb45 |
| Phase 6 | 5 | 21 | td-8cd968, td-21b6d4, td-1eacd3, td-4f92a0, td-7dffff |
| Phase 7 | 6 | 14 | td-18fed9, td-dee103, td-ee96df, td-916342, td-b3b58d, td-ad6d52 |
| Phase 8 | 7 | 18 | td-8643ef, td-d12908, td-aab089, td-713724, td-c8f84b, td-9842d2, td-f4e3bb |
| **Total** | **51** | **174** | - |

---

*Last Updated: 2026-04-29*
*Generated from TD Epic: td-89a996*
