#!/usr/bin/env python3

import json
from pathlib import Path

# Path to Gemini settings
settings_path = Path.home() / ".gemini" / "settings.json"

# Load current settings
with open(settings_path, 'r') as f:
    settings = json.load(f)

# Get current MCP servers
mcp_servers = settings.get("mcpServers", {})

# Add our MCP servers with proper command-based configuration
mcp_servers["cursor-indexing"] = {
    "command": "/Users/user/mcp_wrappers/cursor-indexing-mcp",
    "args": [],
    "env": {}
}

mcp_servers["codegraph"] = {
    "command": "/Users/user/mcp_wrappers/codegraph-mcp",
    "args": [],
    "env": {}
}

# Update the settings
settings["mcpServers"] = mcp_servers

# Save the updated settings
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)

print("✅ Gemini CLI MCP servers added!")
print("📋 Added servers:")
print("   - cursor-indexing: /Users/user/mcp_wrappers/cursor-indexing-mcp")
print("   - codegraph: /Users/user/mcp_wrappers/codegraph-mcp")
print("\n🔄 Please restart Gemini CLI or run:")
print("   gemini mcp enable cursor-indexing")
print("   gemini mcp enable codegraph")