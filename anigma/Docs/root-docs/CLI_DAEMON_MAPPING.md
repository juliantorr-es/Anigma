# CLI to Daemon API Mapping

## Overview
This document maps existing CLI commands to daemon HTTP API endpoints for the CLI refactor to work as a thin client.

## Current CLI Command Structure
From `Main.swift`, the CLI has 18 subcommands:
1. `init` - Initialize workspace
2. `chat` - Interactive chat mode (default)
3. `mcp-server` - MCP server management
4. `providers` - List discovered providers
5. `models` - Model management (with subcommands)
6. `plan` - Generate contract and route
7. `run` - Run task with governance
8. `tui` - Stream live progress/TUI
9. `index` - Index management
10. `index-codebase` - Index codebase
11. `search` - Search functionality
12. `worktree` - Worktree management
13. `runs` - Run history
14. `loop-breaker` - Loop breaking tools
15. `tools` - Tool management
16. `status` - Status display
17. `policy` - Policy management
18. `maturity` - Maturity assessment
19. `rag` - RAG operations
20. `models-ui` - Model UI

## Daemon API Endpoints (Based on Analysis)
From the daemon analysis, key endpoints include:

### Core Services
- `POST /api/v1/sessions` - Create session
- `GET /api/v1/sessions/{id}` - Get session status
- `DELETE /api/v1/sessions/{id}` - Close session
- `GET /api/v1/health` - Health check
- `GET /api/v1/status` - System status

### Job Management
- `POST /api/v1/jobs` - Submit job
- `GET /api/v1/jobs/{id}` - Get job status
- `GET /api/v1/jobs/{id}/output` - Get job output
- `POST /api/v1/jobs/{id}/cancel` - Cancel job
- `GET /api/v1/jobs` - List jobs

### Model Management
- `GET /api/v1/models` - List models
- `POST /api/v1/models` - Register model
- `GET /api/v1/models/{id}` - Get model details
- `DELETE /api/v1/models/{id}` - Delete model
- `POST /api/v1/models/{id}/verify` - Verify model
- `POST /api/v1/models/{id}/run` - Run model inference
- `POST /api/v1/models/{id}/embed` - Generate embeddings

### File/Vault Operations
- `POST /api/v1/vault/upload` - Upload file
- `GET /api/v1/vault/{id}` - Download file
- `DELETE /api/v1/vault/{id}` - Delete file
- `GET /api/v1/vault` - List files

### ML Services
- `POST /api/v1/ml/chat` - Chat completion
- `POST /api/v1/ml/embed` - Text embedding
- `POST /api/v1/ml/summarize` - Text summarization
- `POST /api/v1/ml/classify` - Text classification

### Tool/Agent Operations
- `POST /api/v1/tools/execute` - Execute tool
- `GET /api/v1/tools` - List available tools
- `POST /api/v1/agents/plan` - Create agent plan
- `POST /api/v1/agents/execute` - Execute agent plan

## Mapping Table

| CLI Command | Daemon Endpoint | HTTP Method | Notes |
|-------------|-----------------|-------------|-------|
| `anigma init` | `POST /api/v1/sessions` | POST | Create initial session with workspace config |
| `anigma chat` | `POST /api/v1/sessions/{id}/chat` | POST | Streaming chat endpoint |
| `anigma providers` | `GET /api/v1/providers` | GET | List available providers |
| `anigma models list` | `GET /api/v1/models` | GET | List registered models |
| `anigma models import` | `POST /api/v1/models` | POST | Register new model |
| `anigma models delete` | `DELETE /api/v1/models/{id}` | DELETE | Delete model |
| `anigma models verify` | `POST /api/v1/models/{id}/verify` | POST | Verify model integrity |
| `anigma models run` | `POST /api/v1/models/{id}/run` | POST | Run model inference |
| `anigma models embed` | `POST /api/v1/models/{id}/embed` | POST | Generate embeddings |
| `anigma plan` | `POST /api/v1/agents/plan` | POST | Create agent plan |
| `anigma run` | `POST /api/v1/agents/execute` | POST | Execute agent plan |
| `anigma tui` | WebSocket connection | WS | Real-time updates via WebSocket |
| `anigma index` | `GET /api/v1/index` | GET | Get index status |
| `anigma index-codebase` | `POST /api/v1/index` | POST | Create/update index |
| `anigma search` | `POST /api/v1/search` | POST | Search indexed content |
| `anigma worktree` | `GET /api/v1/worktrees` | GET | List worktrees |
| `anigma runs` | `GET /api/v1/jobs` | GET | List recent jobs/runs |
| `anigma loop-breaker` | `POST /api/v1/tools/execute` | POST | Execute loop-breaking tools |
| `anigma tools` | `GET /api/v1/tools` | GET | List available tools |
| `anigma status` | `GET /api/v1/status` | GET | System status |
| `anigma policy` | `GET /api/v1/policy` | GET | Policy configuration |
| `anigma maturity` | `GET /api/v1/maturity` | GET | Maturity assessment |
| `anigma rag` | `POST /api/v1/rag/query` | POST | RAG query |
| `anigma models-ui` | WebSocket + REST | Mixed | Interactive model UI |

## Session Management Design

### CLI Session Flow
1. **Start**: CLI checks if daemon is running (`GET /api/v1/health`)
2. **Create Session**: If daemon running, create session (`POST /api/v1/sessions`)
3. **Session Token**: Daemon returns session token for subsequent requests
4. **Command Execution**: CLI sends commands with session token
5. **Cleanup**: CLI closes session on exit (`DELETE /api/v1/sessions/{id}`)

### Session Configuration
```json
{
  "workspace_path": "/path/to/workspace",
  "capability_tokens": ["read", "write", "execute"],
  "output_format": "text|json",
  "interactive": true,
  "timeout": 3600
}
```

## File Handling Strategy

### Upload/Download Flow
1. **Local → Daemon**: CLI uploads files to daemon vault before processing
2. **Processing**: Daemon processes files in vault
3. **Results → CLI**: Daemon returns results or file references
4. **Download**: CLI downloads results from vault if needed

### Example: Code Analysis
```
CLI: anigma chat "analyze this code"
  → Upload file to /api/v1/vault/upload
  → POST /api/v1/sessions/{id}/chat with file reference
  ← Daemon processes, returns analysis
  ← CLI displays results
```

## Streaming/Interactive Support

### WebSocket Endpoints
- `ws://{socket}/api/v1/stream/chat` - Streaming chat responses
- `ws://{socket}/api/v1/stream/jobs/{id}` - Job progress updates
- `ws://{socket}/api/v1/stream/logs` - Real-time logs

### TUI Integration
- CLI establishes WebSocket connection for real-time updates
- TUI renders streaming responses
- User input sent via WebSocket messages

## Authentication & Security

### Capability Tokens
- CLI requests capability tokens during session creation
- Daemon validates tokens for each operation
- Tokens can be revoked or time-limited

### Local Socket Security
- Unix domain socket with file permissions
- Optional TLS for localhost HTTP
- Session-based authentication

## Implementation Phases

### Phase 1: Basic Thin Client
1. Create session management
2. Map simple commands (status, providers, models list)
3. Implement file upload/download
4. Basic error handling

### Phase 2: Interactive Commands
1. Streaming chat support
2. TUI integration with WebSocket
3. Job progress tracking
4. Real-time updates

### Phase 3: Advanced Features
1. Tool execution routing
2. Agent planning/execution
3. Complex file processing
4. Batch operations

### Phase 4: Optimization
1. Connection pooling
2. Caching strategies
3. Offline fallback
4. Performance tuning

## Migration Strategy

### Step 1: Dual Mode
- Keep existing CLI logic
- Add daemon client as alternative
- Feature flag to switch modes

### Step 2: Gradual Migration
- Migrate simple commands first
- Test with real workflows
- Gather feedback

### Step 3: Complete Migration
- Remove old business logic
- Optimize thin client
- Update documentation

## Testing Strategy

### Unit Tests
- HTTP client mocking
- Session management
- Error handling

### Integration Tests
- Full command execution
- File upload/download
- Streaming responses

### End-to-End Tests
- Complete workflows
- Performance benchmarks
- Compatibility testing

## Next Steps

1. **Create Daemon Client Library**: Swift package for daemon communication
2. **Implement Session Manager**: Handle session lifecycle
3. **Map First Command**: Start with `anigma status`
4. **Add File Support**: Implement upload/download
5. **Test Integration**: Verify end-to-end workflow
6. **Iterate**: Add more commands based on priority

## References

- Daemon Analysis: `DAEMON_IMPLEMENTATION_COMPLETE.md`
- CLI Source: `Packages/AnigmaCLI/Executable/`
- Daemon API: `Packages/AnigmaDaemonCore/Sources/HTTPServerManager.swift`
- Sidecar Bridge: `Packages/AnigmaDaemonCore/Sources/SidecarBridge.swift`
