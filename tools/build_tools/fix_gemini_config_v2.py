#!/usr/bin/env python3

import json
import os
from pathlib import Path

# Path to Gemini settings
settings_path = Path.home() / ".gemini" / "settings.json"

# Load current settings
with open(settings_path, 'r') as f:
    settings = json.load(f)

# Fix the MCP server configuration
mcp_servers = settings.get("mcpServers", {})

# Remove invalid fields and keep only what Gemini CLI supports
if "cursor-indexing" in mcp_servers:
    mcp_servers["cursor-indexing"] = {
        "url": "http://localhost:8000",
        "description": "Semantic search for Anigma codebase"
    }

if "codegraph" in mcp_servers:
    mcp_servers["codegraph"] = {
        "url": "http://localhost:8080",
        "description": "Architecture analysis for Anigma codebase"
    }

# Update the settings
settings["mcpServers"] = mcp_servers

# Save the updated settings
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)

print("✅ Gemini CLI configuration fixed!")
print("📋 Updated MCP servers:")
print("   - cursor-indexing (http://localhost:8000)")
print("   - codegraph (http://localhost:8080)")
print("\n🔄 Configuration is now valid.")
print("   Test with: gemini mcp list")