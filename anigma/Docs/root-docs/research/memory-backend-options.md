> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


---
title: Memory Backend Options for Harmonia V3
category: research
owner: Engineering Team
status: research
created: 2026-04-16
phase: research
epic: harmonia-v3
---

# Research: Memory Backend Options for Harmonia V3

## Executive Summary

This document evaluates memory backend options for Harmonia V3. The current Harmonia V2 implementation provides a tri-memory architecture (short-term, long-term, persistent) with pluggable storage backends. Key evaluation includes:

1. **Harmonia V2 Memory Layer** (current state)
2. **Contextum Integration** (proposed enhancement)
3. **Alternative Options** (competitive evaluation)
4. **Recommendations** (path forward)

**Key Finding**: Harmonia V2 has a solid foundation with the tri-memory model and pluggable MemoryStore interface. Evaluation should focus on:
- Adding embedding/vector search capabilities
- Implementing scalable persistence backend
- Supporting multi-tenant isolation
- Optimizing performance for high-volume queries

---

## Part 1: Harmonia V2 Memory Layer Analysis

### Current Architecture

Harmonia V2 implements a **tri-memory architecture** with three distinct memory tiers:

#### 1. Short-Term Memory
- **Scope**: Session-bounded, task-specific context
- **Lifetime**: Configurable TTL (default: 1 hour)
- **Content Types**: 
  - Interaction history
  - Transient artifacts
  - Draft documents
  - Intermediate results
  - Reasoning traces
  - Working context
- **Retrieval**: Session/tenant based queries
- **Use Case**: Task execution context, intermediate state

#### 2. Long-Term Memory
- **Scope**: Tenant-scoped knowledge
- **Lifetime**: Persistent until explicitly removed
- **Subject to**: Policy changes, legal requirements
- **Retrieval**: By content type, metadata matching
- **Use Case**: Knowledge base, learned patterns, user preferences

#### 3. Persistent Memory
- **Scope**: System-wide, immutable
- **Change Policy**: Only through releases
- **Content**: Control catalogs, schemas, rules
- **Retrieval**: By catalog/schema/rule ID
- **Use Case**: Configuration, reference data, system state

### MemoryManager API

Current public API in `HarmoniaMemory.swift`:

```swift
public actor MemoryManager {
    // Store memory item
    func store(_ item: ShortTermMemory) async throws -> String
    
    // Retrieve by query
    func retrieve(matching query: MemoryQuery) async throws -> [ShortTermMemory]
    
    // Vector similarity search
    func searchSimilar(
        to embedding: [Float],
        embeddingModel: String?,
        projectId: String,
        limit: Int,
        threshold: Float?,
        scanLimit: Int?
    ) async throws -> [VectorSearchResult]
}
```

### MemoryStore Interface

The MemoryManager is pluggable via `MemoryStore` protocol (implementation location: HarmoniaSurface):

```swift
protocol MemoryStore: Actor, Sendable {
    // Store content with metadata
    func store(
        content: String,
        metadata: [String: String],
        embedding: [Float]?
    ) async throws -> String
    
    // Retrieve by session/tenant
    func retrieve(
        sessionId: String,
        tenantId: String,
        limit: Int
    ) async throws -> [StorageRecord]
    
    // Vector similarity search
    func searchSimilar(
        embedding: [Float],
        embeddingModel: String?,
        projectId: String,
        limit: Int,
        threshold: Float?,
        scanLimit: Int?
    ) async throws -> [SimilarityResult]
}
```

### Current Capabilities

| Capability | Status | Notes |
|------------|--------|-------|
| Session-scoped short-term | ✅ Implemented | With TTL expiration |
| Tenant-scoped long-term | ✅ Implemented | Persistent storage |
| System-wide persistent | ✅ Implemented | Release-controlled |
| Metadata tagging | ✅ Implemented | [String: String] format |
| Vector embeddings | 🟡 Stubbed | `TODO: Wire embedding generation` |
| Vector similarity search | 🟡 Interface ready | Backend implementation needed |
| Multi-tenant isolation | ✅ Designed | Via tenantId in queries |
| Data sensitivity levels | ✅ Implemented | 6 sensitivity tiers |
| Actor-based concurrency | ✅ Implemented | Async/await safe |

### Known Limitations

1. **Embedding Generation**: Currently stubbed (`embedding: nil` in store())
   - No embedding model selection
   - No semantic search capability
   - Requires external embeddings or model integration

2. **Persistence Backend**: Defaults to nil (returns notImplemented)
   - Requires concrete MemoryStore implementation
   - Currently only `LocalMemoryStoreAdapter` in HarmoniaSurface
   - Not production-ready for distributed deployments

3. **Vector Search**: Interface defined but backend not specified
   - No vector database integration
   - Scale limits unknown
   - Performance characteristics undefined

4. **Query Semantics**: Limited to simple metadata matching
   - No full-text search
   - No complex filtering
   - No aggregation queries

### Readiness Assessment for V3

**Overall Readiness: 65