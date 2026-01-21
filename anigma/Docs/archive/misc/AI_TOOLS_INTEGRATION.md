# AI Tools Integration with anigma-mcp

This guide explains how to use Anigma's local MCP server (`anigma-mcp`) with multiple AI coding assistants, enabling governed, local-first AI operations across your entire toolchain.

## Overview

**anigma-mcp** is a Model Context Protocol (MCP) server that exposes 17 powerful tools for code analysis, building, testing, and codebase management. Instead of using cloud-based AI services, you can integrate anigma-mcp with any AI tool that supports MCP, keeping your data local and respecting your governance policies.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Your AI Workflow                          │
│  Claude Desktop  │  Codex CLI  │  Zed Editor  │  Gemini (HTTP) │
└────────┬──────────────┬──────────────┬──────────────┬───────────┘
         │ MCP (stdio)  │ MCP (stdio)  │ MCP (stdio) │ HTTP
         └──────────────┴──────────────┴─────────────┘
                              │
                  ┌───────────▼──────────┐
                  │   anigma-mcp server  │
                  │    (17 tools)        │
                  └───────────┬──────────┘
                              │
                  ┌───────────▼──────────┐
                  │  PlatformRuntime     │
                  │  + Governance        │
                  │  + Evidence Trails   │
                  │  + Caching           │
                  └──────────────────────┘
```

## Tool Capability Matrix

| Tool | MCP Support | Status | Tools Available | Setup Time |
|------|-------------|--------|-----------------|-----------|
| **Claude Desktop** | Native | ✅ Active | All 17 (16 auto-approved) | Already configured |
| **Codex CLI** | Native | ✅ Active | All 17 (auto-approved) | Verified working |
| **Zed Editor** | Native | ✅ To Configure | All 17 | 5-10 minutes |
| **Gemini** | Bridge | 🔄 In Progress | All 17 (via HTTP) | Coming soon |

## Available Tools (17 Total)

### Read-Only Tools (Safe for Auto-Approval)
- **read_file** - Securely read project files with caching
- **context_search** - Semantic and full-text search across codebase
- **get_module_status** - Check MCP module initialization status
- **list_artifacts** - Browse project build artifacts
- **list_models** - List registered ML models
- **database_query** - Execute read-only SQL queries
- **get_system_health** - Get system health metrics and status
- **list_active_alerts** - View active system alerts
- **git_diff** - Inspect repository changes with risk analysis
- **verify_evidence_chain** - Verify governance evidence integrity
- **digest_codebase** - Index entire project for semantic search
- **trace_query** - Query execution history and performance

### Write Operations (Auto-Approved, Governed)
- **swift_build** - Deterministic Swift package builds with caching
- **swift_test** - Execute test suite with flakiness detection
- **apply_patch** - Apply unified diffs with rollback support
- **context_purge** - Clear search index cache
- **create_tool_contract** - Register new tools dynamically

## Quick Start by Tool

### Claude Desktop (Already Configured ✅)

Your Claude Desktop is already configured to use anigma-mcp with 16 auto-approved tools.

**To verify it's working:**
```bash
# Open Claude Desktop
# Ask Claude: "Can you read the CLAUDE.md file using the anigma tools?"
# Expected: Claude reads and displays the file
```

**To use build/test tools:**
```
Ask Claude: "Use anigma to build the Swift project and show me the results"
```

### Codex CLI (Already Configured ✅)

Codex CLI has anigma-mcp registered and fully enabled.

**To verify:**
```bash
codex mcp list
# Expected output:
# Name    Command                    Status   Auth
# anigma  /usr/local/bin/anigma-mcp  enabled  Unsupported
```

**To use in a session:**
```bash
codex
# In Codex: "What tools do you have access to from anigma?"
# In Codex: "Use anigma to search for 'governance' patterns in the codebase"
```

### Zed Editor (Easy 15-min Setup)

Zed has native MCP support via `context_servers`. Configuration is minimal.

**Setup:**

1. **Backup your current Zed settings:**
   ```bash
   cp ~/.config/zed/settings.json ~/.config/zed/settings.json.backup
   ```

2. **Add MCP server configuration** to `~/.config/zed/settings.json`:
   ```json
   {
     "context_servers": {
       "anigma": {
         "source": "custom",
         "command": "/usr/local/bin/anigma-mcp",
         "args": [],
         "env": {
           "ANIGMA_MCP_ENABLE": "true",
           "ANIGMA_LOG_LEVEL": "info"
         }
       }
     }
   }
   ```

3. **Restart Zed Editor**

4. **Verify in Agent Panel:**
   - Open Agent Panel (Cmd+Shift+P → "Toggle Agent Panel")
   - Look for green dot next to "anigma"
   - Tools appear as slash commands: `/read_file`, `/context_search`, `/swift_build`, etc.

**Usage Examples:**
```
In Zed Agent Panel:
/get_module_status
/read_file CLAUDE.md
/context_search governance
/swift_build
/swift_test
```

### Gemini (HTTP Bridge - In Progress)

Gemini support requires an HTTP bridge server (currently being developed).

**Current Status:** Bridge server skeleton in `/Packages/AnigmaGeminiBridge/`

**When available:**
```python
import requests

BRIDGE_URL = "http://localhost:8080"

# List tools
tools = requests.get(f"{BRIDGE_URL}/v1/tools").json()

# Call a tool
response = requests.post(
    f"{BRIDGE_URL}/v1/tools/call",
    json={
        "name": "read_file",
        "arguments": {"file_path": "CLAUDE.md"}
    }
).json()

print(response["response"]["content"])
```

## Troubleshooting

### "anigma-mcp: command not found"
**Cause:** Binary not in PATH
**Solution:**
```bash
# Check if binary exists
ls -lh /usr/local/bin/anigma-mcp

# If missing, copy from build directory
cp /Users/user/Developer/GitHub/Anigma/.build/arm64-apple-macosx/release/anigma-mcp \
   /usr/local/bin/
chmod +x /usr/local/bin/anigma-mcp
```

### Tools not appearing in Zed
**Cause:** MCP server not starting
**Solution:**
1. Check Zed settings.json syntax: `jq . ~/.config/zed/settings.json`
2. Verify binary is executable: `ls -lh /usr/local/bin/anigma-mcp`
3. Test binary directly: `/usr/local/bin/anigma-mcp` (should output JSON-RPC init message)
4. Restart Zed
5. Check Zed logs: `cat ~/Library/Logs/Zed/Zed.log | tail -20`

### Tool execution times out
**Cause:** Long-running operations (build, test)
**Solution:**
- Builds can take 30-60 seconds depending on project size
- Tests depend on suite size
- For large projects, consider running these operations directly

### Tools return empty results
**Cause:** Search index not built or permissions issue
**Solution:**
```bash
# Rebuild semantic search index
# In Claude/Codex/Zed: Ask to "use anigma digest_codebase to index the project"

# Check file permissions
ls -la /Users/user/Developer/GitHub/Anigma/ | head -20
```

## Security Considerations

### Auto-Approval Safety

All configured tools are **auto-approved** because:

1. **Read-only tools** (read_file, context_search) can't modify your code
2. **Governed operations** (swift_build, apply_patch) are protected by:
   - **KillSwitch** - Emergency halt for all writes
   - **WriteGate** - Quality checks before mutations
   - **ABAC** - Attribute-based access control
3. **Evidence trails** - All operations logged with cryptographic signatures
4. **Compliance-ready** - Audit logs available for institutional requirements

### Governance Integration

Every tool call is automatically:
- ✅ Evaluated against governance policies
- ✅ Logged to CathedralModule (evidence storage)
- ✅ Signed with BLAKE3 cryptographic hash
- ✅ Recorded with principal, timestamp, and result

### Local-First Privacy

- No cloud API calls (except for Gemini bridge, which still runs locally)
- All data stays on your machine
- No account required
- No telemetry sent outside your network

## Performance Tips

### Caching and Speed

Tools use multiple caching strategies:

```
read_file           → File content cache (LRU, 100 entries)
context_search      → Search index cache (rebuilt on codebase changes)
swift_build         → File-level build cache (incremental builds)
git_diff            → Diff cache (30 minute TTL)
```

**To clear caches:**
```
In Claude/Codex/Zed:
"Use anigma context_purge to clear the search index"
```

### Latency Targets

- Simple tools (get_module_status, list_models): <100ms
- File operations (read_file): <200ms
- Search (context_search): <500ms (with cache)
- Build (swift_build): <30s (incremental)
- Full indexing (digest_codebase): <60s (one-time)

### Concurrent Access

anigma-mcp safely handles 4-8 concurrent clients:
```
Claude Desktop + Codex CLI + Zed Editor = 3 concurrent clients ✅
Claude + Codex + Zed + Gemini Bridge = 4 concurrent clients ✅
```

Concurrent requests are serialized with timeouts to prevent hangs.

## Advanced Usage

### Tool Composition

Ask Claude/Codex/Zed to chain tools together:

```
"Use anigma to:
1. Search the codebase for 'TODO' comments
2. For each match, read the file and show context
3. Create a summary of all TODOs in markdown format"
```

### Performance Analysis

Get detailed metrics:
```bash
# In Codex/Claude/Zed:
"Use anigma get_system_health to show detailed metrics"
```

### Governance Monitoring

Verify audit trails:
```bash
# In Codex/Claude/Zed:
"Use anigma verify_evidence_chain to check operation integrity"
```

### Dynamic Tool Registration

Register custom tools at runtime:
```bash
# In Codex/Claude/Zed:
"Use anigma create_tool_contract to register a new custom tool
that [description of what your tool does]"
```

## Configuration Files

### Claude Desktop
- **Location:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Key:** `mcpServers.anigma`
- **Mode:** 16 tools auto-approved (read+write operations)

### Codex CLI
- **Location:** `~/.codex/config.toml`
- **Key:** `mcp_servers.anigma`
- **Mode:** All 17 tools, auto-approved

### Zed Editor
- **Location:** `~/.config/zed/settings.json`
- **Key:** `context_servers.anigma`
- **Mode:** All 17 tools, requires per-tool approval or auto-approved (configurable)

## Environment Variables

The anigma-mcp server reads these variables:

```bash
ANIGMA_MCP_ENABLE=true         # Enable MCP mode
ANIGMA_LOG_LEVEL=info          # Logging level (debug, info, warn, error)
ANIGMA_CACHE_SIZE=1000         # Max cache entries
ANIGMA_TIMEOUT=30              # Request timeout in seconds
```

## FAQ

**Q: Is it safe to auto-approve write operations?**
A: Yes. The governance system provides three layers of protection (KillSwitch, WriteGate, ABAC), and all operations are logged with cryptographic evidence.

**Q: Can I use anigma-mcp with multiple tools simultaneously?**
A: Yes, up to 4-8 concurrent clients. Each gets an isolated session and calls are serialized.

**Q: Does anigma-mcp send data to the cloud?**
A: No. All processing is local except for Gemini bridge, which translates HTTP requests locally.

**Q: How often should I rebuild the search index?**
A: Automatically on file changes. Manually rebuild with `context_purge` if stale.

**Q: Can I use anigma-mcp without MCP support?**
A: The binary itself runs standalone with JSON-RPC protocol. Tools can be called directly via subprocess pipes.

## Next Steps

1. ✅ Claude Desktop - Already working
2. ✅ Codex CLI - Already working
3. ✅ Zed Editor - Configure now (15 min)
4. 🔄 Gemini Bridge - Coming soon

Once Zed is configured, you'll have 3 AI tools using the same local, governed backend. All operations are audited, cached, and compliant with your institutional requirements.

## Support

For issues or questions:
- Check the troubleshooting section above
- Review logs: `/Users/user/.local/share/anigma-mcp/logs/`
- See tool documentation: `swift build --product anigma-mcp && .build/release/anigma-mcp --help`
