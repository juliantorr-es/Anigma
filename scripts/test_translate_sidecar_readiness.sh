#!/bin/bash
# TranslateSidecarReadiness Test Harness
# Purpose: Validate SidecarTranslateService library target builds successfully.
# Note: Current implementation is a stub; readiness = build validation only.
# This is a dedicated readiness lane separate from generic BackendReadiness.
# Usage: ./Scripts/test_translate_sidecar_readiness.sh

set -eo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT/anigma"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$REPO_ROOT/.build/test_translate_sidecar_readiness_${TIMESTAMP}.log"
READINESS_RECEIPT="$REPO_ROOT/.build/translate-sidecar-readiness-receipt.json"

# Classification constants
CLASS_FAILED=1
CLASS_CLEAN=0

echo "=== TranslateSidecarReadiness Test Harness ==="
echo "Timestamp: $TIMESTAMP"
echo "Log: $LOG_FILE"
echo "Receipt: $READINESS_RECEIPT"
echo ""

# Step 1: Build SidecarTranslateService target
echo "Step 1: Building SidecarTranslateService target..."
START_TIME=$(date +%s)

if ! swift build --target SidecarTranslateService 2>&1 | tee -a "$LOG_FILE"; then
    BUILD_EXIT=1
    echo "  ❌ BUILD FAILED"
    FINAL_MESSAGE="SidecarTranslateService: build failed"
    CLASSIFICATION="FAILED"
else
    BUILD_EXIT=0
    DURATION=$(($(date +%s) - START_TIME))
    echo "  ✅ BUILD PASSED ($DURATION)s"
    FINAL_MESSAGE="SidecarTranslateService: build passed"
    CLASSIFICATION="CLEAN"
fi

# Count warnings and errors
WARNING_COUNT=$(grep -c "warning:" "$LOG_FILE" 2>/dev/null || echo 0)
ERROR_COUNT=$(grep -c "error:" "$LOG_FILE" 2>/dev/null || echo 0)

# Adjust classification based on warnings/errors
echo ""
echo "=== TranslateSidecarReadiness Results ==="
echo "Duration: ${DURATION}s"
echo "Warnings: $WARNING_COUNT"
echo "Errors: $ERROR_COUNT"
echo "Log: $LOG_FILE"
echo "Receipt: $READINESS_RECEIPT"
echo ""

if [ $BUILD_EXIT -ne 0 ] || [ $ERROR_COUNT -gt 0 ]; then
    CLASSIFICATION="FAILED"
    FINAL_MESSAGE="SidecarTranslateService: build failed (exit=$BUILD_EXIT errors=$ERROR_COUNT)"
elif [ $WARNING_COUNT -gt 0 ]; then
    CLASSIFICATION="PASSED"
    FINAL_MESSAGE="SidecarTranslateService: build passed with $WARNING_COUNT warnings"
else
    CLASSIFICATION="CLEAN"
    FINAL_MESSAGE="SidecarTranslateService: build passed with zero warnings"
fi

echo "Classification: $CLASSIFICATION"
echo "Message: $FINAL_MESSAGE"
echo ""

# Emit receipt
TIMESTAMP_ISO=$(date +%Y-%m-%dT%H:%M:%S%z)
cat > "$READINESS_RECEIPT" << EOF
{
  "schema": "anigma.sidecar_readiness.v1",
  "sidecar": "SidecarTranslateService",
  "lane": "TranslateSidecarReadiness",
  "timestamp": "$TIMESTAMP_ISO",
  "classification": "$CLASSIFICATION",
  "message": "$FINAL_MESSAGE",
  "logFile": "$LOG_FILE",
  "buildTarget": "SidecarTranslateService",
  "buildDuration": $DURATION,
  "warningCount": $WARNING_COUNT,
  "errorCount": $ERROR_COUNT
}
EOF

echo "=== Quick Checks ==="
echo "Build exit: $BUILD_EXIT"
echo "Warnings: $WARNING_COUNT"
echo "Errors: $ERROR_COUNT"
echo "Classification: $CLASSIFICATION"

# Exit with appropriate code
if [ "$CLASSIFICATION" = "FAILED" ]; then
    exit 1
else
    exit 0
fi
