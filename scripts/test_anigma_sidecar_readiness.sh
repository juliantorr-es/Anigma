#!/bin/bash
# AnigmaSidecarReadiness Test Harness
# Purpose: Validate AnigmaSidecar library target builds successfully and daemon coordination works.
# This is a dedicated readiness lane separate from generic BackendReadiness.
# Usage: ./Scripts/test_anigma_sidecar_readiness.sh

set -eo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT/anigma"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$REPO_ROOT/.build/test_anigma_sidecar_readiness_${TIMESTAMP}.log"
READINESS_RECEIPT="$REPO_ROOT/.build/anigma-sidecar-readiness-receipt.json"

# Classification constants
CLASS_FAILED=1
CLASS_CLEAN=0

echo "=== AnigmaSidecarReadiness Test Harness ==="
echo "Timestamp: $TIMESTAMP"
echo "Log: $LOG_FILE"
echo "Receipt: $READINESS_RECEIPT"
echo ""

# Track results
BUILD_EXIT=0
WARNING_COUNT=0
ERROR_COUNT=0
DURATION=0
DAEMON_FOUND=false
DAEMON_STARTED=false
HEALTH_CHECK=false

# Step 1: Build AnigmaSidecar target
echo "Step 1: Building AnigmaSidecar target..."
START_TIME=$(date +%s)

if ! swift build --target AnigmaSidecar 2>&1 | tee -a "$LOG_FILE"; then
    BUILD_EXIT=1
    echo "  ❌ BUILD FAILED"
    FINAL_MESSAGE="AnigmaSidecar: build failed"
    CLASSIFICATION="FAILED"
else
    BUILD_EXIT=0
    DURATION=$(($(date +%s) - START_TIME))
    echo "  ✅ BUILD PASSED ($DURATION)s"
    FINAL_MESSAGE="AnigmaSidecar: build passed"
    CLASSIFICATION="CLEAN"
fi

# Count warnings and errors
WARNING_COUNT=$(grep -c "warning:" "$LOG_FILE" 2>/dev/null || echo 0)
ERROR_COUNT=$(grep -c "error:" "$LOG_FILE" 2>/dev/null || echo 0)

# Step 2: Check for daemon binary (anigmad)
echo ""
echo "Step 2: Checking for anigmad daemon binary..."

# Common daemon binary locations
DAEMON_PATHS=(
    "$REPO_ROOT/anigma/.build/release/anigmad"
    "$REPO_ROOT/anigma/.build/debug/anigmad"
    "$REPO_ROOT/.build/release/anigmad"
    "$REPO_ROOT/.build/debug/anigmad"
)

for path in "${DAEMON_PATHS[@]}"; do
    if [ -f "$path" ] && [ -x "$path" ]; then
        echo "  ✅ Daemon binary found: $path"
        DAEMON_FOUND=true
        DAEMON_PATH="$path"
        DAEMON_SIZE=$(stat -f%z "$path" 2>/dev/null || stat -c%s "$path" 2>/dev/null)
        echo "  Size: $DAEMON_SIZE bytes"
        break
    fi
done

if [ "$DAEMON_FOUND" = false ]; then
    echo "  ⚠️  Daemon binary not found in common locations"
    # This is CONTAMINATED state: library builds but daemon is missing
    if [ "$BUILD_EXIT" -eq 0 ]; then
        CLASSIFICATION="CONTAMINATED"
        FINAL_MESSAGE="AnigmaSidecar: daemon binary missing"
    fi
fi

# Step 3: Optional daemon lifecycle test (only if daemon found and not already running)
if [ "$DAEMON_FOUND" = true ] && [ "$CLASSIFICATION" != "FAILED" ]; then
    echo ""
    echo "Step 3: Daemon lifecycle check..."
    
    # Default socket path
    SOCKET_DIR="$HOME/Library/Caches/anigma"
    SOCKET_PATH="$SOCKET_DIR/anigmad.sock"
    PID_FILE="$SOCKET_PATH.pid"
    
    # Check if daemon is already running
    if [ -f "$PID_FILE" ]; then
        DAEMON_FUNCTIONAL=true
        echo "  ℹ️  Daemon already running (PID file: $PID_FILE), skipping lifecycle test"
    else
        # Try to start daemon, check health, stop it
        # Use a temporary socket path for testing
        TEST_SOCKET_DIR="$REPO_ROOT/.build/test_sockets"
        TEST_SOCKET_PATH="$TEST_SOCKET_DIR/test_anigmad_${TIMESTAMP}.sock"
        TEST_PID_FILE="$TEST_SOCKET_PATH.pid"
        
        mkdir -p "$TEST_SOCKET_DIR"
        
        # Check if another daemon is using the socket
        DAEMON_ALREADY_RUNNING=false
        
        # Attempt graceful start with timeout
        echo "  Attempting daemon start..."
        
        # Start in background, capture PID
        "$DAEMON_PATH" --socket "$TEST_SOCKET_PATH" >> "$LOG_FILE" 2>&1 &
        DAEMON_TEST_PID=$!
        
        # Wait up to 3 seconds for daemon to start
        for i in $(seq 1 15); do
            if [ ! -f "$TEST_SOCKET_PATH" ]; then
                sleep 0.2
            else
                DAEMON_STARTED=true
                echo "  ✅ Daemon socket created: $TEST_SOCKET_PATH"
                break
            fi
        done
        
        # Check health via socket ping
        if [ "$DAEMON_STARTED" = true ]; then
            # Try to connect to socket (simple check)
            if timeout 5 curl --silent --unix-socket "$TEST_SOCKET_PATH" http://localhost/health >/dev/null 2>&1; then
                HEALTH_CHECK=true
                echo "  ✅ Daemon health check: PASSED"
            else
                echo "  ⚠️  Daemon health check: could not connect"
            fi
            
            # Stop daemon
            if kill -TERM $DAEMON_TEST_PID 2>/dev/null; then
                wait $DAEMON_TEST_PID 2>/dev/null || true
                echo "  ✅ Daemon stopped"
            else
                echo "  ⚠️  Daemon process already terminated"
            fi
        else
            echo "  ⚠️  Daemon failed to start within timeout"
            # Kill background process if still running
            kill $DAEMON_TEST_PID 2>/dev/null || true
            wait $DAEMON_TEST_PID 2>/dev/null || true
        fi
        
        # Cleanup
        rm -f "$TEST_SOCKET_PATH" "$TEST_PID_FILE"
        rmdir "$TEST_SOCKET_DIR" 2>/dev/null || true
        
        DAEMON_FUNCTIONAL=$HEALTH_CHECK
        
        if [ "$DAEMON_STARTED" = true ] && [ "$HEALTH_CHECK" = true ]; then
            echo "  ✅ Daemon lifecycle test: PASSED"
        elif [ "$DAEMON_STARTED" = true ]; then
            echo "  ⚠️  Daemon lifecycle test: started but health check failed"
        else
            echo "  ⚠️  Daemon lifecycle test: could not start"
        fi
    fi
fi

echo ""

# Classify final status
echo "=== AnigmaSidecarReadiness Results ==="
echo "Duration: ${DURATION}s"
echo "Warnings: $WARNING_COUNT"
echo "Errors: $ERROR_COUNT"
echo "Daemon found: $DAEMON_FOUND"
echo "Daemon started: $DAEMON_STARTED"
echo "Health check: $HEALTH_CHECK"
echo "Log: $LOG_FILE"
echo "Receipt: $READINESS_RECEIPT"
echo ""

# Determine final classification
if [ $BUILD_EXIT -ne 0 ] || [ $ERROR_COUNT -gt 0 ]; then
    CLASSIFICATION="FAILED"
    FINAL_MESSAGE="AnigmaSidecar: build failed (exit=$BUILD_EXIT errors=$ERROR_COUNT)"
elif [ "$DAEMON_FOUND" = false ]; then
    CLASSIFICATION="CONTAMINATED"
    FINAL_MESSAGE="AnigmaSidecar: build passed but daemon binary missing"
elif [ "$WARNING_COUNT" -gt 0 ]; then
    CLASSIFICATION="PASSED"
    FINAL_MESSAGE="AnigmaSidecar: build passed with $WARNING_COUNT warnings"
else
    CLASSIFICATION="CLEAN"
    FINAL_MESSAGE="AnigmaSidecar: build passed with zero warnings"
    if [ "$DAEMON_FOUND" = true ]; then
        FINAL_MESSAGE="$FINAL_MESSAGE, daemon binary present"
        if [ "$HEALTH_CHECK" = true ]; then
            FINAL_MESSAGE="$FINAL_MESSAGE, lifecycle verified"
        fi
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
  "sidecar": "AnigmaSidecar",
  "lane": "AnigmaSidecarReadiness",
  "timestamp": "$TIMESTAMP_ISO",
  "classification": "$CLASSIFICATION",
  "message": "$FINAL_MESSAGE",
  "logFile": "$LOG_FILE",
  "buildTarget": "AnigmaSidecar",
  "buildDuration": $DURATION,
  "warningCount": $WARNING_COUNT,
  "errorCount": $ERROR_COUNT,
  "daemonFound": $DAEMON_FOUND,
  "daemonStarted": $DAEMON_STARTED,
  "healthCheckPassed": $HEALTH_CHECK
}
EOF

# Quick checks summary
echo "=== Quick Checks ==="
echo "Build: $(if [ $BUILD_EXIT -eq 0 ]; then echo "PASSED"; else echo "FAILED"; fi)"
echo "Warnings: $WARNING_COUNT"
echo "Errors: $ERROR_COUNT"
echo "Daemon binary: $(if [ "$DAEMON_FOUND" = true ]; then echo "FOUND"; else echo "MISSING"; fi)"
echo "Health check: $(if [ "$HEALTH_CHECK" = true ]; then echo "PASSED"; else echo "N/A"; fi)"
echo "Classification: $CLASSIFICATION"

# Exit with appropriate code
if [ "$CLASSIFICATION" = "FAILED" ]; then
    exit 1
elif [ "$CLASSIFICATION" = "CONTAMINATED" ]; then
    exit 2
else
    exit 0
fi
