# Claude Desktop + anigma-mcp Integration

Claude Desktop is **already configured** with anigma-mcp. This guide explains setup and best practices.

## Current Status

✅ **Active & Enhanced** - All 16 tools auto-approved for efficient workflow

## What's Configured

**Configuration file:**
```
~/Library/Application Support/Claude/claude_desktop_config.json
```

**MCP Server:** anigma at `/Users/user/.local/bin/anigma-mcp`

**Auto-approved tools (16 of 17):**
- read_file, list_artifacts, list_models
- context_search, get_system_health, list_active_alerts
- database_query, trace_query, git_diff
- verify_evidence_chain, get_module_status
- digest_codebase, context_purge
- swift_build, swift_test, apply_patch

## Usage Examples

### Read Project Files

```
You: Can you read the CLAUDE.md file?
Claude: I'll use the anigma read_file tool...
[File contents displayed]
```

### Search Codebase

```
You: Use anigma to search for 'governance' patterns
Claude: Searching the codebase...
[Search results with line numbers and context]
```

### Build and Test

```
You: Build the Swift project using anigma
Claude: Running swift_build...
[Build output with timing]

You: Run the tests
Claude: Executing swift_test...
[Test results]
```

### Apply Code Changes

```
You: Apply these changes with anigma apply_patch
[You provide a diff]
Claude: Applying the patch...
[Confirmation of applied changes]
```

## Configuration Details

### Location

```
~/Library/Application Support/Claude/claude_desktop_config.json
```

### Structure

```json
{
  "mcpServers": {
    "anigma": {
      "command": "/Users/user/.local/bin/anigma-mcp",
      "args": [],
      "disabled": false,
      "autoApprove": [
        "read_file",
        "list_artifacts",
        // ... 14 more tools
      ],
      "env": {
        "ANIGMA_MCP_ENABLE": "true",
        "ANIGMA_LOG_LEVEL": "info"
      }
    }
  }
}
```

### Auto-Approved Tools

All 16 tools don't require manual confirmation:

**Read-only (10 tools):**
- read_file - Secure file reading
- list_artifacts - Browse build artifacts
- list_models - List ML models
- context_search - Semantic search
- get_system_health - System metrics
- list_active_alerts - Active alerts
- database_query - SQL queries
- trace_query - Query execution history
- git_diff - Repository changes
- verify_evidence_chain - Audit trails

**Indexed/Cache (3 tools):**
- get_module_status - MCP module status
- digest_codebase - Index project
- context_purge - Clear cache

**Write operations (3 tools, governed):**
- swift_build - Compile packages
- swift_test - Run tests
- apply_patch - Apply diffs

## Workflow Patterns

### Code Review

```
1. Ask Claude to search for TODOs: /context_search "TODO"
2. Read files: /read_file [paths]
3. Get recent changes: /git_diff
4. Suggest improvements and apply: /apply_patch
```

### Documentation

```
1. Index codebase: /digest_codebase
2. Search for patterns: /context_search [pattern]
3. Read relevant files: /read_file [path]
4. Generate documentation
```

### Bug Investigation

```
1. Check git changes: /git_diff
2. Search for related code: /context_search [keyword]
3. Read implementation: /read_file
4. Verify evidence trail: /verify_evidence_chain
```

### Feature Implementation

```
1. Search existing patterns: /context_search [pattern]
2. Read reference code: /read_file
3. Build changes: /swift_build
4. Run tests: /swift_test
5. Create diff: /git_diff
```

## Performance Tips

### Use Claude's context understanding

Claude can:
- Understand relationships between files
- Synthesize information across multiple searches
- Suggest optimal patterns based on codebase

### Combine tools effectively

```
Claude: I'll search for 'KillSwitch' references, read the
implementations, and explain the governance pattern.
[Using context_search + read_file]
```

### Request summaries

```
You: Summarize the last 5 commits and their impact
Claude: Getting recent changes... [git_diff]
Analyzing affected files... [read_file + context_search]
[Comprehensive summary]
```

## Governance & Safety

### Why auto-approve is safe

1. **Read-only tools** cannot modify files
2. **Write operations** protected by:
   - KillSwitch (emergency halt)
   - WriteGate (quality checks)
   - ABAC (access control)
3. **Evidence trails** log every operation
4. **Cryptographic signatures** verify integrity

### Evidence chain

Every tool call is:
- ✅ Logged with timestamp
- ✅ Signed with BLAKE3
- ✅ Associated with principal
- ✅ Recorded with result
- ✅ Queryable for audit

Check evidence:
```
You: Use anigma verify_evidence_chain to check recent operations
Claude: Verifying integrity...
[Evidence report]
```

## Troubleshooting

### Tools not available

**Check if Claude can see them:**
```
You: What anigma tools do you have access to?
Claude: [Lists all 16 tools]
```

If missing:
1. Restart Claude Desktop
2. Check config file syntax: `jq . ~/Library/Application\ Support/Claude/claude_desktop_config.json`
3. Verify binary exists: `ls -lh /Users/user/.local/bin/anigma-mcp`

### Tools return errors

**Check binary:**
```bash
/Users/user/.local/bin/anigma-mcp
# Should output JSON-RPC initialization message
```

**Check permissions:**
```bash
ls -la /Users/user/Developer/GitHub/Anigma/
# Ensure readable
```

### Claude ignores tool suggestions

Claude respects your preferences. If you prefer it not to use certain tools:
```
You: Don't use the build tools, only read operations
Claude: Understood, I'll stick to read-only tools.
```

## Configuration Changes

### To disable a tool

Remove from `autoApprove` array - Claude will ask before using it

### To disable all tools

Set `"disabled": true` in config

### To change log level

Edit `env.ANIGMA_LOG_LEVEL`:
- `debug` - Very detailed
- `info` - Standard (recommended)
- `warn` - Only warnings
- `error` - Only errors

### To use different binary location

Update `command` field:
```json
"command": "/path/to/anigma-mcp"
```

## Best Practices

1. **Let Claude use tools naturally** - It knows when they're useful
2. **Ask for specific tools** when you need certainty: "Use anigma context_search to..."
3. **Review tool outputs** for correctness, especially for write operations
4. **Use git to undo** if apply_patch makes unwanted changes
5. **Check evidence** regularly with verify_evidence_chain

## Advanced Usage

### Request detailed governance info

```
You: Tell me about the Anigma governance system
Claude: [Explanation + links to KillSwitch, WriteGate, ABAC]
```

### Get performance metrics

```
You: Use anigma get_system_health to show detailed metrics
Claude: [System health report with latencies, cache hits, etc.]
```

### Dynamic tool registration

```
You: Can you register a new custom tool that...?
Claude: Using anigma create_tool_contract...
[New tool registered]
```

## Privacy & Security

### Your data stays local

✅ All processing on your machine
✅ No cloud APIs (except initial setup)
✅ No telemetry sent outside network
✅ File access controlled by OS

### Governance layer

✅ All operations logged
✅ Emergency kill switch available
✅ Quality checks enforced
✅ Audit trails permanent

## Next Steps

1. ✅ Claude Desktop - Active (this page)
2. ✅ Codex CLI - [View setup](./codex-cli.md)
3. ✅ Zed Editor - [Configure it](./zed-editor.md)
4. 🔄 Gemini Bridge - Coming soon

You're ready to use anigma-mcp with Claude Desktop!

## More Information

- [Main Integration Guide](../AI_TOOLS_INTEGRATION.md)
- [Zed Editor Setup](./zed-editor.md)
- [Codex CLI Setup](./codex-cli.md)
- [Gemini Bridge Setup](./gemini-bridge.md)
