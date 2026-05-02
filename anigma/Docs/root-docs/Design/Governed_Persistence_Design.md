# Design: Governed Persistence Layer

**Author:** Gemini CLI (ses_f7e637)
**Status:** DRAFT (Design Phase)
**Date:** 2026-01-11
**Version:** 1.0.0

## 1. Overview
The Governed Persistence Layer provides the source of truth for the Anigma Platform. It unifies high-performance SQL metadata (PostgreSQL) with content-addressed large artifact storage (CAS). It is designed to enforce multi-tenant isolation via Row-Level Security (RLS) and prevent common high-concurrency failure modes like the "Thundering Herd."

This document is intentionally aligned with the canonical platform identity/provenance model described in:

- `INTEGRATED_DESIGN_BLUEPRINT.md` — canonical `ProjectID` → `PrincipalID` → `SessionID` → `RunID` → `EpisodeID` hierarchy
- `Observability_Spine_Design.md` — identity propagation, provenance flow, and the `EvidenceAuthority` / `TelemetryClient` split

## 2. PostgreSQL Schema & RLS Strategy

### 2.1 Multi-Tenant Isolation (RLS)
Every table containing project-specific data MUST include a `project_id` column and enable PostgreSQL Row-Level Security.

```sql
-- Example RLS Policy
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY project_isolation_policy ON audit_logs
    USING (project_id = current_setting('anigma.current_project_id')::uuid);
```
- **Enforcement**: The `DatabaseAuthority` sets the `anigma.current_project_id` session variable before executing any query, using the `ProjectID` from the `CorrelationIDContext`.
- **Identity Scope**: `ProjectID`, `PrincipalID`, `SessionID`, `RunID`, and `EpisodeID` are all part of the broader platform identity/provenance model. This layer only binds `ProjectID` directly for RLS, but it must remain compatible with the full hierarchy used by the spine and blueprint docs.

### 2.2 Core Schema
| Table | Description | Primary Key |
| :--- | :--- | :--- |
| **`projects`** | Institutional Tenants | `id` (UUID) |
| **`principals`** | User/Agent Identities | `id` (UUID) |
| **`audit_logs`** | Signed Evidence Receipts | `receipt_id` (UUID) |
| **`artifacts`** | Metadata for Files/Models | `artifact_id` (UUID) |
| **`blobs`** | Physical Content-Addressed Storage | `blob_hash` (BLAKE3) |
| **`entities`** | KG Nodes (People, Orgs, Policies) | `entity_id` (UUID) |
| **`relationships`** | KG Edges (GovernedBy, TrainedOn) | `rel_id` (UUID) |
| **`communities`** | Clustered Graph Summaries | `community_id` (UUID) |
| **`jobs`** | Async Workflows/Tasks | `job_id` (UUID) |

## 3. The Semantic Surface (GraphRAG)

Anigma moves beyond "Naive RAG" by representing institutional data as a structured Knowledge Graph.

### 3.1 Entity & Relationship Extraction
The `InferenceAuthority` runs background extraction jobs (via the `ExecutionAuthority`) to populate the semantic surface:
- **Entities**: Extracted from documents and codebases, categorized by type (Policy, Contributor, System, LegalArgument).
- **Relationships**: Typed connections (e.g., `Principal -> Accessed -> Artifact` or `Policy -> Governs -> CodeSymbol`).
- **Provenance Linkage**: Every `rel_id` and `entity_id` is linked back to the `receipt_id` of the document that provided the evidence for its existence.

### 3.2 Community Summarization
To support "Big Picture" reasoning (e.g., "What are the common legal themes in these 1,000 documents?"):
- **Clustering**: The system uses hierarchical detection (e.g., Leiden algorithm) to group related entities into `communities`.
- **Summarization**: High-level summaries are generated for each community and stored in the `communities` table.
- **Efficient Querying**: The `InferenceAuthority` queries these **Summaries** first, significantly reducing token usage and improving reasoning quality across massive datasets.

## 4. Thundering Herd Prevention (Request Coalescing)

To prevent the "Thundering Herd" problem, the `DatabaseAuthority` implements a **Request Coalescer**.

```swift
actor DatabaseAuthority {
    private var activeQueries: [QueryHash: Task<QueryResult, Error>] = [:]

    func execute<T: Query>(_ query: T) async throws -> T.Result {
        let hash = query.hashValue
        
        // Coalescing: If the same query is already running, wait for it.
        if let existingTask = activeQueries[hash] {
            return try await existingTask.value as! T.Result
        }
        
        let task = Task {
            defer { activeQueries[hash] = nil }
            return try await self.performQuery(query)
        }
        
        activeQueries[hash] = task
        return try await task.value as! T.Result
    }
}
```
- **Benefit**: If 10,000 agents request the same institutional policy, only **one** query hits PostgreSQL; the other 9,999 wait for the result of the first.

## 4. Content-Addressed Storage (CAS)

The `ArtifactAuthority` manages large assets using a hybrid hashing and deduplication strategy.

- **Storage Structure**:
    - Metadata is stored in the `artifacts` table (Filename, ContentType, ProjectID).
    - Content is stored in the `blobs` table, keyed by `blob_hash` (BLAKE3).
- **Deduplication**: If two projects upload the same 10GB LLM weights, they get two `artifact_id`s but share a single `blob_hash` record, saving 10GB of storage.
- **Hashing**:
    - **BLAKE3**: Used for internal CAS addressing and fast deduplication.
    - **SHA-256**: Stored in the `blobs` record for external audit compliance.

## 5. Audit Integrity (Hash-Chaining)

The `audit_logs` table creates a cryptographic provenance chain.

- **Chaining**: Every new receipt includes the `sha256_hash` of the *previous* receipt for that specific `ProjectID`.
- **Verification**: An auditor can verify the entire project history by re-calculating the hash chain. If a single record is modified or deleted, the chain breaks.

## 6. Job Persistence (JobStore)

Asynchronous workflows are persisted to handle daemon restarts.
- **State Machine**: `pending -> running -> (completed | failed)`.
- **Lease Mechanism**: Daemons "Lease" a job by setting `locked_at` and `locked_by` (DaemonID) within a transaction, preventing double-execution.
- **Concurrency Pattern**: Uses PostgreSQL's `SKIP LOCKED` clause for efficient job queue processing, allowing workers to skip already-locked rows and immediately acquire the next available job.

## 7. PostgreSQL Extension Recommendations

To maximize PostgreSQL's capabilities as a unified architectural foundation:

### 7.1 JSONB with GIN Indexes
- **Purpose**: Store and query unstructured data efficiently
- **Implementation**: Use `JSONB` data type for evidence payloads, artifact metadata, and flexible schemas
- **Indexing**: Create GIN indexes on JSONB columns for fast querying of nested properties
- **Benefit**: Replaces document databases while maintaining ACID compliance

### 7.2 Full-Text Search
- **Purpose**: Advanced text search capabilities
- **Implementation**: 
  - Use `TSVECTOR` columns for parsed, stemmed text
  - Apply `pg_trgm` extension for fuzzy search and typo tolerance
  - Create specialized indexes for search-intensive tables
- **Benefit**: Reduces dependency on Elasticsearch for basic search features

### 7.3 Vector Search (pgvector)
- **Purpose**: AI/ML semantic search and similarity matching
- **Implementation**:
  - Install `pgvector` extension
  - Store vector embeddings in `vector` type columns
  - Use HNSW indexes for fast approximate nearest neighbor search
  - Support hybrid queries (vector + relational filters)
- **Benefit**: Eliminates need for dedicated vector databases while maintaining data locality

### 7.4 Time-Series Optimization
- **Purpose**: Efficient telemetry and event logging
- **Implementation**:
  - Use declarative partitioning by time ranges
  - Apply BRIN (Block Range INdexes) for time-based queries
  - Consider timescaleDB extension for advanced time-series features
- **Benefit**: Handles high-volume telemetry without specialized time-series databases

### 7.5 Advanced Indexing Strategies
- **GIN Indexes**: For JSONB, array, and composite type columns
- **GiST Indexes**: For geometric data (if using PostGIS)
- **BRIN Indexes**: For large, naturally-ordered datasets (timestamps, IDs)
- **Partial Indexes**: For frequently queried subsets of data

### 7.6 Full-Text Search Implementation

#### TSVECTOR Columns
- **Purpose**: Enable advanced text search capabilities
- **Implementation**:
  ```sql
  -- Add TSVECTOR column to tables requiring search
  ALTER TABLE artifacts ADD COLUMN search_vector TSVECTOR;
  
  -- Create trigger to update vector when content changes
  CREATE OR REPLACE FUNCTION artifacts_search_vector_update() RETURNS TRIGGER AS $$
  BEGIN
    NEW.search_vector := 
      SETWEIGHT(TO_TSVECTOR('english', COALESCE(NEW.name, '')), 'A') ||
      SETWEIGHT(TO_TSVECTOR('english', COALESCE(NEW.description, '')), 'B') ||
      SETWEIGHT(TO_TSVECTOR('english', COALESCE(NEW.content, '')), 'C');
    RETURN NEW;
  END
  $$ LANGUAGE plpgsql;
  
  -- Create trigger
  CREATE TRIGGER artifacts_search_vector_trigger 
  BEFORE INSERT OR UPDATE ON artifacts 
  FOR EACH ROW EXECUTE FUNCTION artifacts_search_vector_update();
  
  -- Create GIN index for fast searching
  CREATE INDEX idx_artifacts_search_vector ON artifacts USING GIN(search_vector);
  ```

#### Query Examples
- **Basic Search**:
  ```sql
  SELECT id, name, content 
  FROM artifacts 
  WHERE search_vector @@ TO_TSQUERY('english', 'searchterm')
  ORDER BY TS_RANK(search_vector, TO_TSQUERY('english', 'searchterm')) DESC;
  ```

- **Fuzzy Search with pg_trgm**:
  ```sql
  -- Enable extension
  CREATE EXTENSION IF NOT EXISTS pg_trgm;
  
  -- Fuzzy search for typo tolerance
  SELECT id, name, SIMILARITY(name, 'searchterm') as similarity 
  FROM artifacts 
  WHERE NAME % 'searchterm'  -- % operator for fuzzy matching
  ORDER BY similarity DESC;
  ```

- **Combined Search**:
  ```sql
  SELECT id, name, content, 
         TS_RANK(search_vector, query) as rank 
  FROM artifacts, TO_TSQUERY('english', 'searchterm') query 
  WHERE search_vector @@ query 
    OR content % 'searchterm'  -- pg_trgm fuzzy match fallback
  ORDER BY rank DESC;
  ```

#### Performance Considerations
- **Text Processing**: TSVECTOR parsing happens on INSERT/UPDATE, not query time
- **Index Size**: GIN indexes on TSVECTOR can be large
- **Query Optimization**: Use `TS_RANK` for relevance ranking
- **Language Support**: Specify appropriate language (e.g., 'english', 'simple')

### 7.7 Vector Search with pgvector

#### Installation
```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

#### Schema Design
```sql
-- Add vector column for embeddings
ALTER TABLE artifacts ADD COLUMN embedding VECTOR(1536);  -- Dimension depends on embedding model

-- Create HNSW index for fast approximate nearest neighbor search
CREATE INDEX idx_artifacts_embedding 
ON artifacts USING hnsw (embedding vector_cosine_ops);
```

#### Query Examples
- **Basic Vector Search**:
  ```sql
  -- Find 10 most similar artifacts to a query embedding
  SELECT id, name, 1 - (embedding <=> '[query_embedding_values]') AS similarity 
  FROM artifacts 
  ORDER BY embedding <=> '[query_embedding_values]' 
  LIMIT 10;
  ```

- **Hybrid Search (Vector + Full-Text)**:
  ```sql
  SELECT 
    id, 
    name, 
    content,
    1 - (embedding <=> '[query_embedding_values]') AS vector_similarity,
    TS_RANK(search_vector, TO_TSQUERY('english', 'keywords')) AS text_rank 
  FROM artifacts 
  WHERE search_vector @@ TO_TSQUERY('english', 'keywords')
  ORDER BY (vector_similarity * 0.7 + text_rank * 0.3) DESC  -- Weighted combination
  LIMIT 10;
  ```

- **Filtering with Vector Search**:
  ```sql
  -- Vector search with relational filters
  SELECT id, name 
  FROM artifacts 
  WHERE project_id = 'project-123' 
    AND created_at > EXTRACT(EPOCH FROM NOW() - INTERVAL '7 days')
  ORDER BY embedding <=> '[query_embedding_values]' 
  LIMIT 5;
  ```

#### Performance Optimization
- **Index Selection**: Choose appropriate distance metric (`vector_cosine_ops`, `vector_l2_ops`, `vector_ip_ops`)
- **Dimension Configuration**: Match embedding dimension to your ML model
- **HNSW Parameters**: Tune `m` (max connections) and `ef_construction` for your dataset
- **Query Optimization**: Limit result sets and use appropriate filters

### 7.8 Time-Series Data with BRIN Indexes

#### Schema Design
```sql
-- Example telemetry table with time-series data
CREATE TABLE telemetry_events (
    id UUID PRIMARY KEY,
    project_id UUID NOT NULL,
    event_type TEXT NOT NULL,
    payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Partition by time ranges
CREATE TABLE telemetry_events_partitioned (
    LIKE telemetry_events INCLUDING INDEXES
) PARTITION BY RANGE (created_at);

-- Create monthly partitions
CREATE TABLE telemetry_events_y2026m04 PARTITION OF telemetry_events_partitioned 
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

-- Create BRIN index on timestamp
CREATE INDEX idx_telemetry_created_at ON telemetry_events_partitioned USING BRIN(created_at);
```

#### Query Patterns
```sql
-- Efficient time-range queries
SELECT COUNT(*), event_type 
FROM telemetry_events 
WHERE created_at BETWEEN '2026-04-16 00:00:00' AND '2026-04-16 23:59:59'
GROUP BY event_type;

-- Partition pruning example
EXPLAIN ANALYZE 
SELECT * FROM telemetry_events 
WHERE created_at > NOW() - INTERVAL '7 days';
```

## 8. Performance Considerations

### 8.1 Query Optimization
- Use `EXPLAIN ANALYZE` to analyze query performance
- Consider materialized views for expensive, frequently-run analytics
- Implement proper indexing strategy based on query patterns

### 8.2 Connection Pooling
- Use connection pooling (PgBouncer or application-level) to manage database connections efficiently
- Configure appropriate pool sizes based on workload

### 8.3 Backup Strategy
- Implement regular backups with point-in-time recovery capability
- Consider logical backups for large datasets
- Test restore procedures regularly

## 9. Monitoring and Maintenance

### 9.1 Key Metrics to Monitor
- Query performance and execution times
- Lock contention and deadlocks
- Connection pool utilization
- Disk I/O and cache hit ratios
- Replication lag (if using streaming replication)

### 9.2 Regular Maintenance Tasks
- Vacuum and analyze tables to maintain performance
- Monitor and manage index bloat
- Update statistics for query planner
- Review and optimize long-running queries

---
**Status**: Updated with PostgreSQL extension recommendations
**Next Steps**: 
- Implementation of PostgreSQL migrations and CAS deduplication logic
- Evaluate and implement pgvector for vector search capabilities
- Implement SKIP LOCKED pattern for job queue concurrency
- Set up monitoring for extension-specific metrics

**Related ADR**: [ADR-0015: PostgreSQL as Unified Architecture Foundation](../ADR/0015-postgresql-unified-stack.md)

**Related Documents**:
- [PostgreSQL SKIP LOCKED Pattern](PostgreSQL_SKIP_LOCKED_PATTERN.md) for job queue implementation
- [INTEGRATED_DESIGN_BLUEPRINT.md](INTEGRATED_DESIGN_BLUEPRINT.md) for overall architecture
- [Observability_Spine_Design.md](Observability_Spine_Design.md) for identity and provenance
