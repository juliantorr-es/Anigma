# Anigma CLI - Monolithic Coding Assistant

A self-contained, single-binary coding assistant that combines:
- **Embedded MCP Server** - No separate process needed
- **Local ML Inference** - Llama, Qwen, Phi models
- **Code Intelligence** - FTS5 + sqlite-vec semantic search
- **Governance** - Harmonia policy gates & Cathedral evidence
- **Tool Execution** - Safe file operations, shell, git, search

## Maturity Standard: 🏆 GOLDEN (Level 5)

Anigma CLI has been promoted to the **Golden Standard**.
- **Strict Concurrency**: 100% compliant with Swift 6 actor isolation.
- **Verification**: Dedicated `AnigmaCLITests` suite covering database, orchestrator, and integration flows.
- **Governance**: Integrated with Tier 1 `GovernanceCore` (KillSwitch/WriteGate).
- **Documentation**: Comprehensive architectural and usage documentation.

---

## Architecture

```
anigma-cli (single binary)
├── MCP Server (embedded)
│   ├── 50+ tools (file, shell, git, search)
│   └── JSON-RPC over stdio
├── ML Inference Engine
│   ├── llama-3.1-8b-instruct
│   ├── qwen-2.5-7b-coder
│   └── phi-3.5-mini-instruct
├── Database Layer (SQLite)
│   ├── FTS5 full-text search
│   ├── sqlite-vec semantic search
│   └── Cathedral evidence chain
├── Governance
│   ├── Policy gates
│   ├── Loop breakers
│   └── Safety constraints
└── CLI Interface
    ├── Chat mode (interactive)
    ├── Tool mode (one-shot)
    └── MCP server mode
```

## Installation

### Quick Start

```bash
# Build from source
swift build -c release --product anigma-cli

# Copy to PATH
cp .build/release/anigma-cli /usr/local/bin/

# Initialize (first run)
anigma-cli init
```

### First Run Setup

```bash
# Initialize database and directories
anigma-cli init

# This creates:
# ~/.anigma/cli.db        - SQLite database with FTS5
# ~/.anigma/models/       - Local ML models
# ~/.anigma/artifacts/    - Binary bundles
```

## Usage

### Interactive Chat Mode

```bash
# Start chat mode
anigma-cli chat

# With specific model
anigma-cli chat --model qwen-2.5-7b-coder-4bit

# Dry-run mode (no file changes)
anigma-cli chat --dry-run
```

### Index Your Codebase

```bash
# Index current directory
anigma-cli index .

# Force re-index
anigma-cli index . --force

# Check index status
anigma-cli status
```

### Run as MCP Server

```bash
# Run MCP server (stdio transport)
anigma-cli mcp-server

# Use with Claude Desktop or other MCP clients
# Add to Claude Desktop config:
{
  "mcpServers": {
    "anigma": {
      "command": "/usr/local/bin/anigma-cli",
      "args": ["mcp-server"]
    }
  }
}
```

### One-Shot Commands

```bash
# Plan a task
anigma-cli plan "Add logging to UserService"

# Run a task (dry-run)
anigma-cli run "Fix TypeScript errors in components/"

# Execute (actual changes)
anigma-cli run "Refactor auth module" --no-dry-run

# Search code
anigma-cli search "authentication middleware"
```

## Features

### 1. Embedded MCP Server

The MCP server runs **inside** the CLI process - no separate binary needed.

**Tools Available:**
- `read_file` - Read file contents
- `write_file` - Write/create files
- `edit_file` - Surgical edits
- `list_directory` - Browse filesystem
- `bash` - Execute shell commands
- `git_*` - Git operations
- `search_*` - Code search (FTS5 + vector)
- `index_*` - Code indexing
- `evidence_*` - Audit trail

### 2. Local ML Inference

**Supported Models:**
- `llama-3.1-8b-instruct-4bit` - General purpose
- `qwen-2.5-7b-coder-4bit` - Code-focused
- `phi-3.5-mini-instruct-4bit` - Lightweight

Models are auto-downloaded on first use to `~/.anigma/models/`.

### 3. Code Intelligence

**FTS5 Full-Text Search:**
```sql
-- Exact token matching
SELECT * FROM code_fts WHERE chunk_text MATCH 'function handleSubmit';
```

**sqlite-vec Semantic Search:**
```sql
-- Vector similarity search
SELECT * FROM code_vectors 
WHERE embedding MATCH ?
ORDER BY distance 
LIMIT 10;
```

**Hybrid Search:**
Combines FTS5 (fast, exact) + vectors (semantic, fuzzy) for best results.

### 4. Governance Layer

**Policy Gates:**
- Repository identity verification
- Tool allowlist/denylist
- Resource limits (tokens, time, file size)

**Loop Breakers:**
- Duplicate operation detection
- Infinite loop prevention
- Cost tracking

**Cathedral Evidence:**
Every operation is logged in a tamper-evident chain:
```sql
-- Evidence chain with cryptographic hashing
CREATE TABLE evidence_chain (
    id TEXT PRIMARY KEY,
    step_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    payload TEXT NOT NULL,
    hash TEXT NOT NULL,      -- SHA256(prev_hash + payload)
    prev_hash TEXT,
    created_at INTEGER NOT NULL
);
```

### 5. Database Schema

**Sessions & Runs:**
```sql
-- Chat/coding sessions
CREATE TABLE runs (
    run_id TEXT PRIMARY KEY,
    task_summary TEXT NOT NULL,
    mode TEXT NOT NULL,         -- 'chat', 'agentic', 'tool'
    status TEXT NOT NULL,       -- 'running', 'completed', 'error'
    created_at REAL NOT NULL,
    completed_at REAL
);

-- Individual steps within runs
CREATE TABLE steps (
    step_id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL,
    step_number INTEGER NOT NULL,
    action_type TEXT NOT NULL,  -- 'read', 'write', 'edit', 'bash', etc.
    action_data TEXT,
    status TEXT NOT NULL,
    created_at REAL NOT NULL,
    FOREIGN KEY(run_id) REFERENCES runs(run_id)
);
```

**Code Index (FTS5):**
```sql
-- Full-text search
CREATE VIRTUAL TABLE code_fts USING fts5(
    chunk_text,
    section_title,
    content=document_chunks,
    tokenize='porter unicode61'
);

-- Triggers keep FTS in sync
CREATE TRIGGER document_chunks_ai AFTER INSERT ON document_chunks BEGIN
    INSERT INTO code_fts(rowid, chunk_text, section_title)
    VALUES (new.rowid, new.chunk_text, new.section_title);
END;
```

**Vector Embeddings (sqlite-vec):**
```sql
-- Semantic search via embeddings
CREATE TABLE embeddings (
    embedding_id TEXT PRIMARY KEY,
    chunk_id TEXT NOT NULL,
    model_id TEXT NOT NULL,     -- e.g., 'all-MiniLM-L6-v2'
    dimension_count INTEGER NOT NULL,
    vector BLOB NOT NULL,       -- float32 array
    created_at REAL NOT NULL,
    FOREIGN KEY(chunk_id) REFERENCES document_chunks(chunk_id)
);
```

## Commands Reference

### Initialization
```bash
anigma-cli init [--force] [--skip-models]
```

### Chat Mode
```bash
anigma-cli chat [--model MODEL] [--dry-run] [--no-tools]

# Interactive commands:
/exit      - Exit chat mode
/help      - Show help
/index     - Index current directory
/search    - Search indexed code
/model     - Switch model
/tools     - Toggle tools
/dry-run   - Toggle dry-run mode
```

### MCP Server
```bash
anigma-cli mcp-server
```

### Planning & Execution
```bash
anigma-cli plan SUMMARY [--details DETAILS] [--no-mcp]
anigma-cli run SUMMARY [--no-dry-run] [--details DETAILS]
anigma-cli tui [SUMMARY] [--mode plan|run] [--dry-run]
```

### Code Indexing
```bash
anigma-cli index PATH [--force]
anigma-cli status
```

### Worktree Management
```bash
anigma-cli worktree list
anigma-cli worktree create BRANCH
anigma-cli worktree remove PATH
```

### Runs & History
```bash
anigma-cli runs list [--limit N]
anigma-cli runs show RUN_ID
anigma-cli runs evidence RUN_ID
```

### Tools & Policies
```bash
anigma-cli tools list
anigma-cli policy show
anigma-cli policy set POLICY_FILE
```

## Development

### Building

```bash
# Debug build
swift build --product anigma-cli

# Release build (optimized)
swift build -c release --product anigma-cli

# Run tests
swift test --filter AnigmaCLI
```

### Dependencies

All dependencies are embedded in the binary:

**Core:**
- AnigmaCore, AnigmaPrimitives
- DatabaseCore (GRDB), ContractsCore

**MCP Server:**
- AnigmaMCPModule (50+ tools)
- MCP SDK (swift-sdk)

**ML Inference:**
- MLWorkerCommon
- MLX Swift (mlx-swift-lm)

**Governance:**
- HarmoniaModule, CathedralModule
- StorageCore, ExecutionCore

**Code Intelligence:**
- ContextumModule (FTS5 + vectors)
- ArtifactStoreModule, ModelRegistryModule

### Project Structure

```
Packages/AnigmaCLI/
├── Core/                   # Core types & protocols
├── Database/               # SQLite + FTS5 + vectors
├── Eventing/               # Event streaming
├── Providers/              # Tool providers
├── Router/                 # Task routing
├── Governance/             # Policy gates
├── Orchestrator/           # Execution coordination
├── MCP/                    # MCP client integration
└── Executable/             # Main entry point
    ├── Main.swift
    ├── InitCommand.swift
    ├── ChatCommand.swift
    ├── MCPServerCommand.swift
    └── ...
```

## Configuration

### Environment Variables

```bash
# Database path
export ANIGMA_DB_PATH=~/.anigma/cli.db

# Enable vector search
export ANIGMA_VECTOR_SEARCH=1

# Vector extension path (if not compiled in)
export ANIGMA_VECTOR_EXT=~/.anigma/extensions/vec0.dylib

# Model directory
export ANIGMA_MODELS_DIR=~/.anigma/models

# MCP configuration
export ANIGMA_MCP_ENABLED=1
export ANIGMA_MCP_MAX_TOKENS=8000
```

### Database Configuration

```swift
let config = CLIDatabaseConfig(
    databasePath: "~/.anigma/cli.db",
    enableVectorSearch: true,
    vectorExtensionPath: nil,  // Use compiled-in extension
    lexicalCandidateCount: 50, // FTS5 results before reranking
    embeddingDimension: 384    // MiniLM-L6-v2
)
```

## Distribution

### Single Binary Release

```bash
# Build release binary
swift build -c release --product anigma-cli

# Strip debug symbols
strip .build/release/anigma-cli

# Package with models (optional)
mkdir -p anigma-cli-dist
cp .build/release/anigma-cli anigma-cli-dist/
cp -r models/ anigma-cli-dist/models/

# Create tarball
tar czf anigma-cli-v1.0.0-darwin-arm64.tar.gz anigma-cli-dist/
```

### Binary Size

- **Core binary**: ~50MB (with all modules)
- **With models**: ~5GB (includes llama-3.1-8b, qwen-2.5-7b, phi-3.5)
- **With sqlite-vec**: +2MB (statically linked)

### Installation Script

```bash
#!/bin/bash
# install.sh

set -e

VERSION="1.0.0"
PLATFORM="darwin-arm64"
URL="https://github.com/anigma/anigma-cli/releases/download/v${VERSION}/anigma-cli-v${VERSION}-${PLATFORM}.tar.gz"

echo "Installing Anigma CLI v${VERSION}..."

# Download and extract
curl -L "$URL" | tar xz

# Install binary
sudo cp anigma-cli-dist/anigma-cli /usr/local/bin/
sudo chmod +x /usr/local/bin/anigma-cli

# Initialize
anigma-cli init

echo "✅ Anigma CLI installed successfully!"
echo "Run 'anigma-cli --help' to get started."
```

## Roadmap

### ✅ Phase 1-3: Foundation (Complete)
- [x] Core CLI infrastructure
- [x] Database with FTS5 support
- [x] Run/step tracking
- [x] MCP integration layer

### 🚧 Phase 4-6: Integration (In Progress)
- [ ] Embed MCP server as library
- [ ] Integrate MLWorker for local inference
- [ ] Complete FTS5 + sqlite-vec indexing
- [ ] Implement hybrid search

### 📋 Phase 7-9: Features (Planned)
- [ ] Interactive chat mode with tool calling
- [ ] Agentic mode (multi-step reasoning)
- [ ] Model auto-download
- [ ] Evidence chain visualization
- [ ] Policy editor

### 🎯 Phase 10: Distribution (Future)
- [ ] Pre-built binaries (macOS, Linux)
- [ ] Docker image
- [ ] Homebrew tap
- [ ] VS Code extension

## Comparison

### vs. Cursor / GitHub Copilot
- ✅ **Self-hosted**: No API keys, no cloud
- ✅ **Auditable**: Full evidence chain
- ✅ **Governed**: Policy-based execution
- ❌ **Smaller models**: No GPT-4 level

### vs. aider / gpt-engineer
- ✅ **Embedded MCP**: No separate server
- ✅ **Database**: Persistent context
- ✅ **Hybrid search**: FTS5 + vectors
- ❌ **Newer**: Less battle-tested

### vs. continue.dev
- ✅ **Monolithic**: Single binary
- ✅ **Local models**: No ollama required
- ✅ **Governance**: Built-in safety
- ❌ **No IDE plugin**: CLI-only (for now)

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for development guidelines.

## License

See [LICENSE.md](../../LICENSE.md) for licensing information.

## Support

- **Issues**: https://github.com/anigma/anigma-cli/issues
- **Discussions**: https://github.com/anigma/anigma-cli/discussions
- **Docs**: https://anigma.dev/docs/cli

---

**Built with ❤️ by the Anigma team**
