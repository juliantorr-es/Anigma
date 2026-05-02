#!/bin/bash
# Launch prototype with console logging visible

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Launching AnigmaPrototype with Console Logging ==="
echo ""
echo "Watch for these messages:"
echo "  ✅ Bundle identifier: com.anigma.prototype"
echo "  🔍 Refreshing status for project: ..."
echo "  🔧 Setting mode to ..."
echo "  ❌ Any errors"
echo ""
echo "Press Cmd+Q in the app to quit"
echo "================================================"
echo ""

# Launch via the canonical launcher and tail its output
"$SCRIPT_DIR/run_prototype.sh"

# Wait for app to start
sleep 2

# Show recent logs from the app
log stream --predicate 'process == "AnigmaPrototype"' --level debug --style compact
