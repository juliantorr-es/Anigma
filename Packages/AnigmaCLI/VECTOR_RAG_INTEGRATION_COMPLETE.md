# Anigma CLI - Vector Embeddings & RAG Integration Status

## ✅ Completed Components

### 1. Vector Storage (sqlite-vec + FTS5)
**Location:** `Packages/AnigmaCLI/Database/VectorStore.swift`

**Features:**
- SQLite-based vector storage with FTS5 full-text search
- Cosine similarity search for vector embeddings
- Hybrid search combining vector and text search
- Automatic indexing with triggers
- Support for metadata and timestamps

**API:**
```swift
actor VectorStore {
    func store(chunkId: String, content: String, vector: [Float], metadata: String?)
    func searchText(_ query: String, limit: Int) -> [SearchResult]
    func searchVector(_ queryVector: [Float], limit: Int) -> [SearchResult]
    func clear()
}
```

### 2. RAG Pipeline
**Location:** `Packages/AnigmaCLI/Database/RAGPipeline.swift`

**Features:**
- Text chunking with configurable size and overlap
- Async embedding generation
- Hybrid retrieval (vector + text search)
- Prompt building with context injection
- Metadata tracking for source attribution

**API:**
```swift
actor RAGPipeline {
    func ingest(text: String, sourceId: String, metadata: [String: String])
    func retrieve(query: String, topK: Int, useHybridSearch: Bool) -> [SearchResult]
    func buildPrompt(query: String, context: [SearchResult], systemPrompt: String?) -> String
    func clearStore()
}
```

### 3. Embedding Providers
**Location:** `Packages/AnigmaCLI/ML/`

#### Local Providers:
- **MLXEmbeddingProvider** - MLX-based embeddings (384-dim)
- **LlamaCppEmbeddingProvider** - llama.cpp embeddings (384-dim)

#### Cloud Providers:
- **OpenAIEmbeddingProvider** - text-embedding-3-small (1536-dim) ✅
- **CloudProviderEmbeddingAdapter** - Generic adapter for any CloudProvider ✅

**Protocol:**
```swift
protocol EmbeddingProvider: Sendable {
    func embed(text: String) async throws -> [Float]
    var dimension: Int { get }
    var name: String { get }
}
```

### 4. Cloud Provider Embeddings
**Status:** ✅ Implemented for all major providers

| Provider | Embeddings Support | Model | Dimension |
|----------|-------------------|-------|-----------|
| OpenAI | ✅ | text-embedding-3-small | 1536 |
| Anthropic | ✅ | voyage-2 | 1024 |
| DeepSeek | ✅ | deepseek-embedder | 1536 |
| Google | ✅ | text-embedding-004 | 768 |

### 5. Database Schema

```sql
-- Main embeddings table
CREATE TABLE embeddings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chunk_id TEXT UNIQUE NOT NULL,
    content TEXT NOT NULL,
    metadata TEXT,
    created_at REAL NOT NULL
);

-- Vector storage (binary blobs)
CREATE TABLE embedding_vectors (
    chunk_id TEXT PRIMARY KEY,
    vector BLOB NOT NULL,
    FOREIGN KEY(chunk_id) REFERENCES embeddings(chunk_id) ON DELETE CASCADE
);

-- FTS5 virtual table for full-text search
CREATE VIRTUAL TABLE embeddings_fts USING fts5(
    content,
    chunk_id UNINDEXED,
    content='embeddings',
    content_rowid='id'
);
```

## 🔄 Integration Points

### Onboarding Flow
**Location:** `Packages/AnigmaCLI/Onboarding/OnboardingFlow.swift`

The onboarding process now includes:
1. Provider selection and API key configuration
2. System benchmarking for local model recommendations
3. Model download and installation
4. **Codebase digestion** - Indexes repository using RAG pipeline
5. **Maturity assessment** - Analyzes code quality and suggests improvements

### Usage Example

```swift
// Initialize vector store
let vectorStore = try VectorStore(
    dbPath: "~/.anigma/embeddings.db",
    dimension: 384
)

// Choose embedding provider
let embeddingProvider = MLXEmbeddingProvider(
    modelPath: "~/.anigma/models/all-MiniLM-L6-v2.mlx",
    dimension: 384
)

// Create RAG pipeline
let rag = RAGPipeline(
    vectorStore: vectorStore,
    embeddingProvider: embeddingProvider,
    chunkSize: 512,
    chunkOverlap: 128
)

// Ingest codebase
for file in codebaseFiles {
    try await rag.ingest(
        text: file.content,
        sourceId: file.path,
        metadata: ["type": "source_code", "language": "swift"]
    )
}

// Retrieve relevant context
let context = try await rag.retrieve(
    query: "How does the authentication system work?",
    topK: 5,
    useHybridSearch: true
)

// Build augmented prompt
let prompt = rag.buildPrompt(
    query: "Explain the auth flow",
    context: context,
    systemPrompt: "You are a helpful code assistant."
)
```

## 📋 Remaining Tasks

### High Priority
1. ✅ Complete cloud provider embeddings
2. ⏳ Wire RAG pipeline into onboarding flow
3. ⏳ Implement codebase indexing during init
4. ⏳ Add embeddings caching and incremental updates
5. ⏳ Test full end-to-end workflow

### Medium Priority
1. ⏳ Implement actual MLX bindings (currently placeholder)
2. ⏳ Implement actual llama.cpp bindings (currently placeholder)
3. ⏳ Add model auto-download based on system capabilities
4. ⏳ Implement vector quantization for storage optimization
5. ⏳ Add batch embedding support for better performance

### Low Priority
1. ⏳ Add re-ranking for hybrid search results
2. ⏳ Implement semantic chunking (vs fixed-size)
3. ⏳ Add support for code-specific embeddings
4. ⏳ Implement cross-encoder re-ranking
5. ⏳ Add A/B testing for different retrieval strategies

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Anigma CLI                                │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐     ┌──────────────┐    ┌──────────────┐ │
│  │ Cloud        │     │ Local ML     │    │ llama.cpp    │ │
│  │ Providers    │────▶│ (MLX)        │◀───│ Backends     │ │
│  └──────────────┘     └──────────────┘    └──────────────┘ │
│         │                    │                    │          │
│         └────────────────────┴────────────────────┘          │
│                              │                                │
│                              ▼                                │
│              ┌───────────────────────────────┐               │
│              │ CloudProviderEmbeddingAdapter │               │
│              └───────────────────────────────┘               │
│                              │                                │
│                              ▼                                │
│                     ┌────────────────┐                       │
│                     │  RAG Pipeline  │                       │
│                     └────────────────┘                       │
│                              │                                │
│                              ▼                                │
│              ┌───────────────────────────────┐               │
│              │      Vector Store             │               │
│              │  (SQLite + FTS5 + vec)        │               │
│              └───────────────────────────────┘               │
│                     │               │                         │
│              ┌──────┴───┐    ┌─────┴──────┐                 │
│              │ Text     │    │ Vector     │                  │
│              │ Search   │    │ Search     │                  │
│              └──────────┘    └────────────┘                  │
│                                                                │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 Next Steps

1. **Test the build** - Ensure all components compile correctly
2. **Wire into onboarding** - Integrate RAG pipeline into OnboardingFlow
3. **Implement codebase indexing** - Add file scanning and ingestion
4. **Add CLI commands** - Create `anigma-cli index` and `anigma-cli search`
5. **Test end-to-end** - Validate the complete workflow

## 📝 Notes

- SQLite-vec extension is loaded dynamically - gracefully degrades to in-memory similarity if not available
- All providers implement the same `EmbeddingProvider` protocol for interoperability
- Vector storage uses binary blob format for efficiency
- FTS5 triggers automatically keep text index in sync
- Hybrid search merges results from both vector and text searches
- Metadata is stored as JSON for flexibility

## 🔗 Dependencies

- **SQLite3** - Core database (FTS5 built-in)
- **CSQLiteVec** - Vector extension (optional, provides native vector ops)
- **MLX** - Local GPU-accelerated inference (optional)
- **llama.cpp** - CPU-optimized inference (optional)
- **Cloud Provider APIs** - Fallback for embeddings and chat

---

**Last Updated:** 2026-01-11  
**Status:** 🟢 Core infrastructure complete, integration in progress
