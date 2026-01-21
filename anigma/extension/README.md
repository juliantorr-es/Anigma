# Anigma MCP Extension for Claude Desktop

**Local-first Swift stack for institutional AI governance and agentic workflows**

This extension brings Anigma's complete AI platform to Claude Desktop as a Model Context Protocol (MCP) server.

## What is Anigma MCP?

Anigma MCP connects Claude to a comprehensive, locally-running AI infrastructure system built on Swift. It provides:

- **16 powerful tools** for code analysis, semantic search, builds, and system monitoring
- **Adaptive scaling** for 10+ concurrent Claude instances
- **Multi-layer caching** for sub-100ms operation latency
- **Complete observability** with real-time metrics and health monitoring
- **Governance integration** with institutional safety guarantees
- **Local-first execution** - nothing leaves your machine

## Quick Start

### Installation

1. **Download the extension**
   - Download `anigma-mcp.mcpb` from the releases page

2. **Install into Claude Desktop**
   - Double-click `anigma-mcp.mcpb`
   - Claude Desktop will automatically extract and configure it
   - Restart Claude Desktop (`Cmd+Q`, then relaunch)

3. **Verify installation**
   - Look for "anigma" indicator in Claude Desktop bottom-right
   - Ask Claude: **"What's the system health?"**
   - Claude should return MCP metrics

### Configuration

The extension provides 5 user-configurable settings:

| Setting | Default | Purpose |
|---------|---------|---------|
| `anigma_project_root` | `~/Developer/GitHub/Anigma` | Path to Anigma repository |
| `log_level` | `info` | Logging verbosity (debug/info/warn/error) |
| `cache_size_mb` | `10` | File cache size in MB (1-500) |
| `max_concurrent_requests` | `5` | Max concurrent requests per Claude instance |
| `max_requests_per_minute` | `120` | Rate limit per Claude instance |

To modify settings:
1. In Claude Desktop, click the gear icon next to "anigma"
2. Adjust settings as needed
3. Settings take effect immediately

## Available Tools

### Fast Reads (Instant)
- `read_file` - Read project files with LRU caching (<10ms cached)
- `list_artifacts` - Query artifact repository
- `list_models` - Discover ML models
- `get_system_health` - Real-time system metrics
- `list_active_alerts` - Current system alerts

### Search & Query (Normal Priority)
- `context_search` - Semantic search across project
- `database_query` - Read-only SQL queries
- `trace_query` - Execution history
- `git_diff` - Repository changes

### Heavy Compute (May Take Time)
- `swift_build` - Compile Swift package (30s timeout)
- `swift_test` - Run test suite (30s timeout)
- `digest_codebase` - Index entire project (async background)

### Mutations (Requires Approval)
- `apply_patch` - Apply unified diff patches
- `create_tool_contract` - Register new tools
- `context_purge` - Clear search index
- `verify_evidence_chain` - Validate operation history

## Example Prompts

Try these in Claude to get started:

1. **"Show me the system health"**
   - Returns real-time MCP metrics, load zone, and module status

2. **"Review my recent git changes for bugs"**
   - Uses git_diff + context_search to analyze recent changes

3. **"Why is the test suite failing?"**
   - Runs swift_test and analyzes failures

4. **"Find all authentication code in the project"**
   - Semantic search for authentication patterns

5. **"What Swift files have the most complexity?"**
   - Searches for complexity metrics and suggests refactoring

## Architecture

```
Claude Desktop
    ↓ (JSON-RPC)
anigma-mcp Server
    ├── Request Queue (priority + per-client quotas)
    ├── Adaptive Throttling (4-zone load management)
    ├── Multi-Layer Caching (file/query/metadata)
    ├── Metrics & Health (observability)
    └── Timeout Enforcement (2-30s per category)
    ↓
Tier 2: Platform Runtime
    ├── ExecutionAuthority (governed execution)
    ├── EvidenceAuthority (tamper-proof audit)
    ├── DatabaseAuthority (governed queries)
    └── ArtifactAuthority (managed storage)
    ↓
Tier 3: Capability Modules
    ├── HarmoniaModule (AI coding)
    ├── ContextumModule (search)
    ├── ArtifactStoreModule (storage)
    ├── ModelRegistryModule (ML)
    ├── ObservatoriumModule (health)
    └── CathedralModule (evidence)
```

## Performance

| Operation | Cold | Cached | Timeout |
|-----------|------|--------|---------|
| read_file | 50ms | 10ms | 2s |
| context_search | 200ms | 5ms | 5s |
| list_artifacts | 50ms | — | 2s |
| get_system_health | 100ms | — | 2s |
| swift_build | — | — | 30s |

**Throughput:** 100 requests/sec sustained with adaptive throttling

**Memory:** ~50-100MB for 10 concurrent clients

## Governance & Safety

All operations respect Anigma's 3-tier governance:

### Tier 1: Governance Policies
- KillSwitch for emergency halt
- WriteGate for quality checks
- ABAC for access control
- Lifecycle policies for data retention

### Tier 2: Platform Runtime
- ExecutionAuthority governs all execution
- Evidence recorded for all mutations
- Database access governed
- Artifact storage managed

### Tier 3: Capability Modules
- AI coding with safety kernel
- Search with access control
- Evidence verification
- Model lifecycle management

## Troubleshooting

### Extension Not Appearing

1. Verify it's installed: `ls ~/Library/Application\ Support/Claude/`
2. Completely quit Claude Desktop: `Cmd+Q`
3. Relaunch Claude Desktop
4. Ask Claude to "list your tools"

### Tools Timing Out

1. Check system health: Ask Claude "What's the system health?"
2. Look for high load (red or black zone)
3. Check if modules are still initializing
4. Retry after a few seconds

### Slow Performance

1. Ask Claude: "Show me the system health"
2. Check cache hit rates (should be >70%)
3. Look at queue depth (should be <5)
4. Check module status (should be "ready")

### Binary Not Found

1. Verify binary exists: `which anigma-mcp`
2. Check permissions: `ls -la /usr/local/bin/anigma-mcp`
3. Reinstall: `bash Scripts/setup_claude_desktop.sh`

## Advanced Usage

### Environment Variables

Set these before launching Claude Desktop:

```bash
export ANIGMA_MCP_ENABLE=true           # Enable/disable MCP (default: true)
export ANIGMA_LOG_LEVEL=debug           # Logging level (default: info)
export ANIGMA_DISABLED_TOOLS="tool1,tool2"  # Disable specific tools
export ANIGMA_CACHE_SIZE_MB=50          # File cache size (default: 10)
```

### Custom Tool Registration

Ask Claude:
```
"Register a new tool called 'my-tool' that takes a 'name' parameter
and returns 'Hello {name}'"
```

Claude will call `create_tool_contract` to register it dynamically.

### Direct Binary Usage

For non-Claude use cases, run as standalone MCP server:

```bash
/usr/local/bin/anigma-mcp

# Then communicate via stdin/stdout using JSON-RPC 2.0
```

## Security & Privacy

- ✅ **Local-only execution** - No data sent to cloud
- ✅ **Auditable** - All operations logged in tamper-proof evidence
- ✅ **Governed** - Respects institutional policies
- ✅ **Non-destructive reads** - Read tools are completely safe
- ⚠️ **Write tools need approval** - Claude asks before mutations

## Getting Help

- **Documentation**: See `Docs/CLAUDE_INTEGRATION.md` in the Anigma repository
- **Issues**: Report bugs at https://github.com/anthropics/anigma/issues
- **Discussion**: Join the Anigma community at https://anigma.dev

## About Anigma

Anigma is a **local-first, governed AI stack** designed for institutional environments where:

- Radical transparency is non-negotiable
- AI operations require explicit governance
- Data privacy is paramount
- Audit trails are essential
- Safety guarantees are mandatory

Learn more at https://anigma.dev

---

**Version:** 1.0.0
**License:** MIT
**Author:** Anigma Contributors
