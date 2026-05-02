#!/usr/bin/env python3

import json
import os
from pathlib import Path

# Path to Gemini settings
settings_path = Path.home() / ".gemini" / "settings.json"

# Load current settings
with open(settings_path, 'r') as f:
    settings = json.load(f)

# Add our MCP servers to the existing mcpServers
mcp_servers = settings.get("mcpServers", {})

# Add Cursor Indexing (HTTP transport)
mcp_servers["cursor-indexing"] = {
    "url": "http://localhost:8000",
    "name": "Cursor Search",
    "description": "Semantic search for Anigma codebase",
    "transport": "http"
}

# Add CodeGraph (HTTP transport)
mcp_servers["codegraph"] = {
    "url": "http://localhost:8080",
    "name": "CodeGraph",
    "description": "Architecture analysis for Anigma codebase",
    "transport": "http"
}

# Update the settings
settings["mcpServers"] = mcp_servers

# Save the updated settings
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)

print("✅ Gemini CLI configuration updated successfully!")
print("📋 Added MCP servers:")
print("   - cursor-indexing (http://localhost:8000)")
print("   - codegraph (http://localhost:8080)")
print("\n🔄 Please restart Gemini CLI for changes to take effect.")
print("   Command: gemini restart")