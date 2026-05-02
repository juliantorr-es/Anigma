# Installation Troubleshooting Guide

## What Happened?

You have **two ways to install** anigma-mcp with Claude Desktop:

### Method 1: Old Way (Currently Active)
✅ **This is already working!**
- Uses `claude_desktop_config.json`
- Binary at `/usr/local/bin/anigma-mcp`
- Configuration at `~/Library/Application Support/Claude/claude_desktop_config.json`
- The config is already set up and anigma is enabled

### Method 2: New Way (What I Created)
- Uses `.mcpb` format (modern standard)
- File: `anigma-mcp.mcpb` (18 MB)
- Installation: Double-click to install
- For Claude Desktop v1.5+

---

## Check If It's Working

### Step 1: Verify Binary Exists
```bash
which anigma-mcp
# Should show: /usr/local/bin/anigma-mcp

ls -lh /usr/local/bin/anigma-mcp
# Should show: 72M executable
```

**Status:** ✅ Binary exists

### Step 2: Verify Configuration
```bash
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json | grep -A 5 anigma
```

**Status:** ✅ Configuration exists with anigma enabled

### Step 3: Restart Claude Desktop
```bash
# Completely quit Claude
killall Claude

# Wait a moment
sleep 2

# Relaunch
open -a Claude
```

### Step 4: Test in Claude
Ask Claude these questions:
1. **"List your available tools"** - Should see anigma tools
2. **"Show me the system health"** - Should call get_system_health tool
3. **"What's your status?"** - Should respond with MCP server info

---

## Troubleshooting Steps

### Issue: Claude doesn't show anigma tools

**Solution 1: Restart Claude completely**
```bash
killall Claude
sleep 2
open -a Claude
```

**Solution 2: Check config file permissions**
```bash
ls -la ~/Library/Application\ Support/Claude/claude_desktop_config.json
# Should be readable by your user
```

**Solution 3: Verify binary is executable**
```bash
ls -la /usr/local/bin/anigma-mcp
# Should show: -rwxr-xr-x (executable)
```

**Solution 4: Try rebuilding binary**
```bash
cd ~/Developer/GitHub/Anigma
swift build -c release
# Should succeed without errors
```

### Issue: Binary exists but says "not found"

**Possible causes:**
1. Binary not executable
2. Wrong path in config
3. Binary corrupted

**Fixes:**
```bash
# Make sure it's executable
chmod +x /usr/local/bin/anigma-mcp

# Verify it can run
/usr/local/bin/anigma-mcp --version 2>&1 | head -5
# May show error (it's an MCP server, expects stdin)
# But if it starts, that's good sign

# Copy fresh binary if corrupted
cp ~/.build/release/anigma-mcp /usr/local/bin/anigma-mcp
chmod +x /usr/local/bin/anigma-mcp
```

### Issue: Claude won't connect to anigma

**Solution 1: Check config syntax**
```bash
python3 -m json.tool ~/Library/Application\ Support/Claude/claude_desktop_config.json > /dev/null
# Should output nothing if valid
# If error, config JSON is broken
```

**Solution 2: Verify command path**
```bash
# In config file, command should be:
"command": "/usr/local/bin/anigma-mcp"

# NOT:
"command": "anigma-mcp"           # (without full path)
"command": "~/.build/release/..."  # (with ~ expansion)
```

**Solution 3: Check if process starts**
```bash
# Try running it directly
timeout 2 /usr/local/bin/anigma-mcp 2>&1 || echo "Process started (expected to timeout)"
```

---

## The Two Installation Methods

### Method 1: JSON Config (Current - Working)

**How it works:**
1. Binary at `/usr/local/bin/anigma-mcp`
2. Claude reads `claude_desktop_config.json`
3. Launches binary as subprocess
4. Communicates via JSON-RPC stdin/stdout

**Your setup:**
```json
{
  "mcpServers": {
    "anigma": {
      "command": "/usr/local/bin/anigma-mcp",
      "disabled": false,
      "autoApprove": [...]
    }
  }
}
```

✅ **This method is currently active and should work**

---

### Method 2: .mcpb Format (New - Future)

**What is .mcpb?**
- ZIP archive with extension metadata
- Modern Claude Desktop format
- Double-click to install
- Automatic configuration UI
- For Claude Desktop v1.5+

**What I created:**
```
anigma-mcp.mcpb (18 MB)
├── manifest.json (configuration)
├── anigma-mcp (binary)
├── README.md
└── assets/ (icons)
```

**Installation:**
1. Double-click `anigma-mcp.mcpb`
2. Claude Desktop extracts it
3. Restart Claude
4. Done!

**Status:** ✅ File created and ready, but your Claude Desktop version may not support .mcpb yet

---

## Next Steps

### If Current Setup is Broken
1. Run troubleshooting steps above
2. Restart Claude Desktop
3. Test with simple prompt

### If You Want to Use .mcpb Format
1. Check Claude Desktop version (Help → About)
2. If v1.5+, double-click `anigma-mcp.mcpb`
3. If earlier, stick with JSON config

### If Still Not Working
1. Save your current config:
   ```bash
   cp ~/Library/Application\ Support/Claude/claude_desktop_config.json ~/Desktop/backup-config.json
   ```

2. Try completely fresh install:
   ```bash
   # Remove config
   rm ~/Library/Application\ Support/Claude/claude_desktop_config.json

   # Restart Claude - it will recreate default config
   killall Claude
   sleep 2
   open -a Claude

   # Add anigma back manually to config
   ```

3. Run a test:
   ```bash
   # In Claude, ask: "Hello, what MCP servers do you have access to?"
   # Should mention anigma
   ```

---

## Config File Reference

**File location:**
```
~/Library/Application Support/Claude/claude_desktop_config.json
```

**Full example:**
```json
{
  "preferences": {
    "quickEntryDictationShortcut": "capslock"
  },
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

---

## Quick Diagnostics

Run this to check everything:

```bash
#!/bin/bash

echo "=== Binary Check ==="
ls -lh /usr/local/bin/anigma-mcp && echo "✓ Binary exists" || echo "✗ Binary missing"

echo ""
echo "=== Config Check ==="
python3 -m json.tool ~/Library/Application\ Support/Claude/claude_desktop_config.json > /dev/null && echo "✓ Config valid JSON" || echo "✗ Config invalid"

echo ""
echo "=== anigma in Config? ==="
grep -c '"anigma"' ~/Library/Application\ Support/Claude/claude_desktop_config.json && echo "✓ anigma found in config" || echo "✗ anigma not in config"

echo ""
echo "=== Binary Executable? ==="
[ -x /usr/local/bin/anigma-mcp ] && echo "✓ Binary is executable" || echo "✗ Binary not executable"

echo ""
echo "=== Can Process Start? ==="
timeout 1 /usr/local/bin/anigma-mcp 2>&1 | head -1 && echo "✓ Process starts" || echo "✓ Process starts (timeout expected)"
```

---

## What Error Did You See?

Please tell me:
1. What exactly happened when you tried to install?
2. Did you double-click the .mcpb file?
3. Or were you expecting something else?
4. Any error messages?

I can help you fix it once I know the specific issue!
