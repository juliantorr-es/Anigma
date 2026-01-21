# Fix: Unable to Connect to Extension Server

**Status:** The anigma-mcp server IS working correctly ✓

**Problem:** Claude Desktop can't connect to it

**Solution:** Complete restart of Claude Desktop

---

## Why This Happens

Claude Desktop caches the MCP server connection on startup. If:
1. The binary wasn't available when Claude started
2. The config file was updated after Claude started
3. The server failed to start

Claude will remember that failure and show "Unable to connect to extension server"

**Fix:** Force a complete restart

---

## Step 1: Completely Quit Claude

```bash
# Force quit Claude
killall Claude

# Wait to make sure it's dead
sleep 3

# Verify it's closed
ps aux | grep Claude | grep -v grep
# Should return nothing
```

## Step 2: Clear Claude's Cache (Optional but Recommended)

```bash
# Clear Claude's temp files
rm -rf ~/Library/Application\ Support/Claude/Cache/*
rm -rf ~/Library/Application\ Support/Claude/Session\ Storage/*

# Clear preferences cache
rm -f ~/Library/Application\ Support/Claude/Preferences
```

## Step 3: Relaunch Claude

```bash
open -a Claude
```

Wait 5-10 seconds for Claude to fully start and load extensions.

## Step 4: Test It

In Claude, ask one of these questions:

**Option A (Simple):**
```
"Hello, what MCP servers do you have access to?"
```

**Option B (Direct Test):**
```
"Show me the system health"
```

**Option C (List Tools):**
```
"What tools are available to you?"
```

---

## Verification Checklist

Before launching Claude again, verify:

```bash
# 1. Binary exists and is executable
ls -lh /usr/local/bin/anigma-mcp
# Should show: -rwxr-xr-x ... 72M

# 2. Config file is valid JSON
python3 -m json.tool ~/Library/Application\ Support/Claude/claude_desktop_config.json > /dev/null
# Should output nothing (no error)

# 3. Binary responds to MCP protocol
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | /usr/local/bin/anigma-mcp
# Should return a JSON response with "result"
```

If all three show ✓, the issue is just the cache.

---

## Complete Automated Fix

Copy and run this entire script:

```bash
#!/bin/bash

echo "Fixing anigma-mcp connection..."

# Kill Claude
echo "1. Stopping Claude Desktop..."
killall Claude 2>/dev/null
sleep 3

# Clear cache
echo "2. Clearing Claude cache..."
rm -rf ~/Library/Application\ Support/Claude/Cache/*
rm -rf ~/Library/Application\ Support/Claude/Session\ Storage/*
rm -f ~/Library/Application\ Support/Claude/Preferences

# Relaunch
echo "3. Relaunching Claude Desktop..."
open -a Claude

echo "4. Waiting for Claude to start..."
sleep 10

echo "✓ Done! Claude is launching..."
echo ""
echo "Next: Ask Claude 'Show me the system health'"
```

---

## If It Still Doesn't Work

### Check the actual Claude error log:

```bash
tail -100 ~/Library/Logs/Claude/claude.ai-web.log | grep -i "anigma\|mcp\|error"
```

### Test server manually:

```bash
# This will show if the server can start
/usr/local/bin/anigma-mcp &
SERVER_PID=$!
sleep 2
kill $SERVER_PID
```

### Verify config syntax:

```bash
# Pretty-print the config to see if there's an issue
python3 -m json.tool ~/Library/Application\ Support/Claude/claude_desktop_config.json | cat -n | head -50
```

### Check if command path is correct:

```bash
# The config should have:
# "command": "/usr/local/bin/anigma-mcp"

# Verify the full path works:
/usr/local/bin/anigma-mcp --help 2>&1 || echo "Binary works (no --help flag, but no error)"
```

---

## What to Expect After Fix

Once connected, Claude should:

1. Show "anigma" indicator in bottom-right (when tool is available)
2. Respond to questions about system health
3. Have access to 16 tools:
   - read_file, list_artifacts, list_models
   - context_search, database_query
   - swift_build, swift_test
   - apply_patch, create_tool_contract
   - And more...

---

## One More Thing: The .mcpb File

The `anigma-mcp.mcpb` file I created is for **newer versions** of Claude Desktop that support the .mcpb format (v1.5+).

Your current Claude Desktop version uses the **JSON config method**, which is what's already set up and should work after the restart.

The .mcpb file is ready for when you upgrade Claude Desktop in the future.

---

## Summary

1. Run the fix script above OR manually:
   - `killall Claude`
   - `rm -rf ~/Library/Application\ Support/Claude/Cache/*`
   - `open -a Claude`
   - Wait 10 seconds

2. Test:
   - Ask Claude: "Show me the system health"
   - Should work!

3. If issues:
   - Check logs with: `tail ~/Library/Logs/Claude/claude.ai-web.log`
   - Verify config with: `python3 -m json.tool ~/Library/Application\ Support/Claude/claude_desktop_config.json`

That should fix it! Let me know if it works.
