# Codex CLI + anigma-mcp Integration

Codex CLI is **already configured** to use anigma-mcp. This guide explains how to verify and use it.

## Current Status

✅ **Active** - anigma-mcp is registered and enabled in Codex CLI

## Quick Verification

```bash
# Check MCP server registration
codex mcp list

# Expected output:
# Name    Command                    Status   Auth
# anigma  /usr/local/bin/anigma-mcp  enabled  Unsupported
```

If you see "enabled" status, you're good to go!

## Usage

### Start Interactive Session

```bash
codex
```

### Ask Codex to Use anigma Tools

```
> What tools do you have access to from anigma?
Codex: I have access to 17 tools including read_file, context_search, swift_build...

> Use anigma to read the CLAUDE.md file
Codex: Reading CLAUDE.md using anigma...
[File contents displayed]

> Search the codebase for 'governance' using anigma
Codex: Searching for 'governance'...
[Results shown]

> Build the Swift project using anigma
Codex: Building the project...
[Build output]
```

## Available Tools (17)

Codex can access all tools:

```
Read-only:
- read_file           - Read project files
- context_search      - Semantic search
- get_module_status   - Check MCP status
- list_artifacts      - Browse artifacts
- list_models         - List ML models
- database_query      - SQL queries
- get_system_health   - System metrics
- list_active_alerts  - Alerts
- git_diff            - Repository changes
- verify_evidence_chain - Audit trails
- digest_codebase     - Index project
- trace_query         - Performance traces

Write operations (governed):
- swift_build         - Build Swift packages
- swift_test          - Run tests
- apply_patch         - Apply diffs
- context_purge       - Clear cache
- create_tool_contract - Register tools
```

## Configuration

Codex configuration is in `~/.codex/config.toml`:

```toml
[mcp_servers.anigma]
command = "/usr/local/bin/anigma-mcp"

[mcp_servers.anigma.env]
ANIGMA_LOG_LEVEL = "info"
ANIGMA_MCP_ENABLE = "true"
```

All tools are auto-approved:
```toml
approval_policy = "never"
```

## Troubleshooting

### "anigma not found in tools list"

**Check registration:**
```bash
codex mcp list | grep anigma
```

If not found, check binary:
```bash
ls -lh /usr/local/bin/anigma-mcp
```

**Solution:** Copy binary to /usr/local/bin/
```bash
cp /Users/user/Developer/GitHub/Anigma/.build/release/anigma-mcp \
   /usr/local/bin/
chmod +x /usr/local/bin/anigma-mcp
```

### Tools return errors

**Check logs:**
```bash
tail -50 ~/.codex/logs/*
```

**Common issues:**
- Binary not executable: `chmod +x /usr/local/bin/anigma-mcp`
- Environment variables missing: Check `config.toml`
- Project files not readable: Check permissions

### Commands time out

Normal durations:
- Simple tools: <100ms
- Builds: 10-60s
- Full indexing: 30-60s

If timeouts occur, run directly without Codex.

## Workflow Examples

### Code Review Loop

```
> Use anigma context_search to find all database queries
> Read each file with anigma read_file
> Use anigma git_diff to show recent changes
> Apply suggested improvements with anigma apply_patch
```

### Build and Test

```
> Build the project with anigma swift_build
> Run tests with anigma swift_test
> If failures, use anigma git_diff to see what changed
> Use anigma read_file to examine failing tests
```

### Codebase Analysis

```
> Index the codebase with anigma digest_codebase
> Search for patterns with anigma context_search
> Get system metrics with anigma get_system_health
> Verify integrity with anigma verify_evidence_chain
```

## Performance Tips

### Use caching

Tools automatically cache results:
- File contents (LRU, 100 entries)
- Search indexes (auto-rebuild)
- Build artifacts (incremental)

Clear cache if stale:
```
> Use anigma context_purge to clear the search index
```

### Parallel requests

Codex can run multiple tool calls concurrently with anigma-mcp (up to 4-8 clients).

## Security

### Data stays local

✅ All processing on your machine
✅ No cloud APIs called
✅ No telemetry sent out
✅ Governed by Anigma's policies

### Tool safety

Auto-approved because:
- Read-only tools can't modify code
- Write operations protected by KillSwitch + WriteGate
- All operations logged with evidence

## Next Steps

1. ✅ Codex CLI - Already working (this page)
2. ✅ Claude Desktop - Already working
3. ✅ Zed Editor - [Configure it](./zed-editor.md)
4. 🔄 Gemini Bridge - Coming soon

Now you have 3 AI tools using the same local backend!

## More Information

- [Main Integration Guide](../AI_TOOLS_INTEGRATION.md)
- [Claude Desktop Setup](./claude-desktop.md)
- [Zed Editor Setup](./zed-editor.md)
- [Gemini Bridge Setup](./gemini-bridge.md)
