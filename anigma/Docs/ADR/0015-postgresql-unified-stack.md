# ADR-0015: PostgreSQL as Relational Truth and Coordination Foundation

> **Status:** Proposed  
> **Date:** 2026-04-16  
> **Supersedes:** None  
> **Superseded by:** None

---

## Context

The software industry has increasingly adopted complex distributed architectures comprising multiple specialized services (Redis, Elasticsearch, dedicated vector databases, message queues, etc.). This approach creates:

1. **Operational Complexity**: Managing multiple services with different scaling, backup, and monitoring requirements
2. **Cost Overhead**: Subscription fees for multiple SaaS offerings
3. **Data Consistency Challenges**: Maintaining ACID compliance across distributed systems
4. **Development Friction**: Context-switching between different query languages and APIs

Anigma's architecture already uses PostgreSQL as the primary data store, but we can leverage its full capabilities to eliminate most external dependencies.

---

## Decision

Adopt PostgreSQL as the **relational truth and coordination foundation** for Anigma, leveraging its extensibility to replace many specialized services with a single, battle-tested system where the workload is relational, queryable, transactional, or coordination-oriented.

PostgreSQL is not the universal storage answer. It coordinates sealed artifacts, memory-mapped atlases, GPU residency, and runtime projections; it does not absorb their hot binary layouts.

### Specific Adoptions:

1. **JSONB with GIN Indexes**: Replace document databases (MongoDB) for unstructured data
2. **SKIP LOCKED**: Implement job queues natively (replace Redis/RabbitMQ)
3. **TSVECTOR + pg_trgm**: Full-text search capabilities (reduce Elasticsearch dependency)
4. **pgvector**: Vector search for AI/ML features (replace Pinecone/Weaviate)
5. **Row-Level Security (RLS)**: Multi-tenancy security at database level
6. **Declarative Partitioning + BRIN Indexes**: Time-series data handling
7. **Materialized Views**: Pre-computed analytics (reduce data warehouse needs)

### Boundary Rule

PostgreSQL owns:

- relational truth
- manifests and registries
- metadata
- receipts
- policy decisions
- queue state
- queryable relationships
- artifact indexes
- vector/search indexes when latency and scale fit database budgets

PostgreSQL does not own:

- sealed source artifacts
- large immutable binary payload bytes by default
- memory-mapped execution atlases
- GPU-oriented Structure-of-Arrays layouts
- per-frame tile cache state
- private Metal buffers/textures
- UI/session projection state

The database may store references, hashes, manifests, receipts, and queryable summaries for these systems. It must not become the hot lane for workloads that require mmap section layout, GPU residency, or sealed binary replay.

---

## Rationale

### Why PostgreSQL as Relational Foundation?

1. **Battle-Tested Reliability**: 30+ years of active development with proven ACID compliance
2. **Extensibility**: Rich ecosystem of extensions (pgvector, pg_trgm, PostGIS, etc.)
3. **Performance**: Advanced indexing (GIN, GiST, BRIN) and query optimization
4. **Cost Efficiency**: Single system to operate, monitor, and scale
5. **Data Locality**: Avoid unnecessary hybrid search problems for queryable relational state
6. **Security**: Built-in RLS, encryption, and fine-grained access control

### Alignment with Anigma Architecture

This decision aligns perfectly with Anigma's existing:
- **Governed Persistence Layer** (PostgreSQL-based)
- **Three-Tier Architecture** (Tier 2 unified runtime)
- **Static Plugin System** (avoids distributed complexity)
- **Evidence Authority** (ACID-compliant audit logging)
- **Tiered Truth Storage** (database coordinates warm/queryable truth, not all payload bytes)
- **Page Atlas and Binary Atlas direction** (database stores manifests and receipts; atlases own execution layout)

### Industry Validation

The transcript from "I Just Replaced My Entire Tech Stack With Postgres" validates this approach:
- Demonstrates PostgreSQL replacing 80% of typical microservice stack
- Shows real-world performance benchmarks
- Highlights cost savings and operational simplicity

---

## Consequences

### Positive

✅ **Simplified Operations**: Single database to manage, backup, and monitor
✅ **Cost Reduction**: Eliminate multiple SaaS subscriptions
✅ **Data Consistency**: ACID transactions across all data types
✅ **Development Velocity**: Unified query language and API surface
✅ **Performance**: Local joins avoid network hops between services
✅ **Security**: Centralized access control via RLS

### Negative

⚠️ **Learning Curve**: Team must master PostgreSQL's advanced features
⚠️ **Vertical Scaling Limits**: PostgreSQL scales vertically better than horizontally
⚠️ **Extension Management**: Need to track and update extensions
⚠️ **Backup Complexity**: Single large database requires careful backup strategy
⚠️ **Scope Creep Risk**: Treating PostgreSQL as universal storage would damage mmap, GPU, and sealed artifact paths

### Neutral

🔄 **Migration Effort**: Existing data must be migrated to PostgreSQL-native formats
🔄 **Query Patterns**: Some queries may need rewriting to leverage PostgreSQL features
🔄 **Monitoring**: Consolidated monitoring but with more metrics to track

---

## Ownership

### What This Owns

- Canonical relational schemas and migrations.
- PostgreSQL extension policy.
- Queryable state, metadata, manifests, receipts, and registry records.
- Transactional coordination for jobs, queues, and policy-visible state.
- Database backup, restore, migration, and access-control requirements.

### What This Does Not Own

- Content-addressed artifact bytes except small records where inline storage is explicitly justified.
- Sealed binary atlas files or their mmap section layout.
- GPU residency, private Metal resources, tile caches, or per-frame state.
- Product UI projections.
- Any workload whose primary access pattern is sequential mmap scan, GPU replay, or large binary decode.

---

## Runtime Budget

PostgreSQL-backed features must declare:

- expected row count and growth rate
- index size budget
- transaction latency budget
- queue contention budget
- backup/restore target time
- vacuum/retention policy
- extension dependency and upgrade plan

Vector, full-text, JSONB, and queue workloads must graduate out of PostgreSQL if measured latency, index growth, or operational coupling violates those budgets.

---

## Failure Behavior

- Database unavailable: runtime enters degraded mode and blocks mutation paths requiring durable policy/evidence records.
- Queue contention: workers back off through SKIP LOCKED policy and emit pressure telemetry.
- Extension unavailable: dependent capability is disabled, not silently downgraded.
- Index corruption or unacceptable bloat: rebuild from authoritative manifests/artifacts.
- Hot binary workload detected in database: move bytes to sealed artifact or atlas storage and keep only manifest/reference rows.

---

## Verification

Before acceptance, this ADR requires:

- schema ownership review
- extension inventory and upgrade test
- backup/restore drill
- queue contention benchmark
- vector/full-text latency benchmark for expected data scale
- audit proving atlas/artifact payload bytes are referenced, not absorbed as hot database lanes

---

## Implementation Plan

### Phase 1: Foundation (Current - Q2 2026)
- [x] PostgreSQL as primary data store (already implemented)
- [x] RLS for multi-tenancy (already implemented)
- [ ] JSONB with GIN indexes for unstructured data
- [ ] SKIP LOCKED pattern for job queues

### Phase 2: Search & AI (Q3 2026)
- [ ] TSVECTOR for full-text search
- [ ] pg_trgm for fuzzy search
- [ ] pgvector for vector search
- [ ] Hybrid search capabilities (vector + relational filters)

### Phase 3: Advanced Features (Q4 2026)
- [ ] Declarative partitioning for time-series data
- [ ] BRIN indexes for telemetry
- [ ] Materialized views for analytics
- [ ] PostGIS for geographic data (if needed)

---

## Migration Strategy

### For New Features:
- **Immediate**: All new features must use PostgreSQL-native capabilities
- **Required**: Use extensions where appropriate (pgvector, pg_trgm)
- **Review**: Architecture team approves database schema changes

### For Existing Features:
- **Gradual**: Migrate during natural refactoring cycles
- **Priority**: Focus on features with external dependencies first
- **Compatibility**: Maintain dual-write during transition where needed

---

## References

### Internal
- `anigma/Docs/root-docs/Design/Governed_Persistence_Design.md`
- `anigma/Docs/root-docs/Design/INTEGRATED_DESIGN_BLUEPRINT.md`
- `anigma/Docs/ADR/0006-three-tier-runtime-architecture.md`

### External
- [PostgreSQL JSONB Documentation](https://www.postgresql.org/docs/current/datatype-json.html)
- [pgvector Extension](https://github.com/pgvector/pgvector)
- [pg_trgm Extension](https://www.postgresql.org/docs/current/pgtrgm.html)
- [SKIP LOCKED Pattern](https://www.postgresql.org/docs/current/sql-select.html#SQL-FOR-UPDATE-SHARE)
- [Transcript: "I Just Replaced My Entire Tech Stack With Postgres"](https://example.com/transcript)

### Performance Benchmarks
- JSONB vs MongoDB: [PostgreSQL vs MongoDB](https://scalegrid.io/blog/postgresql-vs-mongodb/)
- pgvector vs Pinecone: [pgvector benchmarks](https://github.com/pgvector/pgvector#benchmarks)
- SKIP LOCKED throughput: [PostgreSQL concurrency](https://www.cybertec-postgresql.com/en/postgresql-concurrency-skip-locked/)

---

## Success Metrics

1. **Dependency Reduction**: Track number of external services eliminated
2. **Cost Savings**: Measure infrastructure cost reduction
3. **Query Performance**: Benchmark key operations before/after migration
4. **Development Velocity**: Time-to-implement for new features
5. **Operational Metrics**: MTTR, backup/restore times, monitoring complexity

---

## Approval

**Proposed by:** Architecture Team  
**Reviewed by:** [Engineering Lead]  
**Approved by:** [CTO]  
**Approval Date:** [YYYY-MM-DD]

---

## Revision History

- 2026-04-16: Initial draft based on architectural review and industry validation
