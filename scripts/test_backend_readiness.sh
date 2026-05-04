#!/bin/bash
# Minimal BackendReadiness test harness
# Purpose: Provide fast feedback loop for BackendReadiness test execution
# Usage: ./Scripts/test_backend_readiness.sh [test_filter]

set -eo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT/anigma"

TEST_FILTER="${1:-BackendReadinessContractTests}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$REPO_ROOT/.build/test_backend_readiness_${TIMESTAMP}.log"

echo "=== BackendReadiness Test Harness ==="
echo "Test: $TEST_FILTER"
echo "Log: $LOG_FILE"
echo "Timestamp: $TIMESTAMP"
echo ""

# Run the test with timing
echo "Running test..."
START_TIME=$(date +%s)

# Build only the specific test target
swift build --target "$TEST_FILTER" 2>&1 | tee "$LOG_FILE"
# Then run the test
# Note: PDFSidecarExecutable is excluded from generic BackendReadiness because it is
# validated by PDFSidecarReadiness as a governed daemon-spawnable sidecar.
# See: Scripts/test_pdf_sidecar_readiness.sh
# See: Docs/td/hypotheses/td-7c0153/td-7c0153-root-cause-classification.md
# The --skip flag is retained until PDFSidecarReadiness lane proves stable.
swift test --filter "$TEST_FILTER" --skip PDFSidecarExecutable 2>&1 | tee -a "$LOG_FILE"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=== Results ==="
echo "Duration: ${DURATION}s"
echo "Log: $LOG_FILE"
echo ""

# Analyze results
if grep -q "BUILD FAILED\|Compilation failed\|error:" "$LOG_FILE"; then
    echo "❌ BUILD/COMPILATION FAILED"
    echo ""
    echo "Compilation errors:"
    grep -E "error:|FAILED" "$LOG_FILE" | head -10
elif grep -q "ld: library 'pdfium' not found" "$LOG_FILE"; then
    echo "❌ PDFIUM LINKER ERROR (should not occur after isolation)"
    echo "This indicates pdfium isolation may have regressed"
elif grep -q "Test Suite .* passed" "$LOG_FILE"; then
    echo "✅ TESTS PASSED"
else
    echo "⚠️  UNCLEAR RESULT"
    echo "Check log file for details: $LOG_FILE"
fi

echo ""
echo "=== Quick Checks ==="
echo "PDFium errors: $(grep -c "pdfium" "$LOG_FILE")"
echo "Compilation errors: $(grep -c "error:" "$LOG_FILE" || true)"
echo "Test failures: $(grep -c "FAILED" "$LOG_FILE" || true)"

echo ""
echo "Done."