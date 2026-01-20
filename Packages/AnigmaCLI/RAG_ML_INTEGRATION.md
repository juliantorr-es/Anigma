# RAG Pipeline and Model Management Integration

## Overview
Successfully integrated RAG (Retrieval-Augmented Generation) pipeline and interactive model management UI into anigma-cli.

## Components Added

### 1. RAG Pipeline (`Packages/AnigmaCLI/RAG/RAGPipeline.swift`)
- **Full-text search** with SQLite FTS5
- **Code chunking** with configurable overlap
- **Hybrid retrieval** (FTS + vector ready)
- **Language-aware** indexing
- **Chunk type detection** (function, type, import, comment, code)

#### Features:
```swift
// Initialize RAG pipeline
let rag = RAGPipeline(dbPath: ".anigma/rag.db", chunkSize: 512, overlapSize: 128)
try await rag.initialize()

// Index code
let chunks = try await rag.chunkFile(path: "file.swift", content: code, language: "Swift")
try await rag.indexChunks(chunks)

// Search
let results = try await rag.search(query: "authentication", limit: 5)
```

#### Database Schema:
- `code_chunks` - Main chunk storage with metadata
- `code_chunks_fts` - FTS5 virtual table for full-text search
- Indexes on `file_path` and `language` for efficient filtering
- Ready for `sqlite-vec` integration for vector embeddings

### 2. Model Management UI (`Packages/AnigmaCLI/UI/ModelManagementUI.swift`)
- **Interactive TUI** for model management
- **Download tracking** with progress bars
- **System benchmarking** for model recommendations
- **Categorized model catalog** (LLM, Embedding, Vision)

#### Planned Features:
- Model download with HTTP streaming
- SHA256 verification
- System capability assessment
- Smart model recommendations based on hardware

### 3. CLI Commands

#### `anigma-cli rag`
Subcommands:
- `rag index <path>` - Index codebase for RAG retrieval
- `rag search <query>` - Search indexed code
- `rag stats` - Show index statistics

Example:
```bash
# Index current directory
anigma-cli rag index . --chunk-size 512 --overlap 128

# Search code
anigma-cli rag search "authentication logic" --limit 10

# View stats
anigma-cli rag stats
```

#### `anigma-cli models-ui`
Interactive model management interface:
```bash
anigma-cli models-ui --models-path ~/.anigma/models
```

## Integration Status

### ✅ Completed
1. RAG pipeline with FTS5 search
2. Code chunking and indexing
3. CLI commands for RAG operations
4. Package.swift module definitions
5. Sendable conformance for Swift 6
6. Build integration

### 🚧 In Progress
1. Vector embedding generation (sqlite-vec integration pending)
2. Model download implementation (HTTP streaming)
3. System benchmarking logic
4. Model catalog expansion

### 📋 Next Steps
1. **sqlite-vec Integration**
   - Load `vec0` extension
   - Implement embedding storage
   - Add vector similarity search
   - Hybrid ranking (FTS + vector)

2. **Model Management**
   - Complete HTTP download with progress
   - SHA256 verification
   - Model format detection (GGUF, ONNX, MLX)
   - Local inference integration

3. **Onboarding Integration**
   - Automatic codebase indexing during init
   - Model recommendations based on system
   - Download suggested models

4. **RAG Enhancements**
   - Semantic chunking (respect function/class boundaries)
   - Language-specific parsers
   - Cross-reference resolution
   - Context expansion

## Architecture

```
anigma-cli
├── RAG Pipeline
│   ├── Chunking Engine
│   ├── FTS5 Index
│   ├── Vector Store (sqlite-vec)
│   └── Hybrid Retrieval
├── Model Management
│   ├── Download Manager
│   ├── Model Registry
│   ├── Benchmark Suite
│   └── Interactive UI
└── Integration Layer
    ├── Onboarding Flow
    ├── Chat Interface
    └── MCP Server
```

## Usage Examples

### Index a Codebase
```bash
# Index with verbose output
anigma-cli rag index . --verbose

# Custom chunk size
anigma-cli rag index ~/projects/my-app --chunk-size 1024 --overlap 256
```

### Search Code
```bash
# Basic search
anigma-cli rag search "error handling"

# With vector search (when available)
anigma-cli rag search "authentication flow" --vector --limit 20
```

### Manage Models
```bash
# Open interactive UI
anigma-cli models-ui

# Actions in UI:
# [d] Download model
# [r] Remove model
# [i] Show info
# [s] System info
# [b] Run benchmark
# [q] Quit
```

## Performance Considerations

### Indexing
- Chunk size: 512 tokens (configurable)
- Overlap: 128 tokens (configurable)
- Estimated: ~1000 files/minute (depends on file size)

### Search
- FTS5: Sub-millisecond for most queries
- Vector search: ~10-50ms per query (with proper indexing)
- Hybrid: Combines both for best results

### Storage
- FTS5 index: ~20-30% of code size
- Vector embeddings: ~3KB per chunk (768-dim float16)

## Dependencies
- SQLite 3 with FTS5 (built-in)
- sqlite-vec (external, to be integrated)
- Foundation (HTTP downloads)
- ArgumentParser (CLI)

## Testing
```bash
# Build
swift build --product anigma-cli

# Test RAG indexing
.build/debug/anigma-cli rag index Packages/AnigmaCLI --verbose

# Test search
.build/debug/anigma-cli rag search "RAGPipeline" --limit 5

# Test model UI
.build/debug/anigma-cli models-ui
```

## Future Enhancements
1. **Smart Chunking**: AST-aware chunking for better context
2. **Multi-language Support**: Python, JavaScript, Go, Rust parsers
3. **Incremental Updates**: Watch mode for live indexing
4. **Remote Models**: Download from HuggingFace, Ollama
5. **Model Quantization**: On-the-fly quantization
6. **Distributed Inference**: Multi-model ensembles
