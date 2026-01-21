# Claude Desktop Integration: anigma-mcp

This guide explains how to set up Claude Desktop to use the locally-installed `anigma-mcp` binary as an MCP server.

## Overview

**anigma-mcp** exposes Anigma's entire capability stack (Harmonia, Contextum, ArtifactStore, ModelRegistry, Observatorium, Cathedral) via the Model Context Protocol, allowing Claude to:

- **Read project files** with `read_file` (cached for performance)
- **Perform semantic search** across documentation via `context_search`
- **List artifacts** from the provenance-backed repository
- **Discover ML models** registered in the system
- **Query the database** safely with read-only SQL
- **Inspect system health** and receive real-time metrics
- **Verify evidence chains** for governance compliance
- And 10 more high-level tools

## Prerequisites

1. **Anigma built and installed**:
   ```bash
   swift build -c release
   # anigma-mcp binary is at: .build/release/anigma-mcp
   ```

2. **Claude Desktop app** (version 0.5.0+)

## Installation

### Step 1: Build and Install anigma-mcp

```bash
cd ~/Developer/GitHub/Anigma

# Build release binaries
swift build -c release

# Optional: Install to system PATH for easy access
sudo cp .build/release/anigma-mcp /usr/local/bin/anigma-mcp
sudo chmod +x /usr/local/bin/anigma-mcp
```

### Step 2: Create Claude Desktop MCP Configuration

Create or edit: `~/Library/Application Support/Claude/claude_desktop_config.json`

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

**Configuration Options:**

| Option | Description |
|--------|-------------|
| `command` | Path to the anigma-mcp executable |
| `args` | Command-line arguments (none required) |
| `disabled` | Set to `true` to disable without removing |
| `autoApprove` | Tools that don't require confirmation from user |
| `env` | Environment variables passed to the server |

### Step 3: Restart Claude Desktop

1. Quit Claude Desktop completely (`Cmd+Q`)
2. Relaunch Claude Desktop
3. Look for "anigma" server indicator in the bottom-right corner

## Verification

Once configured, you should see the anigma server active in Claude Desktop. Test it by asking Claude:

```
List the health of the anigma system.
```

Claude should call the `get_system_health` tool and return:
- MCP server uptime
- Load zone (green/yellow/red/black)
- Queue depth and active requests
- Per-tool latency metrics
- Module initialization status

## Tool Reference

### High-Priority (Always Auto-Approve)

**`get_system_health`** - System status and metrics
```
Returns MCP server load, module status, recent errors
Latency: <100ms
```

**`list_active_alerts`** - Active system alerts
```
Returns alerts by severity (critical, warning, info)
Latency: <100ms
```

**`context_search`** - Semantic search across project
```
Input: Natural language query
Output: Top 10 relevant context chunks with source IDs
Cached: 5 minutes (repeated queries hit cache)
Latency: <200ms (cold), <5ms (cached)
```

**`read_file`** - Safely read project files
```
Input: Relative file path
Output: File contents
Cached: LRU cache (10MB default)
Latency: <50ms (cold), <10ms (cached)
```

**`list_artifacts`** - Query artifact repository
```
Optional: Filter by MIME type
Output: Artifact ID, media type, hash, committed timestamp
Latency: <50ms
```

**`list_models`** - Discover registered ML models
```
Optional: Filter by task (llmChat, embedding, transcription, classification)
Output: Model ID, task, backend, license status
Latency: <50ms
```

### Mutation Tools (Require Confirmation)

**`apply_patch`** - Apply unified diff patches
```
Input: Patch content, target files
Output: Success/failure message
Timeout: 10s
System-mutating: YES
```

**`swift_build`** - Trigger deterministic builds
```
Input: Optional package path
Output: Compilation results and diagnostics
Timeout: 30s
System-mutating: NO (read-only side effects)
```

**`swift_test`** - Execute test suite
```
Input: Optional test filter
Output: Pass/fail results
Timeout: 30s
System-mutating: NO
```

**`digest_codebase`** - Index entire project
```
Input: Optional root directory
Output: Indexing progress message (runs in background)
Timeout: N/A (async)
System-mutating: NO (builds search index)
```

**`database_query`** - Read-only SQL queries
```
Input: SQL query (SELECT only)
Output: Rows as formatted text
Timeout: 5s
Safety: Forbids INSERT, UPDATE, DELETE, CREATE, ALTER, DROP
```

**`trace_query`** - Query execution history
```
Input: Optional task ID
Output: Execution and migration history
Timeout: 5s
```

**`git_diff`** - Inspect repository changes
```
Input: Optional path filter
Output: Unified diff of uncommitted changes
Timeout: 2s
```

**`create_tool_contract`** - Register new tools dynamically
```
Input: Tool name, description, JSON schema, capabilities
Output: Confirmation message
Timeout: 10s
System-mutating: YES (adds to tool registry)
```

**`verify_evidence_chain`** - Verify operation history integrity
```
Input: Session ID
Output: Chain validation result, violations (if any)
Timeout: 10s
```

### Performance Expectations

| Tool | Cold Latency | Cached Latency | Timeout |
|------|--------------|---|---------|
| `read_file` | 50ms | 10ms | 2s |
| `context_search` | 200ms | 5ms | 5s |
| `list_artifacts` | 50ms | - | 2s |
| `list_models` | 50ms | - | 2s |
| `database_query` | Variable | - | 5s |
| `swift_build` | - | - | 30s |
| `swift_test` | - | - | 30s |
| `get_system_health` | 100ms | - | 2s |

## Troubleshooting

### Server Not Connecting

**Check if binary exists:**
```bash
which anigma-mcp
# Should print: /usr/local/bin/anigma-mcp
```

**Check logs:**
```bash
# Claude Desktop logs are at:
~/Library/Logs/Claude/
tail -f ~/Library/Logs/Claude/*.log
```

### Tools Not Appearing

1. Verify server is active (look for "anigma" indicator)
2. Restart Claude Desktop
3. Check `claude_desktop_config.json` syntax:
   ```bash
   python3 -m json.tool ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

### Tools Timing Out

- Check system load: `get_system_health`
- Verify Anigma modules are initialized (should show "ready" status)
- Increase timeout in Claude Desktop config if needed

### Slow Tool Performance

- First call to a tool will be slower (module initialization)
- Subsequent calls use caching:
  - File reads cached (LRU, 10MB)
  - Search results cached (5min TTL)
  - Query results cached (5min TTL)
- Monitor cache hit rate in `get_system_health` → Tool Metrics

## Advanced Configuration

### Custom Installation Path

If you install anigma-mcp to a custom location:

```json
{
  "mcpServers": {
    "anigma": {
      "command": "/path/to/custom/anigma-mcp",
      "args": []
    }
  }
}
```

### Disable Specific Tools

To hide a tool from Claude without uninstalling:

```json
{
  "mcpServers": {
    "anigma": {
      "command": "/usr/local/bin/anigma-mcp",
      "env": {
        "ANIGMA_DISABLED_TOOLS": "apply_patch,swift_build,swift_test"
      }
    }
  }
}
```

### Environment Variables

| Variable | Values | Default | Purpose |
|----------|--------|---------|---------|
| `ANIGMA_MCP_ENABLE` | true/false | true | Enable/disable MCP server |
| `ANIGMA_LOG_LEVEL` | debug/info/warn/error | info | Logging verbosity |
| `ANIGMA_DISABLED_TOOLS` | Comma-separated | (none) | Disable specific tools |
| `ANIGMA_CACHE_SIZE_MB` | Integer | 10 | File cache size in MB |

### Multiple Instances

You can run multiple anigma-mcp servers (e.g., for different projects):

```json
{
  "mcpServers": {
    "anigma-main": {
      "command": "/usr/local/bin/anigma-mcp",
      "env": {
        "ANIGMA_PROJECT": "main"
      }
    },
    "anigma-experimental": {
      "command": "/path/to/experimental/anigma-mcp",
      "env": {
        "ANIGMA_PROJECT": "experimental"
      }
    }
  }
}
```

## Example Conversations

### Example 1: Code Review with Context

**You:** "Review the MCP scaling implementation for performance issues."

**Claude:**
1. Calls `context_search` for "MCP scaling performance"
2. Calls `read_file` on relevant files
3. Calls `get_system_health` to check current load
4. Provides detailed review with context

### Example 2: Debugging Test Failures

**You:** "Why are the integration tests failing?"

**Claude:**
1. Calls `swift_test --filter IntegrationTests`
2. Calls `read_file` on failing test source
3. Calls `git_diff` to see recent changes
4. Proposes fixes based on context

### Example 3: System Health Check

**You:** "Is the system under load?"

**Claude:**
1. Calls `get_system_health`
2. Returns load zone, active requests, error rates
3. Suggests actions if needed (e.g., "reduce load", "restart services")

## Governance & Safety

All MCP tool calls are governed by Anigma's policy system:

- **Write operations** go through KillSwitch and WriteGate
- **All mutations** are recorded in tamper-evident evidence chains
- **Read-only operations** are optimized with caching
- **Access control** enforced via ABAC rules
- **Rate limiting** per-client with adaptive throttling

See [ADR-2025-12-30-anigma-cli-mcp-trust-model.md](../governance/adr/ADR-2025-12-30-anigma-cli-mcp-trust-model.md) for details.

## Support

For issues or questions:

1. Check logs: `~/Library/Logs/Claude/`
2. Test MCP directly: `swift build && .build/release/anigma-mcp` (should listen on stdin)
3. Report issues: https://github.com/anthropics/claude-code/issues

