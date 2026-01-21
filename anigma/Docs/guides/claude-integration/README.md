# Claude Desktop Integration

Complete guide for integrating Anigma with Claude Desktop via the **anigma-mcp** Model Context Protocol server.

---

## Quick Start

```bash
cd ~/Developer/GitHub/Anigma
bash Scripts/setup_claude_desktop.sh
```

Then:
1. Quit Claude Desktop (`Cmd+Q`)
2. Relaunch Claude Desktop
3. Ask Claude: **"Show me the system health"**

Done! ✅

---

## Overview

**anigma-mcp** bridges Claude with Anigma's full technology stack:

```
┌───────────────────────────────────────────────────┐
│            Claude (Desktop/Web)                   │
│         (Conversational AI Interface)             │
└─────────────────┬─────────────────────────────────┘
                  │ JSON-RPC (MCP)
                  │ 16 High-Level Tools
                  ▼
┌───────────────────────────────────────────────────┐
│           anigma-mcp Server                       │
│     (Tier 2: Platform Runtime Integration)        │
│  - Request Queue & Adaptive Throttling            │
│  - Metrics & Observability                        │
│  - Module Initialization Barriers                 │
│  - Timeouts & Caching                             │
└─────────────────┬─────────────────────────────────┘
                  │ Governed Execution
                  ▼
┌───────────────────────────────────────────────────┐
│         Capability Modules (Tier 3)               │
│  HarmoniaModule, ContextumModule, ArtifactStore   │
│  ModelRegistry, Observatorium, Cathedral          │
└───────────────────────────────────────────────────┘
```

---

## Installation

### Method 1: Automated Setup (Recommended)

```bash
cd ~/Developer/GitHub/Anigma
bash Scripts/setup_claude_desktop.sh
```

This script:
- ✅ Builds anigma-mcp in release mode
- ✅ Installs to `/usr/local/bin/anigma-mcp`
- ✅ Creates Claude Desktop MCP configuration
- ✅ Validates installation

### Method 2: Manual Setup

#### Step 1: Build and Install

```bash
cd ~/Developer/GitHub/Anigma
swift build -c release
sudo cp .build/release/anigma-mcp /usr/local/bin/anigma-mcp
sudo chmod +x /usr/local/bin/anigma-mcp
```

#### Step 2: Configure Claude Desktop

Create/edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

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

#### Step 3: Restart Claude Desktop

1. Quit completely (`Cmd+Q`)
2. Relaunch
3. Look for "anigma" indicator (bottom-right)

---

## Available Tools (16 Total)

### Read Operations (Auto-Approved)

| Tool | Purpose | Latency |
|------|---------|---------|
| `read_file` | Read project files | 10ms cached |
| `list_artifacts` | Query artifact repo | 50ms |
| `list_models` | Discover ML models | 50ms |
| `get_system_health` | System metrics | 100ms |
| `list_active_alerts` | Active alerts | 100ms |

### Search & Query

| Tool | Purpose | Latency |
|------|---------|---------|
| `context_search` | Semantic search | 5ms cached |
| `database_query` | Read-only SQL | 5s timeout |
| `trace_query` | Execution history | 5s timeout |
| `git_diff` | Repository changes | 2s timeout |

### Heavy Compute

| Tool | Purpose | Timeout |
|------|---------|---------|
| `swift_build` | Compile package | 30s |
| `swift_test` | Run tests | 30s |
| `digest_codebase` | Index project | async |

### Mutations (Require Approval)

| Tool | Purpose | Timeout |
|------|---------|---------|
| `apply_patch` | Apply diffs | 10s |
| `create_tool_contract` | Register tools | 10s |
| `context_purge` | Clear search index | 10s |
| `verify_evidence_chain` | Verify history | 10s |

---

## Example Prompts

```
"Show me the system health"
→ Real-time metrics, load zone, latency percentiles

"Find all references to 'authentication' in the codebase"
→ Semantic search across project

"What's my recent git changes?"
→ Diff of uncommitted changes

"Read the README file"
→ File is cached on second call

"Run the tests"
→ Execute test suite

"Review my code for bugs"
→ Combines read_file + context_search + analysis
```

---

## Performance

### Latency Expectations

| Tool | Cold | Cached | Timeout |
|------|------|--------|---------|
| read_file | 50ms | 10ms | 2s |
| context_search | 200ms | 5ms | 5s |
| list_artifacts | 50ms | - | 2s |
| get_system_health | 100ms | - | 2s |
| swift_build | - | - | 30s |

### Caching Strategy

| Cache Layer | TTL | Purpose |
|-------------|-----|---------|
| File Cache | LRU 10MB | read_file |
| Query Cache | 5 min | context_search, database_query |
| Metadata Cache | 30 min | list_artifacts, list_models |

### Adaptive Throttling

| Load Zone | Behavior |
|-----------|----------|
| 🟢 Green (<70%) | Accept all, fast |
| 🟡 Yellow (70-85%) | Warn + add jitter |
| 🔴 Red (85-95%) | Reject low-priority |
| ⚫ Black (>95%) | Health checks only |

---

## Configuration

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `ANIGMA_MCP_ENABLE` | true | Enable/disable MCP |
| `ANIGMA_LOG_LEVEL` | info | debug/info/warn/error |
| `ANIGMA_DISABLED_TOOLS` | (none) | Comma-separated tools to disable |
| `ANIGMA_CACHE_SIZE_MB` | 10 | File cache size |

### Multiple Instances

```json
{
  "mcpServers": {
    "anigma-main": {
      "command": "/usr/local/bin/anigma-mcp",
      "env": { "ANIGMA_PROJECT": "main" }
    },
    "anigma-experimental": {
      "command": "/path/to/experimental/anigma-mcp",
      "env": { "ANIGMA_PROJECT": "experimental" }
    }
  }
}
```

---

## Troubleshooting

### Server Not Connecting

1. **Verify binary exists:**
   ```bash
   which anigma-mcp
   # Should print: /usr/local/bin/anigma-mcp
   ```

2. **Check config syntax:**
   ```bash
   python3 -m json.tool ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

3. **Check Claude logs:**
   ```bash
   tail -100f ~/Library/Logs/Claude/*.log
   ```

4. **Complete restart:**
   ```bash
   killall Claude
   sleep 3
   rm -rf ~/Library/Application\ Support/Claude/Cache/*
   open -a Claude
   ```

### Tools Not Appearing

1. Look for "anigma" indicator in Claude Desktop
2. Completely quit Claude (`Cmd+Q`)
3. Relaunch and wait 10 seconds
4. Ask Claude: "What tools are available?"

### Tools Timing Out

1. Check `get_system_health` for load zone
2. First call is slower (modules initializing)
3. Verify modules are ready in health check
4. Retry the operation

### Slow Performance

1. Check cache hit rates in `get_system_health`
2. Monitor queue depth
3. Check for high error rates
4. Verify modules are initialized

---

## Extension Packaging (.mcpb)

For distributing anigma-mcp as a one-click installable extension:

### Build .mcpb Bundle

```bash
bash Scripts/package_extension.sh
# Output: anigma-mcp.mcpb
```

### Bundle Structure

```
anigma-mcp.mcpb (zip archive)
├── anigma-mcp/
│   ├── manifest.json
│   ├── anigma-mcp (binary)
│   ├── README.md
│   └── assets/
│       └── icon-*.png
```

### Installation via .mcpb

**Double-click method:**
1. Download `anigma-mcp.mcpb`
2. Double-click to install
3. Restart Claude Desktop

**Manual method:**
```bash
unzip anigma-mcp.mcpb -d ~/Library/Application\ Support/Claude/
```

---

## Governance & Safety

All MCP operations respect Anigma's governance architecture:

- **KillSwitch**: Emergency halt for all writes
- **WriteGate**: Pre-flight checks before mutations
- **ABAC**: Attribute-based access control
- **Evidence**: All operations recorded in tamper-evident chains
- **Rate Limiting**: Per-client quotas (5 concurrent, 120/min)

---

## Related Documentation

- [Three-Tier Architecture](../ADR/0006-three-tier-runtime-architecture.md)
- [MCP Trust Model](../governance/adr/ADR-2025-12-30-anigma-cli-mcp-trust-model.md)
- [MCP Sprint](../sprints/2026-01-MCP-Extension/)

---

*Consolidated from: CLAUDE_DESKTOP_SETUP.md, CLAUDE_DESKTOP_EXTENSION_GUIDE.md, CLAUDE_INTEGRATION.md, QUICK_START_CLAUDE_DESKTOP.md, FIX_EXTENSION_CONNECTION.md*

*Last Updated: January 10, 2026*
