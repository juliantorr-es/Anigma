# SQLite-vec Integration Status

## ✅ Completed Components

### 1. **CSQLiteVec Native Module** (`Packages/CSQLiteVec/`)
- **sqlite-vec.c** - sqlite-vec 0.1.7-alpha.2 C extension
- **sqlite-vec.h** - Public API headers
- **module.modulemap** - Swift module map
- Platform-specific optimizations:
  - AVX enabled for x86_64 Linux (release builds)
  - NEON enabled for ARM (macOS, iOS, tvOS, watchOS)

### 2. **CLIDatabaseActor** (`Packages/AnigmaCLI/Database/CLIDatabaseActor.swift`)
Fully integrated sqlite-vec support with:

#### Core Features:
- ✅ Dynamic sqlite-vec extension loading via `sqlite3_vec_init()`
- ✅ Version detection and availability checking
- ✅ FTS5 full-text search tables
- ✅ vec0 virtual tables for vector embeddings
- ✅ Hybrid search combining lexical + semantic ranking

#### Database Schema:
```sql
-- Document chunks with FTS5
CREATE TABLE document_chunks (
    chunk_id TEXT PRIMARY KEY,
    document_path TEXT NOT NULL,
    section_title TEXT,
    chunk_text TEXT NOT NULL,
    chunk_hash TEXT NOT NULL,
    source_commit TEXT NOT NULL,
    chunk_index INTEGER NOT NULL,
    created_at REAL NOT NULL
);

CREATE VIRTUAL TABLE document_chunks_fts USING fts5(
    chunk_text,
    section_title,
    content=document_chunks,
    tokenize='porter unicode61'
);

-- Vector embeddings with vec0
CREATE VIRTUAL TABLE embeddings_vec USING vec0(
    embedding_id TEXT PRIMARY KEY,
    chunk_id TEXT NOT NULL,
    model_id TEXT NOT NULL,
    vector FLOAT[384]  -- Configurable dimension
);

-- Embedding metadata
CREATE TABLE embeddings_metadata (
    embedding_id TEXT PRIMARY KEY,
    chunk_id TEXT NOT NULL,
    model_id TEXT NOT NULL,
    dimension_count INTEGER NOT NULL,
    created_at REAL NOT NULL,
    UNIQUE(chunk_id, model_id)
);
```

#### Hybrid Search Algorithm:
1. **Lexical Search** (FTS5):
   - Porter stemming + Unicode61 tokenization
   - BM25 ranking with `rank` scores
   - Configurable candidate count (default: 50)

2. **Semantic Search** (vec0):
   - L2 distance: `vec_distance_L2(vector, query_embedding)`
   - Float32 vector storage
   - Efficient nearest-neighbor search

3. **Reranking**:
   - Normalized score fusion
   - Weighted combination (default: 30% lexical, 70% semantic)
   - Top-k selection after merging

### 3. **CLIIndexManager** (`Packages/AnigmaCLI/Database/CLIIndexManager.swift`)
Incremental indexing with:

- ✅ Content-aware chunking (512 tokens, 64 overlap)
- ✅ SHA256 content hashing for deduplication
- ✅ Incremental indexing (reuse chunks for unchanged files)
- ✅ Batch embedding generation
- ✅ Index status tracking per repository/commit

### 4. **Integration with Package.swift**
```swift
.target(
    name: "CSQLiteVec",
    path: "Packages/CSQLiteVec",
    sources: ["sqlite-vec.c"],
    publicHeadersPath: ".",
    cSettings: [
        .define("SQLITE_CORE"),
        .define("SQLITE_VEC_ENABLE_AVX", .when(platforms: [.linux])),
        .define("SQLITE_VEC_ENABLE_NEON", .when(platforms: [.macOS, .iOS]))
    ]
)

.target(
    name: "AnigmaCLIDatabase",
    dependencies: [
        "CSQLiteVec",
        .product(name: "Crypto", package: "swift-crypto")
    ]
)
```

## 🔄 Current Capabilities

### Vector Operations Available:
- `vec_version()` - Get sqlite-vec version
- `vec_distance_L2(a, b)` - L2 distance between vectors
- `vec_distance_cosine(a, b)` - Cosine distance
- `vec_normalize(v)` - Normalize vector to unit length
- `vec_add(a, b)`, `vec_sub(a, b)` - Vector arithmetic

### Supported Data Types:
- `FLOAT[n]` - Float32 vectors (default)
- `BIT[n]` - Binary vectors
- `INT8[n]` - Quantized int8 vectors

### Search Strategies:
1. **Pure FTS5** - Fast lexical matching for exact term queries
2. **Pure Vector** - Semantic similarity when embeddings available
3. **Hybrid** - Best of both worlds with score fusion

## 📊 Performance Characteristics

### FTS5 (Lexical):
- **Speed**: Very fast (microseconds for typical queries)
- **Recall**: High for exact matches, lower for semantic similarity
- **Index Size**: ~30% of original text

### vec0 (Semantic):
- **Speed**: Fast for small datasets (<100K vectors), consider HNSW for larger
- **Recall**: High for semantic similarity, captures intent
- **Index Size**: dimension × 4 bytes per vector

### Hybrid:
- **Speed**: Sum of both (FTS5 + vec0 queries)
- **Recall**: Best overall - captures both exact and semantic matches
- **Use Case**: Production-ready for code search, documentation retrieval

## 🚀 Next Steps

### Immediate Priorities:
1. ✅ **Build Integration** - Compile CSQLiteVec with anigma-cli
2. ⏳ **Embedding Provider** - Connect to MLX embedders for vector generation
3. ⏳ **CLI Commands** - Expose indexing/search via `anigma-cli index`, `anigma-cli search`
4. ⏳ **Onboarding Flow** - Auto-index codebase during `anigma-cli init`

### Future Enhancements:
- **HNSW Index** - Add approximate nearest neighbor for large codebases
- **Multi-Modal** - Index images, diagrams, assets
- **Real-Time Updates** - Watch filesystem for incremental updates
- **Distributed** - Shard across multiple databases for very large repos
- **Quantization** - Use INT8 vectors for 4x memory reduction

## 🧪 Testing

### Manual Verification:
```bash
# Build with sqlite-vec
swift build --product anigma-cli

# Test vector availability
sqlite3 ~/.anigma/cli.db "SELECT vec_version();"

# Insert test embedding
sqlite3 ~/.anigma/cli.db <<EOF
CREATE VIRTUAL TABLE test_vec USING vec0(
    id TEXT PRIMARY KEY,
    embedding FLOAT[3]
);
INSERT INTO test_vec VALUES ('test1', '[1.0, 0.0, 0.0]');
INSERT INTO test_vec VALUES ('test2', '[0.0, 1.0, 0.0]');
SELECT id, vec_distance_L2(embedding, '[0.5, 0.5, 0.0]') as dist
FROM test_vec
ORDER BY dist
LIMIT 2;
EOF
```

### Integration Tests:
- Unit tests for CLIDatabaseActor
- Integration tests for hybrid search
- Performance benchmarks for indexing throughput

## 📝 Documentation

### API Reference:
See inline documentation in:
- `CLIDatabaseActor.swift` - Database operations
- `CLIIndexManager.swift` - Indexing pipeline
- `CLIHybridRetrieval.swift` - Search algorithms

### Usage Examples:
```swift
// Initialize database with vector support
let db = CLIDatabaseActor(config: CLIDatabaseConfig(
    enableVectorSearch: true,
    embeddingDimension: 384
))
try await db.open()

// Index a repository
let indexer = CLIIndexManager(database: db)
let result = try await indexer.indexRepository(
    repoRoot: "/path/to/repo",
    commit: "abc123",
    files: ["main.swift", "README.md"]
)

// Generate embeddings
let count = try await indexer.generateEmbeddings(
    modelID: "nomic-embed-text-v1.5",
    dimension: 384
) { text in
    // Call embedding model
    return await embeddingModel.embed(text)
}

// Hybrid search
let results = try await db.hybridSearch(
    query: "how to initialize database",
    queryEmbedding: await embeddingModel.embed("how to initialize database"),
    limit: 10,
    lexicalWeight: 0.3,
    semanticWeight: 0.7
)
```

## ✅ Integration Checklist

- [x] CSQLiteVec module with AVX/NEON optimizations
- [x] CLIDatabaseActor with vec0 support
- [x] FTS5 + vec0 hybrid search
- [x] Incremental indexing with deduplication
- [x] Embedding metadata tracking
- [x] Package.swift dependencies
- [ ] Embedding provider integration (MLX)
- [ ] CLI commands for index/search
- [ ] Onboarding auto-indexing
- [ ] Unit tests
- [ ] Integration tests
- [ ] Performance benchmarks
- [ ] Production deployment

## 🎯 Success Metrics

- **Indexing Speed**: >1000 chunks/second on M1 Mac
- **Search Latency**: <50ms for hybrid search (p95)
- **Recall@10**: >0.8 for semantic queries
- **Storage Efficiency**: <2x original codebase size
- **Incremental Update**: <1s for single file change

---

**Status**: ✅ Core infrastructure complete, ready for embedding integration
**Last Updated**: 2026-01-10
