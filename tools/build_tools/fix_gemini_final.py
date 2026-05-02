#!/usr/bin/env python3

import json
import os
from pathlib import Path

# Path to Gemini settings
settings_path = Path.home() / ".gemini" / "settings.json"

# Load current settings
with open(settings_path, 'r') as f:
    settings = json.load(f)

# Get current MCP servers
mcp_servers = settings.get("mcpServers", {})

# Add our HTTP MCP servers with correct format
mcp_servers["cursor-indexing"] = {
    "endpoint": "http://localhost:8000",
    "transport": "http",
    "description": "Semantic search for Anigma codebase"
}

mcp_servers["codegraph"] = {
    "endpoint": "http://localhost:8080",
    "transport": "http",
    "description": "Architecture analysis for Anigma codebase"
}

# Update the settings
settings["mcpServers"] = mcp_servers

# Save the updated settings
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)

print("✅ Gemini CLI configuration updated with correct format!")
print("📋 Added MCP servers:")
print("   - cursor-indexing (http://localhost:8000)")
print("   - codegraph (http://localhost:8080)")
print("\n🔄 Configuration now uses proper 'endpoint' format.")
print("   Test with: gemini mcp list")