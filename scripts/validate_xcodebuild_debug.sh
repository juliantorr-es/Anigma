#!/bin/bash
set -euo pipefail

# validate_xcodebuild_debug.sh
# Canonical Xcode Debug build validation lane for Anigma's macOS/native integration work.
#
# Usage:
#   bash scripts/validate_xcodebuild_debug.sh [--scheme <scheme>] [--test] [--dry-run]
#
# Default scheme: anigma-app (macOS app target)
# Alternative schemes: anigmad, AnigmaDaemonSimple, AnigmaPipeline, AnigmaCore
#
# Doctrine:
# - xcodebuild Debug is the product/runtime build lane for macOS.Apple-framework-heavy work
# - SwiftPM describe + validators remain the architecture graph lane
# - swift build remains useful but is not the only truth for the macOS app lane

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

WORKSPACE_PATH="${REPO_ROOT}/anigma/.swiftpm/xcode/package.xcworkspace"
DERIVED_DATA_PATH="${REPO_ROOT}/.build/xcode-derived-data"
LOG_DIR="${REPO_ROOT}/.build/logs"
LOG_FILE="${LOG_DIR}/xcodebuild-debug.log"

SCHEME="anigma-app"
RUN_TESTS=false
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --scheme)
            SCHEME="$2"
            shift 2
            ;;
        --test)
            RUN_TESTS=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Ensure directories exist
mkdir -p "${LOG_DIR}"

# Destination for macOS arm64
DESTINATION='platform=macOS,arch=arm64'

# Print configuration
echo "=== Xcode Debug Validation Lane ==="
echo "Repo root: ${REPO_ROOT}"
echo "Workspace: ${WORKSPACE_PATH}"
echo "Scheme: ${SCHEME}"
echo "Configuration: Debug"
echo "Destination: ${DESTINATION}"
echo "DerivedData: ${DERIVED_DATA_PATH}"
echo "Log file: ${LOG_FILE}"
echo "Run tests: ${RUN_TESTS}"
echo "Dry run: ${DRY_RUN}"
echo ""

# Dry run: just print the command and exit
if [ "${DRY_RUN}" = true ]; then
    if [ "${RUN_TESTS}" = true ]; then
        echo "Would run:"
        echo "  cd ${REPO_ROOT} && xcodebuild -workspace ${WORKSPACE_PATH} -scheme ${SCHEME} -configuration Debug -destination '${DESTINATION}' -derivedDataPath ${DERIVED_DATA_PATH} test"
    else
        echo "Would run:"
        echo "  cd ${REPO_ROOT} && xcodebuild -workspace ${WORKSPACE_PATH} -scheme ${SCHEME} -configuration Debug -destination '${DESTINATION}' -derivedDataPath ${DERIVED_DATA_PATH} build"
    fi
    echo ""
    echo "To execute, run without --dry-run"
    exit 0
fi

# Build command
if [ "${RUN_TESTS}" = true ]; then
    ACTION="test"
else
    ACTION="build"
fi

echo "=== Executing: ${ACTION} ==="
echo "Command: cd ${REPO_ROOT} && xcodebuild -workspace ${WORKSPACE_PATH} -scheme ${SCHEME} -configuration Debug -destination '${DESTINATION}' -derivedDataPath ${DERIVED_DATA_PATH} ${ACTION}"
echo ""

# Run and log
cd "${REPO_ROOT}"
START_TIME=$(date +%s)
xcodebuild -workspace "${WORKSPACE_PATH}" -scheme "${SCHEME}" -configuration Debug -destination "${DESTINATION}" -derivedDataPath "${DERIVED_DATA_PATH}" ${ACTION} 2>&1 | tee "${LOG_FILE}"
EXIT_CODE=${PIPESTATUS[0]}
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "=== Results ==="
echo "Exit code: ${EXIT_CODE}"
echo "Duration: ${DURATION}s"
echo "Log file: ${LOG_FILE}"

if [ ${EXIT_CODE} -eq 0 ]; then
    echo "✅ PASS: xcodebuild Debug ${ACTION} succeeded"
else
    echo "❌ FAIL: xcodebuild Debug ${ACTION} failed (exit code ${EXIT_CODE})"
fi

echo ""
echo "=== Advisory: Dead Code Audit ==="
python3 "${REPO_ROOT}/scripts/anigma_dead_code_audit.py" --mode advisory --no-proof || true

echo ""
echo "=== Advisory: Executable Consolidation Audit ==="
python3 "${REPO_ROOT}/scripts/anigma_executable_consolidation_audit.py" --mode advisory --focus anigmad --no-proof || true

exit ${EXIT_CODE}
