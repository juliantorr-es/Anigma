# Anigma MCP Extension - Quick Start

## Install (30 seconds)

1. **Download** `anigma-mcp.mcpb`
2. **Double-click** the file
3. **Restart Claude** (Cmd+Q, then relaunch)
4. **Done!** ✨

Look for "anigma" indicator in Claude Desktop bottom-right.

## Test It

Ask Claude:
```
"Show me the system health"
```

Claude will:
1. Call the `get_system_health` tool
2. Return real-time MCP metrics
3. Show load zone, uptime, module status

## Try These Prompts

1. **"What files have the most code?"**
   → Uses `context_search` to find complex files

2. **"Review my recent git changes"**
   → Uses `git_diff` + `context_search`

3. **"Why is the test failing?"**
   → Uses `swift_test` to analyze failures

4. **"Find all authentication code"**
   → Semantic search across codebase

5. **"Build the project and show results"**
   → Uses `swift_build` with 30s timeout

## Available Tools

### Instant (Sub-100ms)
- `read_file` - Read files with caching
- `list_artifacts` - Artifact repository
- `list_models` - ML models
- `get_system_health` - System metrics
- `list_active_alerts` - Current alerts

### Normal (100-500ms)
- `context_search` - Semantic search
- `database_query` - SQL queries
- `trace_query` - Execution history
- `git_diff` - Repository changes

### Slow (10-30s)
- `swift_build` - Compile project
- `swift_test` - Run tests
- `digest_codebase` - Index project

### Mutations (Need approval)
- `apply_patch` - Apply diffs
- `create_tool_contract` - Register tools
- `context_purge` - Clear cache
- `verify_evidence_chain` - Verify audit

## Configuration

Click the settings icon next to "anigma" in Claude Desktop to adjust:

- **Project Root**: Path to Anigma repo
- **Log Level**: debug, info, warn, error
- **Cache Size**: 1-500 MB
- **Max Concurrent Requests**: Per Claude instance
- **Rate Limit**: Requests per minute

## Troubleshooting

### Tools not appearing?
1. Quit Claude: Cmd+Q
2. Relaunch Claude
3. Ask: "list your tools"

### Getting "not initialized" error?
- Modules are still loading (first run takes ~5s)
- Wait a moment and retry

### Tools timing out?
1. Check: "What's the system health?"
2. If red/black zone, system is overloaded
3. Try again after a few seconds

### Binary not found?
1. Reinstall: Double-click anigma-mcp.mcpb again
2. Completely restart Claude (Cmd+Q)

## Performance

| Operation | Time | Cached Time |
|-----------|------|-------------|
| read_file | 50ms | 10ms |
| context_search | 200ms | 5ms |
| list_* | 50ms | instant |
| get_system_health | 100ms | instant |
| swift_build | 30s | — |

Cached operations are **10-40x faster**!

## Capabilities

Anigma provides:

✅ **16 powerful tools**
✅ **Adaptive scaling** (10+ concurrent Claude instances)
✅ **Multi-layer caching** (sub-100ms latency)
✅ **Real-time observability** (metrics, health checks)
✅ **Governance integration** (institutional safety)
✅ **Local-first** (nothing leaves your machine)

## Learn More

- **Extension Guide**: [CLAUDE_DESKTOP_EXTENSION_GUIDE.md](../Docs/CLAUDE_DESKTOP_EXTENSION_GUIDE.md)
- **Architecture**: [CLAUDE_INTEGRATION.md](../Docs/CLAUDE_INTEGRATION.md)
- **Setup Guide**: [CLAUDE_DESKTOP_SETUP.md](../Docs/CLAUDE_DESKTOP_SETUP.md)
- **Website**: https://anigma.dev

## Questions?

- Check logs: `~/Library/Logs/Claude/*.log`
- Review manifest: `~/Library/Application Support/Claude/anigma-mcp/manifest.json`
- Visit: https://github.com/anthropics/anigma/issues

---

**Version:** 1.0.0
**License:** MIT
**Ready for production use!**
