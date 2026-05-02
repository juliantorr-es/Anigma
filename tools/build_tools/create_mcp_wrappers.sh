#!/bin/bash

echo "🔧 Creating MCP server wrapper scripts..."

# Create directory for wrappers
mkdir -p ~/mcp_wrappers

# Create Cursor Indexing wrapper
cat > ~/mcp_wrappers/cursor-indexing-mcp << 'EOF'
#!/bin/bash
# Cursor Indexing MCP Server Wrapper
# Connects to the HTTP server running on localhost:8000

# Check if server is running
if ! lsof -i :8000 > /dev/null; then
    echo "Error: Cursor Indexing server is not running on port 8000"
    echo "Start it with: cd agent_tools/cursor-local-indexing && ./run_mcp_server.sh"
    exit 1
fi

# Proxy to the HTTP server
exec curl -s http://localhost:8000/
EOF

# Create CodeGraph wrapper
cat > ~/mcp_wrappers/codegraph-mcp << 'EOF'
#!/bin/bash
# CodeGraph MCP Server Wrapper
# Connects to the HTTP server running on localhost:8080

# Check if server is running
if ! lsof -i :8080 > /dev/null; then
    echo "Error: CodeGraph server is not running on port 8080"
    echo "Start it with: cd ~/codegraph-mcp && source .venv/bin/activate && codegraph-mcp start --port 8080"
    exit 1
fi

# Proxy to the HTTP server
exec curl -s http://localhost:8080/
EOF

# Make wrappers executable
chmod +x ~/mcp_wrappers/cursor-indexing-mcp
chmod +x ~/mcp_wrappers/codegraph-mcp

echo "✅ MCP wrapper scripts created!"
echo "📋 Wrappers:"
echo "   - ~/mcp_wrappers/cursor-indexing-mcp"
echo "   - ~/mcp_wrappers/codegraph-mcp"
echo "\n🔄 Now updating Gemini CLI configuration..."

# Update Gemini CLI configuration
/usr/local/bin/python3.13 << 'PYTHON'
import json
from pathlib import Path

settings_path = Path.home() / ".gemini" / "settings.json"

with open(settings_path, 'r') as f:
    settings = json.load(f)

mcp_servers = settings.get("mcpServers", {})

# Remove old HTTP configurations
if "cursor-indexing" in mcp_servers:
    del mcp_servers["cursor-indexing"]
if "codegraph" in mcp_servers:
    del mcp_servers["codegraph"]

# Add command-based configurations
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

settings["mcpServers"] = mcp_servers

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)

print("✅ Gemini CLI configuration updated!")
PYTHON

echo ""
echo "🎉 Setup complete!"
echo "📋 Test the configuration:"
echo "   gemini mcp list"
echo "   gemini mcp enable cursor-indexing"
echo "   gemini mcp enable codegraph"