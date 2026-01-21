# Zed Editor + anigma-mcp Integration

Configure Zed Editor to use anigma-mcp for governed, local AI coding assistance with access to 17 specialized tools.

## What You Get

- ✅ All 17 anigma-mcp tools available as slash commands
- ✅ Semantic codebase search
- ✅ Local Swift builds and tests
- ✅ File reading with caching
- ✅ Evidence-based operation trails
- ✅ Zero cloud dependencies

## Prerequisites

- Zed Editor installed (latest version)
- anigma-mcp binary at `/usr/local/bin/anigma-mcp`
- ~/.config/zed/settings.json exists

## Installation (5 minutes)

### Step 1: Backup Current Settings

```bash
cp ~/.config/zed/settings.json ~/.config/zed/settings.json.backup
```

### Step 2: Add MCP Server Configuration

Edit `~/.config/zed/settings.json` and add this section after `"edit_predictions"`:

```json
{
  // ... existing settings ...
  "edit_predictions": {
    "mode": "subtle"
  },
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
  },
  // ... rest of settings ...
}
```

### Step 3: Verify Configuration

Check JSON syntax:
```bash
jq . ~/.config/zed/settings.json > /dev/null && echo "✅ Valid JSON"
```

### Step 4: Restart Zed

Quit and reopen Zed Editor completely.

### Step 5: Verify Integration

1. Open **Agent Panel** (Cmd+Shift+P → search "Agent Panel")
2. Look for the "anigma" entry in context servers
3. You should see a **green dot** indicator (connected)
4. Type "/" in the assistant and see anigma tools autocomplete

## Usage

### In Zed's Agent Panel

Slash commands trigger anigma-mcp tools:

```
/get_module_status          # Check MCP status
/read_file <path>          # Read a file
/context_search <query>    # Search codebase
/swift_build               # Build the project
/swift_test                # Run tests
/git_diff                  # Show changes
/digest_codebase           # Index project
```

### Example Workflows

**Search for patterns:**
```
User: Use /context_search to find all "TODO" comments
Zed Agent: Executing context_search with query 'TODO'...
[Results shown in chat]
```

**Build and test:**
```
User: Run /swift_build to compile the project
Zed Agent: Building project...
[Build output and results]
```

**Read configuration:**
```
User: Use /read_file to show me CLAUDE.md
Zed Agent: Reading CLAUDE.md...
[File contents displayed]
```

## Troubleshooting

### Green indicator doesn't show

**Problem:** MCP server not connecting

**Check:**
```bash
# 1. Verify JSON syntax
jq . ~/.config/zed/settings.json

# 2. Check binary exists and is executable
ls -lh /usr/local/bin/anigma-mcp
chmod +x /usr/local/bin/anigma-mcp

# 3. Test binary directly
/usr/local/bin/anigma-mcp
# Should output JSON-RPC initialization message

# 4. Check Zed logs
tail -20 ~/Library/Logs/Zed/Zed.log
```

**Solution:** Restart Zed after fixing issues.

### Tools don't appear in autocomplete

**Problem:** Slash commands not showing

**Check:**
1. Restart Zed
2. Open Agent panel again
3. Type "/" to trigger autocomplete
4. Check "Always allow tool actions" is enabled in agent settings

**Solution:** Check Zed logs and verify context_servers configuration.

### Command times out

**Problem:** Tool execution takes too long

**Typical durations:**
- Simple tools: <100ms
- File operations: <200ms
- Builds: 10-60s (depends on project)
- Full indexing: 30-60s (one-time)

**Solution:**
- Use incremental builds (faster)
- Avoid full rebuilds unless necessary
- For long operations, run outside Zed

### "anigma-mcp: command not found"

**Problem:** Binary not in PATH

**Solution:**
```bash
# Find where it is
which anigma-mcp
# or
ls -la /Users/user/.local/bin/anigma-mcp
# or
find ~ -name "anigma-mcp" 2>/dev/null

# Copy to standard location
cp /path/to/anigma-mcp /usr/local/bin/
chmod +x /usr/local/bin/anigma-mcp

# Verify
/usr/local/bin/anigma-mcp --version
```

### Tools return empty or error results

**Problem:** Search index not built

**Solution:**
```
In Zed Agent: /digest_codebase
This indexes the entire project for semantic search.
```

**Problem:** File permissions

**Check:**
```bash
ls -la ~/Developer/GitHub/Anigma/ | head -20
# Ensure you have read permissions
```

## Configuration Details

### Environment Variables

Pass to the MCP server:
```json
"env": {
  "ANIGMA_MCP_ENABLE": "true",      # Enable MCP mode
  "ANIGMA_LOG_LEVEL": "info"        # info, debug, warn, error
}
```

### Alternative Paths

If your anigma-mcp binary is elsewhere:
```json
"command": "/Users/your-username/path/to/anigma-mcp"
```

## Performance

### Caching Benefits

Tools automatically cache:
- File contents (100 entries, LRU eviction)
- Search indexes (rebuilt on file changes)
- Build artifacts (incremental compilation)
- Git diffs (30 minute TTL)

### Concurrent Requests

Zed + Claude Desktop + Codex CLI can all use anigma-mcp simultaneously:
- Up to 4-8 concurrent clients
- Requests handled sequentially with timeouts
- Each client gets isolated session

## Security

### Data Privacy

- ✅ All processing happens locally
- ✅ No data sent to cloud
- ✅ File access controlled by OS permissions
- ✅ All operations logged with evidence

### Tool Safety

Auto-approved tools (read-only):
- read_file, context_search, get_module_status
- list_artifacts, list_models, database_query
- get_system_health, list_active_alerts

Governed write operations:
- swift_build, swift_test, apply_patch
- Protected by KillSwitch, WriteGate, ABAC

## Advanced

### Custom Tool Registration

Create new tools:
```
In Zed Agent: /create_tool_contract with description...
```

### Tool Chaining

Ask assistant to chain tools:
```
"Use anigma to:
1. Search for 'TODO' comments with /context_search
2. Read each file with /read_file
3. Summarize all TODOs"
```

### Governance Monitoring

Check audit trails:
```
/verify_evidence_chain
/get_system_health
/trace_query
```

## Uninstalling

To remove anigma-mcp from Zed:

```bash
# Remove from settings
rm "context_servers.anigma" ~/.config/zed/settings.json

# Or restore backup
cp ~/.config/zed/settings.json.backup ~/.config/zed/settings.json

# Restart Zed
```

## Next Steps

1. ✅ Configure Zed (this guide)
2. ✅ Claude Desktop (already working)
3. ✅ Codex CLI (already working)
4. 🔄 Gemini Bridge (coming soon)

You now have 3 AI tools using the same local, governed backend!

## More Information

- [Main Integration Guide](../AI_TOOLS_INTEGRATION.md)
- [Claude Desktop Setup](./claude-desktop.md)
- [Codex CLI Setup](./codex-cli.md)
- [Gemini Bridge Setup](./gemini-bridge.md)
