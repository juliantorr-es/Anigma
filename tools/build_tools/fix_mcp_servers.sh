#!/bin/bash

echo "🔧 Fixing MCP Server Issues..."
echo ""

# 1. Stop all existing servers
echo "1️⃣ Stopping existing servers..."
pkill -f code_indexer_server.py 2>/dev/null
cd ~/codegraph-mcp && source .venv/bin/activate && codegraph-mcp stop 2>/dev/null
sleep 2

# 2. Restart Cursor Indexing
echo "2️⃣ Restarting Cursor Indexing server..."
cd agent_tools/cursor-local-indexing && nohup ./run_mcp_server.sh > server.log 2>&1 &
sleep 5

# 3. Check if Cursor Indexing is running
if lsof -i :8000 > /dev/null; then
    echo "✅ Cursor Indexing server running on port 8000"
else
    echo "❌ Cursor Indexing server failed to start"
    tail -10 agent_tools/cursor-local-indexing/server.log
fi

# 4. Restart CodeGraph
echo "3️⃣ Restarting CodeGraph server..."
cd ~/codegraph-mcp && source .venv/bin/activate && codegraph-mcp start --port 8080
sleep 5

# 5. Check if CodeGraph is running
if lsof -i :8080 > /dev/null; then
    echo "✅ CodeGraph server running on port 8080"
else
    echo "❌ CodeGraph server failed to start"
    tail -10 ~/.codegraph/server.log
fi

echo ""
echo "🎉 Server restart complete!"
echo ""
echo "📊 Final Status:"
ps aux | grep -E "code_indexer_server|codegraph" | grep -v grep