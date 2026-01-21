# Anigma CLI Monolithic Architecture

## Vision
Create a single, self-contained `anigma-cli` binary that embeds the entire Anigma stack, making it easy to distribute and use without external dependencies or separate binaries.

## Architecture Principles

### 1. Embedded Everything
- **anigma-mcp server** embedded as library
- **ml-worker** capabilities built-in
- **anigma-daemon** (anigmad) functionality integrated
- **harmonia** governance gates included
- **Cathedral** evidence/database system
- **Contextum** code indexing with FTS5 + sqlite-vec
- **ArtifactStore** for binary bundles
- **ModelRegistry** for local ML models

### 2. Database Layer (FTS5 + sqlite-vec)
```
~/.anigma/
├── cli.db              # Main CLI database (GRDB)
│   ├── sessions        # Chat/coding sessions
│   ├── runs            # Execution runs
│   ├── steps           # Individual steps
│   ├── files_fts       # FTS5 full-text search
│   ├── code_vectors    # sqlite-vec embeddings
│   └── evidence        # Cathedral evidence chain
├── models/             # Local ML models
│   ├── llama-3.1-8b/
│   └── embeddings/
└── artifacts/          # Binary bundles (MCP servers, etc.)
```

### 3. Internal Architecture

```
AnigmaCLIExecutable (main binary)
├── Core Subsystems
│   ├── MCPServer (embedded, not subprocess)
│   ├── MLInferenceEngine (local models)
│   ├── CathedralEvidence (audit trail)
│   ├── ContextumIndexer (FTS5 + vectors)
│   └── HarmoniaGovernance (policy gates)
├── Database Layer
│   ├── SessionStore
│   ├── RunTracker
│   ├── CodebaseIndex (FTS5)
│   └── VectorStore (sqlite-vec)
├── Tool Execution
│   ├── FileTools (read/write/edit)
│   ├── ShellTools (bash)
│   ├── GitTools
│   └── SearchTools (grep/fts)
└── UI Layer
    ├── TUI (interactive mode)
    └── REPL (stdio mode)
```

## Implementation Phases

### Phase 1: Core Database Schema ✅
- [x] Session management
- [x] Run/step tracking
- [x] File operations log
- [ ] FTS5 full-text index
- [ ] sqlite-vec vector embeddings

### Phase 2: MCP Server Embedding
- [ ] Convert AnigmaMCPExecutable to library mode
- [ ] Embed MCP server in CLI process
- [ ] Tool routing from CLI → MCP tools
- [ ] Unified database backend

### Phase 3: ML Inference Integration
- [ ] Embed MLWorker capabilities
- [ ] Local model loading (llama/embeddings)
- [ ] Vector embedding generation
- [ ] Semantic search via vectors

### Phase 4: Code Indexing (Contextum)
- [ ] FTS5 schema for code search
- [ ] sqlite-vec for semantic search
- [ ] Incremental indexing on file changes
- [ ] Multi-strategy search (exact, fuzzy, semantic)

### Phase 5: Tool Execution Engine
- [ ] File tools (with safety checks)
- [ ] Shell tools (sandboxed)
- [ ] Git integration
- [ ] Search tools (FTS + vector)

### Phase 6: Governance Integration
- [ ] Harmonia policy gates
- [ ] Cathedral evidence logging
- [ ] Loop breakers
- [ ] Safety constraints

### Phase 7: Distribution
- [ ] Single binary build
- [ ] Embedded resources (schemas, prompts)
- [ ] First-run initialization
- [ ] Model auto-download

## Benefits

1. **Single Binary**: One file to install, no separate MCP server
2. **Offline Capable**: Local models, no API required
3. **Fast**: No IPC overhead, shared memory
4. **Secure**: Single attack surface, governed execution
5. **Auditable**: Cathedral evidence chain for all operations
6. **Smart Search**: FTS5 + vector embeddings for code understanding

## Database Schema

### Sessions Table
```sql
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    mode TEXT NOT NULL, -- 'chat', 'agentic', 'tool'
    metadata TEXT -- JSON
);
```

### Runs Table
```sql
CREATE TABLE runs (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    completed_at INTEGER,
    status TEXT NOT NULL, -- 'running', 'success', 'error'
    FOREIGN KEY (session_id) REFERENCES sessions(id)
);
```

### Steps Table
```sql
CREATE TABLE steps (
    id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL,
    step_number INTEGER NOT NULL,
    tool_name TEXT NOT NULL,
    input TEXT NOT NULL,
    output TEXT,
    status TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (run_id) REFERENCES runs(id)
);
```

### FTS5 Code Index
```sql
CREATE VIRTUAL TABLE code_fts USING fts5(
    file_path,
    content,
    language,
    tokenize='porter unicode61'
);
```

### Vector Embeddings
```sql
CREATE VIRTUAL TABLE code_vectors USING vec0(
    file_path TEXT PRIMARY KEY,
    embedding FLOAT[384],
    content_hash TEXT
);
```

### Cathedral Evidence
```sql
CREATE TABLE evidence_chain (
    id TEXT PRIMARY KEY,
    step_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    payload TEXT NOT NULL,
    hash TEXT NOT NULL,
    prev_hash TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (step_id) REFERENCES steps(id)
);
```

## Current Status

### Completed
- ✅ CLI module structure (Core, Eventing, Providers, Router, Governance, Orchestrator)
- ✅ MCP integration layer (AnigmaCLIMCP)
- ✅ Basic database module (AnigmaCLIDatabase)
- ✅ Model registry integration

### In Progress
- 🚧 FTS5 + sqlite-vec schema
- 🚧 Embedded MCP server
- 🚧 ML inference integration

### Next Steps
1. Complete database schema with FTS5 + vectors
2. Embed MCP server as library
3. Integrate ML worker for local inference
4. Build code indexing pipeline
5. Implement tool execution engine
6. Add governance layer
7. Create single binary distribution

## Distribution Strategy

### Build Configuration
```swift
// Package.swift modification
.executableTarget(
    name: "AnigmaCLIExecutable",
    dependencies: [
        // All core modules embedded
        "AnigmaMCPModule",      // MCP server
        "MLWorkerCommon",        // ML inference
        "HarmoniaModule",        // Governance
        "CathedralModule",       // Evidence
        "ContextumModule",       // Indexing
        "ArtifactStoreModule",   // Artifacts
        "ModelRegistryModule",   // Models
        // Everything else...
    ],
    resources: [
        .copy("Resources/schemas"),
        .copy("Resources/prompts"),
    ]
)
```

### Release Build
```bash
swift build -c release --product anigma-cli
strip .build/release/anigma-cli
# Single binary: ~50MB (with models: ~5GB)
```

## Usage Examples

```bash
# First run: initialize database
anigma-cli init

# Index current codebase
anigma-cli index .

# Chat mode with local model
anigma-cli chat

# Agentic mode
anigma-cli agent "add logging to UserService"

# Tool mode
anigma-cli tool edit --file src/main.rs --old "TODO" --new "DONE"

# Search (FTS5 + vector hybrid)
anigma-cli search "authentication middleware"

# Show evidence chain
anigma-cli evidence --session <id>
```

## Next Implementation Steps

1. **Complete Database Schema** (2 hours)
   - Add FTS5 virtual tables
   - Add sqlite-vec extension
   - Migration system

2. **Embed MCP Server** (4 hours)
   - Refactor AnigmaMCPExecutable → library
   - In-process tool routing
   - Shared database access

3. **ML Integration** (6 hours)
   - Embed MLWorker
   - Local model loading
   - Vector embedding generation

4. **Code Indexing** (4 hours)
   - FTS5 indexer
   - Vector embedder
   - Incremental updates

5. **Tool Engine** (8 hours)
   - Safe file operations
   - Shell sandboxing
   - Git integration

6. **Distribution** (4 hours)
   - Resource embedding
   - Single binary build
   - Installation script

**Total: ~28 hours of focused work**
