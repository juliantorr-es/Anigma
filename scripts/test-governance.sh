#!/bin/bash
# Test governance invariants in isolated harness
# Fast execution (4-6s build, 0.004s tests) with zero Harmonia dependency

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HARNESS_DIR="$REPO_ROOT/Tests/GovernanceHarness"

echo "🔒 Running governance tests..."

cd "$HARNESS_DIR"
swift test --parallel

echo "✅ All governance tests passed"
