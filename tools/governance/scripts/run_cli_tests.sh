#!/bin/bash
#
# run_cli_tests.sh
# Run harmonia CLI test suite
#

set -e

echo "🧪 Running harmonia tests..."
echo ""

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    echo "❌ Error: Must run from repository root"
    exit 1
fi

# Build first
echo "📦 Building harmonia..."
swift build --package-path . --product harmonia
echo ""

# Run unit tests
echo "🔬 Running unit tests..."
swift test --filter AnigmaCLITests
TEST_EXIT_CODE=$?

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✅ All tests passed!"
else
    echo ""
    echo "❌ Some tests failed (exit code: $TEST_EXIT_CODE)"
    exit $TEST_EXIT_CODE
fi

# Run integration tests
echo ""
echo "🔗 Running integration tests..."
swift test --filter CLIIntegrationTests
INTEGRATION_EXIT_CODE=$?

if [ $INTEGRATION_EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✅ Integration tests passed!"
else
    echo ""
    echo "❌ Integration tests failed (exit code: $INTEGRATION_EXIT_CODE)"
    exit $INTEGRATION_EXIT_CODE
fi

echo ""
echo "═══════════════════════════════════════"
echo "🎉 All tests passed successfully!"
echo "═══════════════════════════════════════"
