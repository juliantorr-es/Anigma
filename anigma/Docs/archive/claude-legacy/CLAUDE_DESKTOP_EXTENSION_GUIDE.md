# Claude Desktop Extension Guide

Complete guide to building, packaging, and distributing the anigma-mcp extension for Claude Desktop.

## What is .mcpb?

**.mcpb** (MCP Bundle) is the modern standard format for Claude Desktop extensions:

- A ZIP archive containing the extension package
- Includes binary executable, configuration, and assets
- Users can install with one double-click (no manual config)
- Claude Desktop extracts and configures automatically
- Significantly better UX than manual JSON editing

### .mcpb vs Old Method

| Aspect | Old Method (.json) | New Method (.mcpb) |
|--------|------|------|
| Installation | Edit `claude_desktop_config.json` | Double-click `.mcpb` file |
| User Friction | High (JSON editing) | Low (one click) |
| Error Prone | Yes (config mistakes) | No (auto-extracted) |
| Distribution | Manual setup instructions | Single file download |
| Updates | Manual file replacement | Claude Desktop handles |

## .mcpb Bundle Structure

A valid .mcpb must contain:

```
anigma-mcp.mcpb (zip archive)
├── anigma-mcp/
│   ├── manifest.json          (required)
│   ├── anigma-mcp             (binary executable)
│   ├── README.md              (optional but recommended)
│   └── assets/
│       ├── icon-32.png        (optional but recommended)
│       ├── icon-64.png
│       ├── icon-128.png
│       └── icon-256.png
```

### manifest.json Structure

```json
{
  "manifest_version": "0.3",
  "name": "anigma-mcp",
  "display_name": "Anigma MCP",
  "version": "1.0.0",
  "description": "...",
  "server": {
    "type": "binary",
    "entry_point": "anigma-mcp"
  },
  "tools": [
    {
      "name": "tool_name",
      "description": "Tool description"
    }
  ],
  "user_config": {
    "setting_name": {
      "type": "string|number|boolean",
      "title": "Display Title",
      "description": "Help text",
      "default": "default_value"
    }
  },
  "icons": [
    {
      "path": "assets/icon-32.png",
      "size": "32x32"
    }
  ]
}
```

## Building & Packaging

### Quick Build

```bash
cd ~/Developer/GitHub/Anigma

# Build the binary
swift build -c release

# Package as .mcpb
bash Scripts/package_extension.sh

# Output: anigma-mcp.mcpb
```

### Step-by-Step

#### 1. Generate Icons (Optional but Recommended)

```bash
bash Scripts/create_extension_icons.sh
```

This requires ImageMagick:

```bash
brew install imagemagick
```

Or use an online converter: https://cloudconvert.com/svg-to-png
- Input: `extension/assets/icon.svg`
- Output 4 sizes: 32x32, 64x64, 128x128, 256x256

#### 2. Verify Extension Files

All files should exist:

```bash
ls -la extension/
  manifest.json        # ✓ required
  README.md           # ✓ recommended
  assets/
    icon-32.png       # ✓ recommended
    icon-64.png
    icon-128.png
    icon-256.png
```

#### 3. Build the Binary

```bash
swift build -c release
# Output: .build/release/anigma-mcp
```

#### 4. Package as .mcpb

```bash
bash Scripts/package_extension.sh
# Output: anigma-mcp.mcpb (~10MB)
```

The script automatically:
- ✅ Builds the binary
- ✅ Verifies all required files
- ✅ Creates placeholder icons (if ImageMagick available)
- ✅ Zips everything into .mcpb format
- ✅ Places in repo root: `anigma-mcp.mcpb`

### Manual Packaging (If Script Fails)

```bash
# Create staging directory
mkdir -p /tmp/anigma-mcp-bundle/anigma-mcp

# Copy files
cp extension/manifest.json /tmp/anigma-mcp-bundle/anigma-mcp/
cp extension/README.md /tmp/anigma-mcp-bundle/anigma-mcp/
cp .build/release/anigma-mcp /tmp/anigma-mcp-bundle/anigma-mcp/
chmod +x /tmp/anigma-mcp-bundle/anigma-mcp/anigma-mcp

# Copy assets
cp -r extension/assets /tmp/anigma-mcp-bundle/anigma-mcp/

# Create zip
cd /tmp/anigma-mcp-bundle
zip -r ~/Developer/GitHub/Anigma/anigma-mcp.mcpb anigma-mcp/

# Result: ~/Developer/GitHub/Anigma/anigma-mcp.mcpb
```

## Installation

### For Users

#### Method 1: Double-Click (Recommended)

1. Download `anigma-mcp.mcpb`
2. Double-click the file
3. Claude Desktop will:
   - Detect the .mcpb format
   - Extract to `~/Library/Application Support/Claude/`
   - Show configuration UI for settings
   - Automatically approve safe tools
4. Restart Claude Desktop (`Cmd+Q`, then relaunch)
5. Look for "anigma" indicator in bottom-right

#### Method 2: Manual Installation

```bash
# Unzip the bundle
unzip anigma-mcp.mcpb -d ~/Library/Application\ Support/Claude/

# Result: ~/Library/Application Support/Claude/anigma-mcp/
#   ├── manifest.json
#   ├── anigma-mcp (binary)
#   ├── README.md
#   └── assets/

# Restart Claude Desktop
```

#### Method 3: Command-Line

```bash
# Open with Claude Desktop
open -a "Claude Desktop" anigma-mcp.mcpb
```

### Verification

Ask Claude:

```
"Show me the system health"
```

Claude should:
1. See the anigma MCP server is available
2. Call `get_system_health` tool
3. Return JSON with MCP metrics
4. Display formatted response

If it works, installation is complete! ✅

## Distribution

### Option 1: GitHub Releases (Recommended)

1. Create a GitHub release on https://github.com/anthropics/anigma
2. Upload `anigma-mcp.mcpb` as an asset
3. Users can download and install with one double-click

**Pros:**
- Simple distribution
- Users see release notes
- Built-in version management
- No server required

**Steps:**

```bash
# Create release via GitHub CLI
gh release create v1.0.0 anigma-mcp.mcpb \
  --title "Anigma MCP v1.0.0" \
  --notes "Claude Desktop extension for anigma-mcp"
```

Or via GitHub web UI:
1. Go to Releases
2. New Release
3. Upload `anigma-mcp.mcpb`
4. Publish

### Option 2: Claude Registry (Official Directory)

Coming soon when Claude Desktop registry is public:

1. Submit extension to https://registry.modelcontextprotocol.io
2. Undergo security review
3. Get listed in Claude Desktop's built-in extension store
4. Users can install directly from Claude Desktop GUI

**Pros:**
- Maximum discoverability
- Official validation
- One-click from Claude
- Automatic updates

### Option 3: Website/Documentation

1. Host `anigma-mcp.mcpb` on your website
2. Provide download link in documentation
3. Users download and double-click to install

**Pros:**
- Full control
- Branding opportunities
- Analytics

**Cons:**
- Manual hosting required
- Users must find the link

### Option 4: Auto-Update System

For future versions, consider:

```json
{
  "manifest_version": "0.3",
  "name": "anigma-mcp",
  "version": "1.0.0",
  "updateUrl": "https://anigma.dev/extensions/anigma-mcp/latest.json",
  ...
}
```

Claude Desktop can check updateUrl periodically and prompt users to update.

## Troubleshooting

### "Binary not found" Error

**Problem:** Claude Desktop shows "anigma-mcp binary not found"

**Solutions:**

1. Verify binary is in bundle:
   ```bash
   unzip -l anigma-mcp.mcpb | grep anigma-mcp
   # Should show: anigma-mcp/anigma-mcp
   ```

2. Check permissions:
   ```bash
   ls -la ~/Library/Application\ Support/Claude/anigma-mcp/anigma-mcp
   # Should be executable (x permission)
   ```

3. Rebuild and repackage:
   ```bash
   swift build -c release
   bash Scripts/package_extension.sh
   ```

### "Invalid manifest" Error

**Problem:** Claude Desktop won't recognize the extension

**Solutions:**

1. Validate JSON syntax:
   ```bash
   python3 -m json.tool extension/manifest.json > /dev/null
   # Should print nothing if valid
   ```

2. Check manifest_version:
   ```bash
   grep manifest_version extension/manifest.json
   # Must be "0.3"
   ```

3. Verify required fields in manifest:
   - name
   - display_name
   - version
   - server.type = "binary"
   - server.entry_point

### Extension Not Appearing in Claude

**Problem:** Claude Desktop shows no "anigma" indicator

**Solutions:**

1. Verify extraction:
   ```bash
   ls -la ~/Library/Application\ Support/Claude/anigma-mcp/
   # Should show: manifest.json, anigma-mcp (binary), README.md
   ```

2. Check installation location:
   ```bash
   # Should be here (no subdirectories)
   ~/Library/Application Support/Claude/anigma-mcp/

   # NOT here (wrong location)
   ~/Library/Application Support/Claude/anigma-mcp/anigma-mcp/
   ```

3. Try manual installation:
   ```bash
   rm -rf ~/Library/Application\ Support/Claude/anigma-mcp/
   unzip anigma-mcp.mcpb -d ~/Library/Application\ Support/Claude/
   ```

4. Completely restart Claude:
   ```bash
   killall "Claude"
   sleep 2
   open -a Claude
   ```

### Tools Timing Out

See [CLAUDE_INTEGRATION.md - Troubleshooting](./CLAUDE_INTEGRATION.md#troubleshooting)

## Configuration Deep-Dive

### User Config in manifest.json

Claude Desktop renders a configuration UI based on `user_config` in manifest.json:

```json
{
  "user_config": {
    "anigma_project_root": {
      "type": "directory",
      "title": "Anigma Project Root",
      "description": "Path to your Anigma repository",
      "required": false,
      "default": "${HOME}/Developer/GitHub/Anigma"
    },
    "log_level": {
      "type": "string",
      "title": "Logging Level",
      "description": "Control verbosity (debug, info, warn, error)",
      "enum": ["debug", "info", "warn", "error"],
      "default": "info"
    },
    "cache_size_mb": {
      "type": "number",
      "title": "File Cache Size (MB)",
      "min": 1,
      "max": 500,
      "default": 10
    }
  }
}
```

**Supported Types:**
- `string` - Text input
- `number` - Numeric input
- `boolean` - Toggle switch
- `directory` - Directory picker
- `file` - File picker

**Special Fields:**
- `enum` - List of allowed values (renders as dropdown)
- `default` - Default value
- `required` - Whether setting is mandatory
- `min`/`max` - Numeric bounds

### Environment Variables

Users can also set environment variables before launching Claude Desktop:

```bash
export ANIGMA_LOG_LEVEL=debug
export ANIGMA_CACHE_SIZE_MB=50
open -a Claude
```

## Security Considerations

### Code Signing (macOS)

For production distribution, consider code-signing the binary:

```bash
# Generate self-signed certificate (development)
codesign -s - .build/release/anigma-mcp

# Or use Apple Developer certificate (production)
codesign -s "Apple Development: your@email.com" \
  --timestamp \
  .build/release/anigma-mcp
```

### Notarization

For macOS Ventura+, consider notarizing the binary:

```bash
xcrun altool --notarize-app -f anigma-mcp.mcpb \
  -t macOS \
  -u apple-id@example.com \
  -p app-specific-password
```

### Sandboxing

Claude Desktop runs MCP extensions in restricted sandbox. anigma-mcp has access to:
- Anigma project directory
- User's home directory
- System utilities (git, swift, etc.)

No network access by default (safe for local-only use).

## Testing Before Release

### Checklist

Before packaging and distributing:

- [ ] `swift build -c release` completes without errors
- [ ] `bash Scripts/package_extension.sh` produces valid .mcpb
- [ ] `unzip -t anigma-mcp.mcpb` shows no errors
- [ ] Double-clicking .mcpb opens in Claude Desktop
- [ ] All 4 icon sizes appear correctly
- [ ] Configuration UI renders properly
- [ ] `get_system_health` returns valid metrics
- [ ] `read_file` caches results (second call is fast)
- [ ] `context_search` returns relevant results
- [ ] `swift_build` times out gracefully (doesn't hang)
- [ ] Switching between tools works smoothly
- [ ] Restarting Claude doesn't lose configuration

### Manual Testing

```bash
# 1. Build and package
swift build -c release
bash Scripts/package_extension.sh

# 2. Install locally
rm -rf ~/Library/Application\ Support/Claude/anigma-mcp/
unzip anigma-mcp.mcpb -d ~/Library/Application\ Support/Claude/

# 3. Restart Claude
killall Claude
sleep 2
open -a Claude

# 4. Test in Claude
# Ask: "Show me the system health"
# Should return MCP metrics without error
```

## Version Bumping

When releasing a new version:

1. Update version in `extension/manifest.json`:
   ```json
   "version": "1.0.1"
   ```

2. Rebuild and repackage:
   ```bash
   swift build -c release
   bash Scripts/package_extension.sh
   ```

3. Create release tag:
   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```

4. Upload to releases

## References

- [Model Context Protocol (MCP)](https://modelcontextprotocol.io)
- [Claude Desktop Documentation](https://claude.ai/docs)
- [anigma-mcp GitHub Repository](https://github.com/anthropics/anigma)
- [Anigma Integration Guide](./CLAUDE_INTEGRATION.md)
