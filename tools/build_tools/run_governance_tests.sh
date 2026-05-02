#!/bin/bash
#
# Run governance harness tests in isolation (fast, no HarmoniaModule build)
#
# Usage:
#   ./run_governance_tests.sh           # Run all tests
#   ./run_governance_tests.sh -v        # Verbose output
#

set -e

cd "$(dirname "$0")/Tests/GovernanceHarness"

echo "================================================"
echo "Governance Harness Tests (Isolated Build)"
echo "================================================"
echo ""
echo "Building harness (should be <10s)..."
echo ""

# Run tests with timing
if [ "$1" = "-v" ]; then
    time swift test -v
else
    time swift test
fi

echo ""
echo "================================================"
echo "Tests Complete"
echo "================================================"
