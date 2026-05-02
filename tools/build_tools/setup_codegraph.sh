#!/bin/bash

echo "🚀 Setting up CodeGraph MCP Server..."

# Create directory for CodeGraph
mkdir -p ~/codegraph-mcp
cd ~/codegraph-mcp

# Check if repository already exists
if [ -d ".git" ]; then
    echo "⚠️  Repository already exists, pulling latest changes..."
    git pull origin main
else
    echo "📦 Cloning CodeGraph MCP Server repository..."
    git clone https://github.com/nahisaho/CodeGraphMCPServer.git .
fi

echo "🐍 Setting up Python virtual environment..."
python3.13 -m venv .venv
source .venv/bin/activate

echo "🔧 Installing dependencies..."
pip install --upgrade pip
pip install -e ".[dev]"

echo "✅ CodeGraph MCP Server setup complete!"
echo ""
echo "📝 Next steps:"
echo "1. Index your codebase: codegraph-mcp index /Users/user/Developer/GitHub/Anigma_clean --full"
echo "2. Start the server: codegraph-mcp start --port 8080"
echo "3. Configure your MCP client to connect to http://localhost:8080"

echo "💡 To activate the virtual environment later:"
echo "   source ~/codegraph-mcp/.venv/bin/activate"