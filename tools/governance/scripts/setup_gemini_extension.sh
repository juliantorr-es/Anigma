#!/bin/bash
set -e

# Setup script for Gemini Extension
# 1. Builds the daemon-backed MCP binary (anigmad)
# 2. Extracts MCP tool definitions
# 3. Converts them to Gemini format

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Building anigmad..."
cd "$REPO_ROOT"
swift build -c release --product anigmad

echo "Extracting tools..."
# Find the binary
BINARY=".build/release/anigmad"
if [ ! -f "$BINARY" ]; then
    BINARY=$(find .build -name anigmad -type f | head -n 1)
fi

echo "Using binary: $BINARY"
echo '{"jsonrpc": "2.0", "method": "tools/list", "id": 1, "params": {}}' | "$BINARY" --mcp | grep '^{"id":1' > mcp_tools_raw.json

echo "Converting to Gemini format..."
python3 Scripts/generate_gemini_tools.py > gemini_tools.json

echo "Cleaning up..."
rm mcp_tools_raw.json

echo "Done! Gemini tools are ready in gemini_tools.json"
echo "Instructions: See GEMINI_EXTENSION.md"
