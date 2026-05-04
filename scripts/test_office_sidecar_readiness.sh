#!/bin/bash
# OfficeSidecarReadiness Test Harness
# Purpose: Validate SidecarOfficeService library target builds successfully.
# Note: Current implementation is a stub; readability = build validation only.
# LibreOfficeKit vendor is assumed in aligned doctrine (validated separately).
# This is a dedicated readiness lane separate from generic BackendReadiness.
# Usage: ./Scripts/test_office_sidecar_readiness.sh

set -eo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT/anigma"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$REPO_ROOT/.build/test_office_sidecar_readiness_${TIMESTAMP}.log"
READINESS_RECEIPT="$REPO_ROOT/.build/office-sidecar-readiness-receipt.json"

# LibreOfficeKit vendor path (aligned doctrine: validated in separate lane)
LIBREOFFICE_VENDOR_PATH="$REPO_ROOT/External/Vendor/LibreOfficeKit/macos-arm64"

# Classification constants
CLASS_FAILED=1
CLASS_CLEAN=0
CLASS_PASSED=0
CLASS_CONTAMINATED=2

echo "=== OfficeSidecarReadiness Test Harness ==="
echo "Timestamp: $TIMESTAMP"
echo "Log: $LOG_FILE"
echo "Receipt: $READINESS_RECEIPT"
echo ""

# Step 0: Check for LibreOfficeKit vendor (aligned doctrine: optional check)
# The aligned doctrine: we do NOT re-validate LibreOfficeKit in sidecar readiness.
# LibreOfficeKit is validated in its own governance lane. Sidecar readiness assumes
# it is present, or explicitly reports ENVIRONMENT_UNAVAILABLE.
echo "Step 0: Checking LibreOfficeKit vendor existence..."

OFFICEMISSING=false
if [ ! -d "$LIBREOFFICE_VENDOR_PATH" ]; then
    echo "  ⚠️  LibreOfficeKit vendor directory not found: $LIBREOFFICE_VENDOR_PATH"
    OFFICEMISSING=true
    VENDOR_STATUS="ENVIRONMENT_UNAVAILABLE"
else
    echo "  ✅ LibreOfficeKit vendor directory exists: $LIBREOFFICE_VENDOR_PATH"
    VENDOR_STATUS="CLEAN"
fi

# Step 1: Build SidecarOfficeService target
echo ""
echo "Step 1: Building SidecarOfficeService target..."
START_TIME=$(date +%s)

if ! swift build --target SidecarOfficeService 2>&1 | tee -a "$LOG_FILE"; then
    BUILD_EXIT=1
    echo "  ❌ BUILD FAILED"
    FINAL_MESSAGE="SidecarOfficeService: build failed"
    CLASSIFICATION="FAILED"
else
    BUILD_EXIT=0
    DURATION=$(($(date +%s) - START_TIME))
    echo "  ✅ BUILD PASSED ($DURATION)s"
    FINAL_MESSAGE="SidecarOfficeService: build passed"
    CLASSIFICATION="CLEAN"
fi

# Count warnings and errors
WARNING_COUNT=$(grep -c "warning:" "$LOG_FILE" 2>/dev/null || true)
WARNING_COUNT=${WARNING_COUNT:-0}
ERROR_COUNT=$(grep -c "error:" "$LOG_FILE" 2>/dev/null || true)
ERROR_COUNT=${ERROR_COUNT:-0}

# Adjust classification based on warnings/errors
echo ""
echo "=== OfficeSidecarReadiness Results ==="
echo "Duration: ${DURATION}s"
echo "Warnings: $WARNING_COUNT"
echo "Errors: $ERROR_COUNT"
echo "LibreOfficeKit vendor: $VENDOR_STATUS"
echo "Log: $LOG_FILE"
echo "Receipt: $READINESS_RECEIPT"
echo ""

if [ $BUILD_EXIT -ne 0 ] || [ $ERROR_COUNT -gt 0 ]; then
    CLASSIFICATION="FAILED"
    FINAL_MESSAGE="SidecarOfficeService: build failed (exit=$BUILD_EXIT errors=$ERROR_COUNT)"
elif [ $WARNING_COUNT -gt 0 ]; then
    CLASSIFICATION="PASSED"
    FINAL_MESSAGE="SidecarOfficeService: build passed with $WARNING_COUNT warnings"
    if [ "$OFFICEMISSING" = true ]; then
        CLASSIFICATION="CONTAMINATED"
        FINAL_MESSAGE="SidecarOfficeService: CONTAMINATED - LibreOfficeKit vendor missing ($WARNING_COUNT warnings)"
    fi
else
    CLASSIFICATION="CLEAN"
    FINAL_MESSAGE="SidecarOfficeService: build passed with zero warnings"
    if [ "$OFFICEMISSING" = true ]; then
        FINAL_MESSAGE="SidecarOfficeService: build passed with zero warnings (LibreOfficeKit vendor not required for stub)"
    fi
fi

echo "Classification: $CLASSIFICATION"
echo "Message: $FINAL_MESSAGE"
echo ""

# Emit receipt
TIMESTAMP_ISO=$(date +%Y-%m-%dT%H:%M:%S%z)
cat > "$READINESS_RECEIPT" << EOF
{
  "schema": "anigma.sidecar_readiness.v1",
  "sidecar": "SidecarOfficeService",
  "lane": "OfficeSidecarReadiness",
  "timestamp": "$TIMESTAMP_ISO",
  "classification": "$CLASSIFICATION",
  "message": "$FINAL_MESSAGE",
  "logFile": "$LOG_FILE",
  "buildTarget": "SidecarOfficeService",
  "buildDuration": ${DURATION:-0},
  "warningCount": $WARNING_COUNT,
  "errorCount": $ERROR_COUNT,
  "libreOfficeVendorStatus": "$VENDOR_STATUS",
  "libreOfficeVendorPath": "$LIBREOFFICE_VENDOR_PATH"
}
EOF

echo "=== Quick Checks ==="
echo "LibreOfficeKit vendor: $(if [ "$OFFICEMISSING" = true ]; then echo "MISSING"; else echo "PRESENT"; fi)"
echo "Build exit: $BUILD_EXIT"
echo "Warnings: $WARNING_COUNT"
echo "Errors: $ERROR_COUNT"
echo "Classification: $CLASSIFICATION"

# Exit with appropriate code
if [ "$CLASSIFICATION" = "FAILED" ]; then
    exit 1
elif [ "$CLASSIFICATION" = "CONTAMINATED" ]; then
    exit 2
else
    exit 0
fi
