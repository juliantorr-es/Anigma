# Claude Integration: anigma-mcp Backend

This document outlines how Anigma integrates with Claude (both Claude Desktop and web) as an MCP (Model Context Protocol) backend.

## Overview

**anigma-mcp** bridges Claude with Anigma's full technology stack:

```
┌─────────────────────────────────────────────────────┐
│              Claude (Desktop/Web)                   │
│         (Conversational AI Interface)               │
└────────────────┬──────────────────────────────────┘
                 │ JSON-RPC (MCP)
                 │ 16 High-Level Tools
                 ▼
┌─────────────────────────────────────────────────────┐
│           anigma-mcp Server                         │
│     (Tier 2: Platform Runtime Integration)         │
│  - Request Queue & Adaptive Throttling              │
│  - Metrics & Observability                         │
│  - Module Initialization Barriers                  │
│  - Timeouts & Caching                              │
└────────────────┬──────────────────────────────────┘
                 │ Governed Execution
                 │ (Tier 1: Governance)
                 ▼
┌─────────────────────────────────────────────────────┐
│         Capability Modules (Tier 3)                 │
│  ┌────────────────────────────────────────────┐    │
│  │ HarmoniaModule      (AI coding assistant)  │    │
│  │ ContextumModule     (Search & indexing)    │    │
│  │ ArtifactStoreModule (Build artifacts)      │    │
│  │ ModelRegistryModule (ML models)            │    │
│  │ ObservatoriumModule (System health)        │    │
│  │ CathedralModule     (Evidence & audit)     │    │
│  └────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

## Installation & Setup

### Quick Start (Automated)

```bash
cd ~/Developer/GitHub/Anigma
bash Scripts/setup_claude_desktop.sh
```

This script:
1. ✅ Builds anigma-mcp in release mode
2. ✅ Installs to `/usr/local/bin/anigma-mcp`
3. ✅ Creates Claude Desktop MCP configuration
4. ✅ Validates installation

Then:
1. Quit Claude Desktop (`Cmd+Q`)
2. Relaunch Claude Desktop
3. Look for "anigma" indicator (bottom-right)

### Manual Setup

See [CLAUDE_DESKTOP_SETUP.md](./CLAUDE_DESKTOP_SETUP.md) for detailed instructions.

## How It Works

### Tool Execution Flow

```
Claude user prompt
    ↓
Claude determines relevant tools
    ↓
Claude calls MCP tool via JSON-RPC
    ↓
anigma-mcp receives request
    │
    ├→ Create MCPRequestContext (UUID, priority, deadline)
    ├→ Attempt to enqueue in MCPRequestQueue
    │  └→ Check client quotas (5 concurrent, 120/min)
    │  └→ Evaluate adaptive throttle (green/yellow/red/black zones)
    │  └→ Return 429 if overloaded, with retry hint
    ├→ Execute tool with timeout enforcement
    │  └→ Fast reads: 2s timeout (cached for <10ms)
    │  └→ Searches: 5s timeout (cached for <5ms)
    │  └→ Builds: 30s timeout (no cache)
    ├→ Record metrics (latency, errors, cache stats)
    ├→ Track in error log (for recent errors)
    ├→ Return result to Claude
    │
    └→ Claude processes result and continues conversation
```

### Adaptive Throttling

anigma-mcp implements 4-zone throttling to prevent overload:

```
Load < 70%     → GREEN (accept all, fast)
70% - 85%      → YELLOW (warn, add jitter)
85% - 95%      → RED (reject low-priority, accept critical)
Load > 95%     → BLACK (reject all except health checks)
```

Clients receive throttle hints (with retry-after) in error responses.

### Caching Strategy

Multi-layer caching for performance:

| Layer | TTL | Hit Rate | Purpose |
|-------|-----|----------|---------|
| **File Cache** | N/A (LRU, 10MB) | >80% | `read_file` performance |
| **Query Cache** | 5 minutes | >70% | `context_search`, `database_query` |
| **Metadata Cache** | 30 minutes | >90% | `list_artifacts`, `list_models` |

Cached operations typically complete in <10ms.

## Tool Categories

### Category 1: Fast Reads (High Priority)

Auto-approved, cached, <100ms typical latency:

- **`read_file`** - Read project files (cached LRU)
- **`list_artifacts`** - Query artifact repository
- **`list_models`** - Discover ML models
- **`get_system_health`** - System status and metrics
- **`list_active_alerts`** - Current system alerts

### Category 2: Search & Query (Normal Priority)

Require explicit approval for first use, cached:

- **`context_search`** - Semantic search across project
- **`database_query`** - Read-only SQL queries
- **`trace_query`** - Execution history
- **`git_diff`** - Repository changes

### Category 3: Heavy Compute (Low Priority)

Require approval, not cached, may take 10-30s:

- **`swift_build`** - Compile Swift package (30s timeout)
- **`swift_test`** - Run test suite (30s timeout)
- **`digest_codebase`** - Index entire project (async background)

### Category 4: Mutations (Low Priority)

Require approval, system-altering:

- **`apply_patch`** - Apply unified diff patches
- **`create_tool_contract`** - Register new tools
- **`context_purge`** - Clear search index
- **`verify_evidence_chain`** - Validate operation history

## API Reference

### Request Lifecycle

**MCPRequestContext** (internal):
```
{
  requestId: UUID,           // Unique request ID
  clientId: String,          // Client identifier
  toolName: String,          // "context_search", "read_file", etc
  priority: RequestPriority, // critical|high|normal|low
  createdAt: Date,
  deadline: Date,
  state: RequestState        // queued|executing|completed|failed
}
```

**RequestPriority** mapping:
- `critical` → health checks (get_system_health, list_active_alerts)
- `high` → fast reads (read_file, list_artifacts, list_models)
- `normal` → searches (context_search, database_query)
- `low` → heavy compute (swift_build, swift_test, mutations)

### Error Responses

**Too Many Requests (429)**:
```json
{
  "error": "Request rejected: Client quota exceeded Load: 72%; Retry after 5s",
  "throttleHint": {
    "loadZone": "yellow",
    "recommendedBackoffMs": 5000,
    "shouldRetry": true,
    "loadPercentage": 0.72
  }
}
```

**Module Not Initialized (503)**:
```json
{
  "error": "Contextum is not initialized yet."
}
```

**Tool Timeout (504)**:
```json
{
  "error": "Tool 'swift_build' timeout after 30.0s (limit: 30.0s)"
}
```

**Request ID for Debugging**:
All errors include `X-Request-ID` header (UUID) for correlation.

## Performance Characteristics

### Latency by Tool (Cold vs Cached)

| Tool | Cold | Cached | Timeout |
|------|------|--------|---------|
| read_file | 50ms | 10ms | 2s |
| context_search | 200ms | 5ms | 5s |
| list_artifacts | 50ms | - | 2s |
| list_models | 50ms | - | 2s |
| database_query | Variable | - | 5s |
| get_system_health | 100ms | - | 2s |
| swift_build | - | - | 30s |
| swift_test | - | - | 30s |
| digest_codebase | - | - | N/A |

### Throughput

- **Sustained**: 100 req/sec (10 concurrent clients × 10 req/sec)
- **Peak**: Up to 200 req/sec with adaptive throttling
- **Queue**: Max 50 pending requests (auto-rejects if exceeded)

### Memory Usage

- **Per-client session**: ~1KB
- **File cache**: 10MB (configurable, LRU eviction)
- **Query cache**: ~100KB per 100 queries
- **Total (10 clients)**: ~50-100MB

## Governance & Safety

All MCP operations respect Anigma's governance architecture:

### Tier 1: Governance Layer
- **KillSwitch**: Emergency halt for all writes (global governance)
- **WriteGate**: Pre-flight checks before mutations
- **ABAC**: Attribute-based access control
- **Lifecycle**: Data retention policies

### Tier 2: Platform Runtime (MCP Integration)
- **ExecutionAuthority**: Governs all tool execution
- **EvidenceAuthority**: Records all operations (tamper-evident)
- **DatabaseAuthority**: Governed database access
- **ArtifactAuthority**: Managed artifact storage

### Tier 3: Capability Modules
- **HarmoniaModule**: AI coding with safety kernel
- **ContextumModule**: Search with access control
- **CathedralModule**: Evidence verification

## Observability

### Health Check

Claude can request system health at any time:

```
"What's the current system status?"
```

Returns:
- MCP server uptime
- Load zone (green/yellow/red/black)
- Active requests count
- Queue depth
- Per-tool latency percentiles (p50/p95/p99)
- Cache hit rates
- Module initialization status
- Recent errors (last 10)

### Metrics Exposed

Via `get_system_health`:
```json
{
  "uptime": 3600.5,                    // seconds
  "loadZone": "green",                 // <70% capacity
  "activeRequests": 2,
  "queueDepth": 0,
  "toolMetrics": [
    {
      "toolName": "context_search",
      "callCount": 42,
      "errorCount": 0,
      "latencyP50": 45,               // milliseconds
      "latencyP95": 120,
      "latencyP99": 250,
      "cacheHitRate": 0.71            // 71%
    }
  ],
  "moduleStatus": {
    "runtime": "ready",
    "contextum": "ready",
    "artifactStore": "ready",
    "modelRegistry": "ready",
    "observatorium": "ready",
    "cathedral": "ready"
  },
  "recentErrors": []
}
```

## Example Workflows

### Workflow 1: Code Review with Context

```
User: "Review my recent changes for bugs and improvements"

Claude:
  1. Calls git_diff to see changes
  2. Calls context_search for related code patterns
  3. Calls read_file on suspicious areas
  4. Provides detailed review with citations
```

### Workflow 2: Debugging Test Failures

```
User: "Why are the integration tests failing?"

Claude:
  1. Calls swift_test --filter IntegrationTests
  2. Calls read_file on failing test code
  3. Calls git_diff to see recent changes
  4. Calls database_query to inspect test data
  5. Proposes root cause and fixes
```

### Workflow 3: System Health Monitoring

```
User: "Monitor the system for issues"

Claude (periodic):
  1. Calls get_system_health
  2. Evaluates load zone, error rates, module status
  3. Alerts if system is overloaded or degraded
  4. Recommends actions (scale back, restart services)
```

### Workflow 4: Semantic Search with Analysis

```
User: "Find all references to authentication in the codebase"

Claude:
  1. Calls context_search("authentication")
  2. Returns top 10 relevant context chunks
  3. Calls read_file on sources to verify
  4. Summarizes authentication patterns
  5. Suggests improvements
```

## Configuration Reference

### Claude Desktop Config

File: `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "anigma": {
      "command": "/usr/local/bin/anigma-mcp",
      "args": [],
      "disabled": false,
      "autoApprove": [
        "read_file",
        "list_artifacts",
        "list_models",
        "context_search",
        "get_system_health",
        "list_active_alerts",
        "database_query",
        "trace_query",
        "git_diff",
        "verify_evidence_chain"
      ],
      "env": {
        "ANIGMA_MCP_ENABLE": "true",
        "ANIGMA_LOG_LEVEL": "info"
      }
    }
  }
}
```

### Environment Variables

| Variable | Values | Default | Purpose |
|----------|--------|---------|---------|
| `ANIGMA_MCP_ENABLE` | true/false | true | Enable/disable MCP |
| `ANIGMA_LOG_LEVEL` | debug/info/warn/error | info | Logging verbosity |
| `ANIGMA_DISABLED_TOOLS` | CSV | (none) | Disable specific tools |
| `ANIGMA_CACHE_SIZE_MB` | Integer | 10 | File cache size |

## Troubleshooting

### Server Not Connecting

1. **Check binary exists**:
   ```bash
   which anigma-mcp
   # Should print: /usr/local/bin/anigma-mcp or path
   ```

2. **Check config syntax**:
   ```bash
   python3 -m json.tool \
     ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

3. **Check logs**:
   ```bash
   tail -100f ~/Library/Logs/Claude/*.log
   ```

### Tools Not Appearing

1. Verify server is active (look for "anigma" indicator in Claude)
2. Completely quit Claude Desktop (`Cmd+Q`)
3. Relaunch Claude Desktop
4. Ask Claude to "list your tools"

### Slow Performance

1. Check `get_system_health` for load zone
2. Look for high cache miss rates
3. Monitor queue depth
4. Check if modules are still initializing

### Tools Timing Out

1. Verify system load is not high
2. Check module status in health check
3. Retry (often first call triggers initialization)
4. Increase timeout in config if needed

## Security Considerations

### Read-Only Operations

All read tools (`read_file`, `context_search`, etc.) are:
- ✅ Non-destructive
- ✅ Cached automatically
- ✅ No governance checks required
- ✅ Safe to auto-approve

### Write Operations

All write tools (`apply_patch`, `swift_build`, etc.) are:
- ⚠️ Require explicit Claude user approval
- ⚠️ Recorded in tamper-evident evidence
- ⚠️ Subject to WriteGate checks
- ⚠️ Subject to KillSwitch

### Rate Limiting

Per-client quotas prevent abuse:
- 5 concurrent requests per client
- 120 requests per minute per client
- Adaptive throttling backs off overloaded clients

## Advanced Usage

### Custom Tool Registration

Claude can dynamically register new tools:

```
"Register a new tool called 'my-custom-tool' that takes a 'name' parameter and returns 'Hello {name}'"
```

Claude calls `create_tool_contract` to register it, then can use it immediately.

### Direct Binary Usage

For non-Claude use cases:

```bash
# Start anigma-mcp as a standalone MCP server
.build/release/anigma-mcp

# Communicate via stdin/stdout using MCP protocol (JSON-RPC)
```

### Integration with Other Tools

anigma-mcp follows MCP standard, so it can integrate with:
- Other AI systems (Cursor, etc.)
- Custom MCP clients
- Automation scripts

## Related Documentation

- [Architecture Overview](../ADR/0006-three-tier-runtime-architecture.md)
- [MCP Trust Model](../governance/adr/ADR-2025-12-30-anigma-cli-mcp-trust-model.md)
- [Anigma Developer Guide](./CLAUDE.md)

## Support & Issues

For bugs, feature requests, or questions:

1. **Check logs**: `~/Library/Logs/Claude/`
2. **Verify installation**: `which anigma-mcp && anigma-mcp --version`
3. **Report issue**: Include logs and configuration details

