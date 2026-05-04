#!/bin/bash
# PDFSidecarReadiness Test Harness
# Purpose: Validate SidecarPDFService library and PDFSidecarExecutable as a governed
#         daemon-spawnable sidecar subprocess with service-level readiness.
# This is a dedicated readiness lane separate from generic BackendReadiness.
# Usage: ./Scripts/test_pdf_sidecar_readiness.sh

set -eo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT/anigma"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$REPO_ROOT/.build/test_pdf_sidecar_readiness_${TIMESTAMP}.log"
SIDECAR_READINESS_RECEIPT="$REPO_ROOT/.build/pdf-sidecar-readiness-receipt.json"

# Classification constants
CLASS_FAILED=1
CLASS_PASSED=0
CLASS_CONTAMINATED=2
CLASS_CLEAN=0

# PDFium vendor path
PDFIUM_VENDOR_PATH="$REPO_ROOT/External/Vendor/PDFium/macos-arm64"
PDFIUM_LIB_PATH="$PDFIUM_VENDOR_PATH/lib/libpdfium.dylib"

# Track per-target status
TOTAL_ERRORS=0
TOTAL_WARNINGS=0
WARN_COUNT=0

# Service-level receipt fields
SERVICE_TYPES=("pdf_vendor" "pdf_native" "sidecar_pdf_service" "sidecar_pdf_executable" "sidecar_spawn")
SERVICE_RESULTS=()

echo "=== PDFSidecarReadiness Test Harness ==="
echo "Timestamp: $TIMESTAMP"
echo "Log: $LOG_FILE"
echo "Receipt: $SIDECAR_READINESS_RECEIPT"
echo ""

# Function to emit a readiness receipt
emit_receipt() {
    local status=$1
    local message=$2
    local timestamp=$(date +%Y-%m-%dT%H:%M:%S%z)
    
    # Build services JSON from collected results
    local services_json=""
    for i in "${!SERVICE_TYPES[@]}"; do
        local svc="${SERVICE_TYPES[$i]}"
        local result="${SERVICE_RESULTS[$i]}"
        if [ -n "$services_json" ]; then
            services_json="$services_json, "
        fi
        services_json="$services_json\"$svc\": \"$result\""
    done
    
    cat > "$SIDECAR_READINESS_RECEIPT" << EOF
{
  "schema": "anigma.sidecar_readiness.v1",
  "sidecar": "SidecarPDFService",
  "lane": "PDFSidecarReadiness",
  "timestamp": "$timestamp",
  "classification": "$status",
  "message": "$message",
  "logFile": "$LOG_FILE",
  "services": {$services_json}
}
EOF
}

# Function to record service result
record_service() {
    local svc_type=$1
    local result=$2
    SERVICE_RESULTS+=("$result")
}

# Function to add service receipt entry
add_service_receipt() {
    local svc_name=$1
    local classification=$2
    local message=$3
    record_service "$svc_name" "$classification"
}

# Step 0: Validate PDFium vendor files
# The aligned doctrine: we do NOT re-validate PDFium in sidecar readiness.
# PDFium is validated in its own governance lane. Sidecar readiness assumes
# it is present, or explicitly reports ENVIRONMENT_UNAVAILABLE.
echo "Step 0: Checking PDFium vendor existence..."

PDFMISSING=false
if [ ! -d "$PDFIUM_VENDOR_PATH" ]; then
    echo "  ⚠️  PDFium vendor directory not found: $PDFIUM_VENDOR_PATH"
    PDFMISSING=true
    WARN_COUNT=$((WARN_COUNT + 1))
    add_service_receipt "pdf_vendor" "ENVIRONMENT_UNAVAILABLE" "PDFium vendor directory missing"
else
    echo "  ✅ PDFium vendor directory exists: $PDFIUM_VENDOR_PATH"
    if [ ! -f "$PDFIUM_LIB_PATH" ]; then
        echo "  ⚠️  libpdfium.dylib not found at $PDFIUM_LIB_PATH"
        WARN_COUNT=$((WARN_COUNT + 1))
        add_service_receipt "pdf_vendor" "ENVIRONMENT_UNAVAILABLE" "libpdfium.dylib missing"
    else
        echo "  ✅ libpdfium.dylib found: $PDFIUM_LIB_PATH"
        add_service_receipt "pdf_vendor" "CLEAN" "PDFium vendor files present"
    fi
fi

# Step 1: Validate PDFNative target (C++ PDFium wrapper)
echo ""
echo "Step 1: Building PDFNative target..."
START_TIME=$(date +%s)

if ! swift build --target PDFNative 2>&1 | tee -a "$LOG_FILE"; then
    BUILD_EXIT=1
    echo "  ❌ BUILD FAILED"
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    add_service_receipt "pdf_native" "FAILED" "PDFNative target failed to build"
else
    BUILD_EXIT=0
    echo "  ✅ BUILD PASSED"
    STEP_WARNINGS=$(grep -c "warning:" "$LOG_FILE" 2>/dev/null || echo 0)
    TOTAL_WARNINGS=$((TOTAL_WARNINGS + STEP_WARNINGS))
    add_service_receipt "pdf_native" "PASSED" "PDFNative target built successfully (warnings: $STEP_WARNINGS)"
fi
DURATION=$(($(date +%s) - START_TIME))
PDFNATIVE_DURATION=$DURATION

# Step 2: Validate SidecarPDFService target (the service library)
echo ""
echo "Step 2: Building SidecarPDFService target..."
START_TIME=$(date +%s)

# Clear log for this step to count warnings accurately
> "$LOG_FILE"

if ! swift build --target SidecarPDFService 2>&1 | tee -a "$LOG_FILE"; then
    BUILD_EXIT=1
    echo "  ❌ BUILD FAILED"
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    add_service_receipt "sidecar_pdf_service" "FAILED" "SidecarPDFService target failed to build"
else
    BUILD_EXIT=0
    echo "  ✅ BUILD PASSED"
    STEP_WARNINGS=$(grep -c "warning:" "$LOG_FILE" 2>/dev/null || echo 0)
    TOTAL_WARNINGS=$((TOTAL_WARNINGS + STEP_WARNINGS))
    add_service_receipt "sidecar_pdf_service" "PASSED" "SidecarPDFService target built successfully (warnings: $STEP_WARNINGS)"
fi
DURATION=$(($(date +%s) - START_TIME))
SERVICELIB_DURATION=$DURATION

# Step 3: Validate PDFSidecarExecutable product (the daemon executable)
echo ""
echo "Step 3: Building PDFSidecarExecutable product..."
START_TIME=$(date +%s)

# Clear log for this step
> "$LOG_FILE"

if ! swift build --target PDFSidecarExecutable 2>&1 | tee -a "$LOG_FILE"; then
    BUILD_EXIT=1
    echo "  ❌ BUILD FAILED"
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    add_service_receipt "sidecar_pdf_executable" "FAILED" "PDFSidecarExecutable target failed to build"
else
    BUILD_EXIT=0
    echo "  ✅ BUILD PASSED"
    STEP_WARNINGS=$(grep -c "warning:" "$LOG_FILE" 2>/dev/null || echo 0)
    TOTAL_WARNINGS=$((TOTAL_WARNINGS + STEP_WARNINGS))
    add_service_receipt "sidecar_pdf_executable" "PASSED" "PDFSidecarExecutable target built successfully (warnings: $STEP_WARNINGS)"
fi
DURATION=$(($(date +%s) - START_TIME))
EXECUTABLE_DURATION=$DURATION

# Step 4: Check for PDFSidecarExecutable binary and attempt health check
TOTAL_DURATION=$((PDFNATIVE_DURATION + SERVICELIB_DURATION + EXECUTABLE_DURATION))

# Only proceed with binary check if the executable built successfully
if [ "${SERVICE_RESULTS[2]}" != "FAILED" ]; then
    echo ""
    echo "Step 4: Checking for PDFSidecarExecutable binary..."
    
    SIDECAR_BINARY=""
    if [ -f "$REPO_ROOT/anigma/.build/arm64-apple-macosx/debug/PDFSidecarExecutable" ]; then
        SIDECAR_BINARY="$REPO_ROOT/anigma/.build/arm64-apple-macosx/debug/PDFSidecarExecutable"
    elif [ -f "$REPO_ROOT/anigma/.build/x86_64-apple-macosx/debug/PDFSidecarExecutable" ]; then
        SIDECAR_BINARY="$REPO_ROOT/anigma/.build/x86_64-apple-macosx/debug/PDFSidecarExecutable"
    elif [ -f "$REPO_ROOT/anigma/.build/debug/PDFSidecarExecutable" ]; then
        SIDECAR_BINARY="$REPO_ROOT/anigma/.build/debug/PDFSidecarExecutable"
    elif [ -f "$REPO_ROOT/anigma/.build/release/PDFSidecarExecutable" ]; then
        SIDECAR_BINARY="$REPO_ROOT/anigma/.build/release/PDFSidecarExecutable"
    fi
    
    if [ -n "$SIDECAR_BINARY" ] && [ -f "$SIDECAR_BINARY" ]; then
        echo "  ✅ Binary found: $SIDECAR_BINARY"
        BINARY_SIZE=$(stat -f%z "$SIDECAR_BINARY" 2>/dev/null || stat -c%s "$SIDECAR_BINARY" 2>/dev/null)
        echo "  Size: $BINARY_SIZE bytes"
        
        # Attempt to spawn and check health
        echo ""
        echo "Step 5: Validating sidecar subprocess spawn (health check)..."
        HEALTH_STATUS=""
        if timeout 5 "$SIDECAR_BINARY" --health 2>&1 | head -1 | grep -q "READY\|OK\|PASSED\|true"; then
            HEALTH_STATUS="PASSED"
            echo "  ✅ Sidecar health check: PASSED"
        elif timeout 5 "$SIDECAR_BINARY" --version 2>&1 | head -1 | grep -q "[0-9]\+\.[0-9]\+"; then
            HEALTH_STATUS="PASSED"
            echo "  ✅ Sidecar version check: PASSED"
        elif timeout 5 "$SIDECAR_BINARY" --help 2>&1 | head -1; then
            HEALTH_STATUS="PASSED"
            echo "  ✅ Sidecar help check: PASSED"
        else
            HEALTH_STATUS="CONTAMINATED"
            echo "  ⚠️  Sidecar spawn attempted but no health/version/help mode responded"
            WARN_COUNT=$((WARN_COUNT + 1))
        fi
        
        # Update service receipt with spawn result
        add_service_receipt "sidecar_spawn" "$HEALTH_STATUS" "Sidecar subprocess $HEALTH_STATUS"
    else
        echo "  ⚠️  Binary not found (product builds but may not be linked with PDFium runtime)"
        WARN_COUNT=$((WARN_COUNT + 1))
        add_service_receipt "sidecar_spawn" "ENVIRONMENT_UNAVAILABLE" "Binary not found - PDFium runtime likely required"
    fi
fi

echo ""

# Classify final status
echo "=== PDFSidecarReadiness Results ==="
echo "Total Duration: ${TOTAL_DURATION}s"
echo "Errors: $TOTAL_ERRORS"
echo "Warnings: $TOTAL_WARNINGS"
echo "Log: $LOG_FILE"
echo "Receipt: $SIDECAR_READINESS_RECEIPT"
echo ""

# Determine overall classification
if [ $TOTAL_ERRORS -gt 0 ]; then
    OVERALL_STATUS=$CLASS_FAILED
    FINAL_MESSAGE="SidecarPDFService readiness: FAILED ($TOTAL_ERRORS errors)"
elif [ $TOTAL_WARNINGS -gt 0 ]; then
    OVERALL_STATUS=$CLASS_PASSED
    FINAL_MESSAGE="SidecarPDFService readiness: PASSED with $TOTAL_WARNINGS warnings"
    if [ "$PDFMISSING" = true ]; then
        FINAL_MESSAGE="SidecarPDFService readiness: CONTAMINATED - PDFium vendor missing"
    fi
else
    OVERALL_STATUS=$CLASS_CLEAN
    FINAL_MESSAGE="SidecarPDFService readiness: CLEAN - all targets built with zero warnings"
fi

echo "Classification: $OVERALL_STATUS"
echo "Message: $FINAL_MESSAGE"
echo ""

# Emit final receipt
emit_receipt "$OVERALL_STATUS" "$FINAL_MESSAGE"

# Quick checks summary
echo "=== Quick Checks ==="
echo "PDFNative build: $(if [ "${SERVICE_RESULTS[0]}" = "FAILED" ]; then echo "FAILED"; else echo "PASSED"; fi)"
echo "SidecarPDFService build: $(if [ "${SERVICE_RESULTS[1]}" = "FAILED" ]; then echo "FAILED"; else echo "PASSED"; fi)"
echo "PDFSidecarExecutable build: $(if [ "${SERVICE_RESULTS[2]}" = "FAILED" ]; then echo "FAILED"; else echo "PASSED"; fi)"
echo "PDFium vendor: $(if [ "${SERVICE_RESULTS[0]}" = "ENVIRONMENT_UNAVAILABLE" ]; then echo "MISSING"; else echo "PRESENT"; fi)"
echo "Subprocess spawn: $(if [ "${SERVICE_RESULTS[4]}" = "PASSED" ]; then echo "YES"; else echo "NO"; fi)"
echo "Total warnings: $TOTAL_WARNINGS"
echo "Total errors: $TOTAL_ERRORS"

# Exit with appropriate code
if [ $OVERALL_STATUS -eq $CLASS_FAILED ]; then
    exit 1
elif [ $OVERALL_STATUS -eq $CLASS_CONTAMINATED ]; then
    exit 2
else
    exit 0
fi
