# Quick Start: Claude Desktop + anigma-mcp

## 30-Second Setup

```bash
cd ~/Developer/GitHub/Anigma
bash Scripts/setup_claude_desktop.sh
```

Then:
1. Quit Claude Desktop (`Cmd+Q`)
2. Relaunch Claude Desktop
3. Ask Claude: "Show me the system health"

Done! ✅

---

## What You Just Installed

**anigma-mcp** - A Model Context Protocol server that gives Claude access to Anigma's full stack:

```
Claude ↔ anigma-mcp ↔ Harmonia, Contextum, ArtifactStore, ModelRegistry, Observatorium, Cathedral
```

---

## 16 Tools Now Available to Claude

### Read Operations (Auto-Approve)
- `read_file` - Read project files (cached)
- `list_artifacts` - Query artifact repo
- `list_models` - Discover ML models
- `get_system_health` - System metrics
- `list_active_alerts` - Active alerts

### Search & Query
- `context_search` - Semantic search
- `database_query` - Read-only SQL
- `trace_query` - Execution history
- `git_diff` - Repository changes

### Heavy Compute
- `swift_build` - Compile package
- `swift_test` - Run tests
- `digest_codebase` - Index project

### Mutations (Require Approval)
- `apply_patch` - Apply diffs
- `create_tool_contract` - Register tools
- `context_purge` - Clear search index
- `verify_evidence_chain` - Verify history

---

## Try These Prompts

```
"Show me the system health"
→ Get real-time metrics, load zone, latency percentiles

"Find all references to 'authentication' in the codebase"
→ Semantic search across project

"What's my recent git changes?"
→ Show diff of uncommitted changes

"Read the README file"
→ File is cached on second call

"Run the tests"
→ Execute test suite

"Review my code for bugs"
→ Combines read_file + context_search + analysis
```

---

## Performance Expectations

| Operation | Cold | Cached |
|-----------|------|--------|
| read_file | 50ms | 10ms |
| context_search | 200ms | 5ms |
| list_artifacts | 50ms | - |
| get_system_health | 100ms | - |

**First call**: Slightly slower (modules may still be initializing)
**Subsequent calls**: Much faster (caching kicks in)

---

## Status Check

Verify installation:

```bash
# Should print: /usr/local/bin/anigma-mcp
which anigma-mcp

# Should show Claude config with "anigma" server
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

Look for "anigma" indicator in Claude Desktop (bottom-right corner).

---

## Troubleshooting

**Server not connecting?**
- Quit Claude completely (`Cmd+Q`)
- Restart Claude Desktop
- Check config: `python3 -m json.tool ~/Library/Application\ Support/Claude/claude_desktop_config.json`

**Tools timing out?**
- Check system load: Ask Claude "Show me the system health"
- First call is slower (modules initializing)
- Try again

**Need help?**
- Full docs: `Docs/CLAUDE_DESKTOP_SETUP.md`
- Integration guide: `Docs/CLAUDE_INTEGRATION.md`

---

## Key Features

✅ **10 Concurrent Clients** - Handles multiple Claude instances
✅ **Adaptive Throttling** - Gracefully degrades under load
✅ **Multi-Layer Caching** - <10ms for cached operations
✅ **Observable Health** - Real-time metrics & load zones
✅ **Governance Enforced** - All operations auditable

---

## Next Steps

1. ✅ Run setup script
2. ✅ Restart Claude Desktop
3. ✅ Test with system health query
4. 📖 Read full docs for advanced usage

**Questions?** See `Docs/CLAUDE_INTEGRATION.md` for comprehensive guide.

