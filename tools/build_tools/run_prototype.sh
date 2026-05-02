#!/bin/bash
set -e

# Canonical launcher for the Phase 3 prototype.

echo "=== Phase 3 Prototype Quick Launch ==="
echo ""

echo "1. Building .app bundle..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/build_app_bundle.sh"

echo ""
echo "2. Database:"
echo "   PostgreSQL (host: localhost, db: anigma_v3)"
echo ""

echo "3. Launching app..."
open "$SCRIPT_DIR/anigma/.build/debug/AnigmaPrototype.app"

echo ""
echo "✅ App launched!"
echo ""
echo "Next: Run smoke test from PHASE3_SMOKE_TEST.md"
echo ""
