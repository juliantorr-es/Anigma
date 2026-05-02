> Historical status snapshot. This file reflects the state observed on 2026-04-21 and is not the source of truth for current status.
>
> Source of truth:
> - `td`
> - `anigma/current_build_status.txt`
> - `anigma/build_phase3_logs/`


# Anigma MCP Extension - Deployment Guide

**Complete guide to packaging and distributing the anigma-mcp Claude Desktop extension.**

## Status

✅ **Extension is ready for production packaging and distribution**

The anigma-mcp MCP server is fully implemented with:
- Production-grade scaling infrastructure
- Complete governance integration
- Comprehensive observability
- Multi-layer caching
- Adaptive throttling

Now we're building the **installable Claude Desktop extension** so users can get started with one click.

## Quick Start (30 Seconds)

```bash
cd ~/Developer/GitHub/Anigma

# Package as Claude Desktop extension
bash Scripts/package_extension.sh

# Output: anigma-mcp.mcpb
# Size: ~10-15MB (includes binary + assets)
```

Users can then:
1. Download `anigma-mcp.mcpb`
2. Double-click to install
3. Restart Claude Desktop
4. Ask Claude: **"Show me the system health"**

## Files Created

### Core Extension Files

| File | Purpose | Status |
|------|---------|--------|
| `extension/manifest.json` | Extension metadata (16 tools, config UI) | ✅ Created |
| `extension/README.md` | User-facing extension guide | ✅ Created |
| `extension/assets/icon.svg` | Source icon (vector) | ✅ Created |
| `extension/assets/icon-*.png` | Generated icons (4 sizes) | 🔄 Can be generated |

### Build & Packaging Scripts

| Script | Purpose | Status |
|--------|---------|--------|
| `Scripts/create_extension_icons.sh` | Generate PNG icons from SVG | ✅ Created |
| `Scripts/package_extension.sh` | Package as .mcpb archive | ✅ Created |
| `Scripts/setup_claude_desktop.sh` | Old method (manual config) | ✅ Existing |

### Documentation

| Document | Purpose | Status |
|----------|---------|--------|
| `Docs/CLAUDE_DESKTOP_EXTENSION_GUIDE.md` | Comprehensive extension guide | ✅ Created |
| `Docs/CLAUDE_INTEGRATION.md` | Integration architecture | ✅ Existing |
| `Docs/CLAUDE_DESKTOP_SETUP.md` | Manual setup instructions | ✅ Existing |
| `extension/README.md` | Extension user guide | ✅ Created |

## Production Workflow

### 1. Verify Binary is Built

```bash
ls -lh .build/release/anigma-mcp
# Should show: 70-80MB executable
```

### 2. Generate Icons (Optional)

If you want custom icons instead of placeholders:

```bash
# Option A: Using ImageMagick
brew install imagemagick
bash Scripts/create_extension_icons.sh

# Option B: Using Inkscape
brew install inkscape
bash Scripts/create_extension_icons.sh

# Option C: Manual (online converter)
# Use https://cloudconvert.com/svg-to-png
# Upload: extension/assets/icon.svg
# Generate: 32x32, 64x64, 128x128, 256x256 PNGs
```

### 3. Package as .mcpb

```bash
bash Scripts/package_extension.sh

# Output: anigma-mcp.mcpb (~10-15MB)
# Ready to distribute!
```

### 4. Test Locally

```bash
# Install for testing
rm -rf ~/Library/Application\ Support/Claude/anigma-mcp/
unzip anigma-mcp.mcpb -d ~/Library/Application\ Support/Claude/

# Restart Claude
killall Claude
sleep 2
open -a Claude

# Test
# Ask Claude: "Show me the system health"
```

### 5. Release

Choose a distribution method:

#### Option A: GitHub Releases (Recommended)

```bash
# Tag the release
git tag v1.0.0
git push origin v1.0.0

# Create release with gh CLI
gh release create v1.0.0 anigma-mcp.mcpb \
  --title "Anigma MCP v1.0.0 - Claude Desktop Extension" \
  --notes "One-click Claude Desktop extension with local-first AI governance"
```

#### Option B: Direct Download

Host on your website/server:
```
https://anigma.dev/download/anigma-mcp.mcpb
```

#### Option C: Claude Registry (Coming Soon)

Submit to https://registry.modelcontextprotocol.io

## What Users Get

### Installation

1. **Download** `anigma-mcp.mcpb`
2. **Double-click** - Claude Desktop extracts automatically
3. **Restart Claude** - Anigma MCP is ready
4. **No manual config required** ✨

### Configuration UI

Claude Desktop automatically renders config UI for:
- Project root path
- Logging level
- Cache size
- Rate limits
- Concurrent request limits

Users can adjust via Claude Desktop settings without touching JSON.

### 16 Available Tools

**Fast Reads (Instant)**
- read_file, list_artifacts, list_models, get_system_health, list_active_alerts

**Search & Query (Normal)**
- context_search, database_query, trace_query, git_diff

**Heavy Compute (May take time)**
- swift_build, swift_test, digest_codebase

**Mutations (Need approval)**
- apply_patch, create_tool_contract, context_purge, verify_evidence_chain

## Technical Details

### .mcpb Format

A .mcpb is simply a ZIP archive with:

```
anigma-mcp.mcpb
├── anigma-mcp/
│   ├── manifest.json          # Extension metadata
│   ├── anigma-mcp             # Binary executable
│   ├── README.md              # Documentation
│   └── assets/
│       ├── icon-32.png
│       ├── icon-64.png
│       ├── icon-128.png
│       └── icon-256.png
```

### manifest.json

Key sections:

```json
{
  "manifest_version": "0.3",          // MCP standard version
  "name": "anigma-mcp",               // ID
  "display_name": "Anigma MCP",       // User-facing name
  "version": "1.0.0",                 // Semantic versioning
  "server": {
    "type": "binary",                 // Type of server
    "entry_point": "anigma-mcp"       // Binary name
  },
  "tools": [                          // 16 tools
    { "name": "read_file", "description": "..." },
    ...
  ],
  "user_config": {                    // Config UI
    "anigma_project_root": { ... },
    "log_level": { ... },
    ...
  },
  "icons": [                          // Icon sizes
    { "path": "assets/icon-32.png", "size": "32x32" },
    ...
  ]
}
```

### Security Considerations

- ✅ Local-only execution (no network)
- ✅ Read tools are safe (auto-approved)
- ✅ Write tools require approval
- ✅ All operations auditable
- ✅ Sandboxed by Claude Desktop

## Troubleshooting

### Extension Won't Install

```bash
# Verify .mcpb is valid ZIP
unzip -t anigma-mcp.mcpb
# Should show: testing: anigma-mcp/manifest.json   OK

# Check manifest JSON syntax
python3 -m json.tool extension/manifest.json > /dev/null
# Should print nothing if valid
```

### Binary Not Found

```bash
# Verify binary is in archive
unzip -l anigma-mcp.mcpb | grep "anigma-mcp$"
# Should show: anigma-mcp/anigma-mcp

# Verify it's executable
ls -la anigma-mcp/anigma-mcp
# Should show: -rwxr-xr-x (executable)
```

### Configuration UI Not Appearing

```bash
# Verify user_config in manifest
grep -A 20 '"user_config"' extension/manifest.json

# Check for JSON syntax errors
python3 -m json.tool extension/manifest.json | grep -A 5 user_config
```

## Version Updates

When releasing v1.0.1:

1. Update version in manifest:
   ```json
   "version": "1.0.1"
   ```

2. Rebuild:
   ```bash
   swift build -c release
   bash Scripts/package_extension.sh
   ```

3. Tag and release:
   ```bash
   git tag v1.0.1
   gh release create v1.0.1 anigma-mcp.mcpb
   ```

## Future Enhancements

- **Auto-updates**: Check for new versions periodically
- **Code signing**: Sign binary for macOS security
- **Telemetry**: Optional usage metrics
- **Extended tools**: Add domain-specific tools
- **Multi-platform**: Extend to Windows/Linux

## Distribution Checklist

Before releasing:

- [ ] Swift build completes: `swift build -c release`
- [ ] Binary exists: `ls .build/release/anigma-mcp`
- [ ] Icons generated: `ls extension/assets/icon-*.png`
- [ ] Package created: `bash Scripts/package_extension.sh`
- [ ] Archive valid: `unzip -t anigma-mcp.mcpb`
- [ ] Manifest valid: `python3 -m json.tool extension/manifest.json`
- [ ] Installed locally and tested
- [ ] All 16 tools work
- [ ] Config UI renders properly
- [ ] Get health returns metrics
- [ ] Caching works (fast on second call)
- [ ] Documentation updated

## Next Steps

### Immediate (Ready Now)

```bash
# 1. Generate icons (optional but recommended)
bash Scripts/create_extension_icons.sh

# 2. Package extension
bash Scripts/package_extension.sh

# 3. Test locally
unzip anigma-mcp.mcpb -d ~/Library/Application\ Support/Claude/
killall Claude
open -a Claude
# Ask: "Show me the system health"

# 4. Publish to GitHub releases
gh release create v1.0.0 anigma-mcp.mcpb
```

### Future (Coming Soon)

- Submit to Claude registry for discovery
- Add auto-update mechanism
- Code-sign binary for macOS
- Create video tutorial
- Publish blog post about anigma-mcp

## Resources

- [Model Context Protocol](https://modelcontextprotocol.io)
- [MCP Implementation Guide](https://modelcontextprotocol.io/docs)
- [Extension Guide](./Docs/CLAUDE_DESKTOP_EXTENSION_GUIDE.md)
- [Integration Architecture](./Docs/CLAUDE_INTEGRATION.md)
- [Setup Instructions](./Docs/CLAUDE_DESKTOP_SETUP.md)

---

**Status:** ✅ Production Ready

The anigma-mcp extension is ready for deployment. Users can now install it directly from Claude Desktop with one click!
