#!/usr/bin/env bash
# Scripts/ci/check-concurrency.sh
# Swift 6 Strict Concurrency Enforcement Tool

set -euo pipefail

# --- Configuration ---
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_FILE="${PROJECT_ROOT}/concurrency_build.log"

echo -e "${BOLD}${BLUE}================================================================================${NC}"
echo -e "${BOLD}${BLUE} ANIGMA CONCURRENCY CONTRACT ENFORCEMENT${NC}"
echo -e "${BOLD}${BLUE}================================================================================${NC}"

# 1. Build Phase
echo -e "🚀 ${BOLD}Building with -strict-concurrency=complete...${NC}"
cd "${PROJECT_ROOT}"

# Run build and capture output
if swift build -Xswiftc -strict-concurrency=complete > "${LOG_FILE}" 2>&1; then
    echo -e "✅ ${GREEN}Build successful with strict concurrency checks.${NC}"
else
    echo -e "❌ ${RED}Concurrency build failed or found violations.${NC}"
    echo ""
    echo -e "${BOLD}--- Violation Report ---${NC}"
    
    # Advanced parsing of the compiler output
    # Group by file and show the specific Sendable/Concurrency issue
    grep -E "warning:|error:" "${LOG_FILE}" | \
    grep -E "concurrency|Sendable|isolated|actor|data race" | \
    sed "s|\(.*\):\([0-9]*\):\([0-9]*\): \(.*\): \(.*\)|\1 (Line \2): [\4] \5|" | \
    while read -r report; do
        if [[ $report == *"[error]"* ]]; then
            echo -e "  ${RED}• ${report}${NC}"
        else
            echo -e "  ${YELLOW}• ${report}${NC}"
        fi
    done | head -n 30

    echo ""
    echo -e "${BOLD}Recommended Actions:${NC}"
    echo -e "  1. Ensure all types passed across actor boundaries are ${BOLD}Sendable${NC}."
    echo -e "  2. Use ${BOLD}actor${NC} or ${BOLD}global actors (@MainActor)${NC} for shared state."
    echo -e "  3. Use ${BOLD}nonisolated(unsafe)${NC} only as a last resort for legacy C-library integration."
    echo ""
    echo -e "See full log for details: ${BOLD}${LOG_FILE}${NC}"
    exit 1
fi

# 2. TSan Phase (Optional)
if [[ "${1:-}" == "--tsan" ]]; then
    echo ""
    echo -e "🔍 ${BOLD}Running Thread Sanitizer (Runtime Data Race Detection)...${NC}"
    if swift test --sanitize=thread > tsan_results.log 2>&1; then
        echo -e "✅ ${GREEN}No runtime data races detected.${NC}"
    else
        echo -e "❌ ${RED}Runtime data races DETECTED!${NC}"
        grep -A 10 "ThreadSanitizer:" tsan_results.log || true
        exit 1
    fi
fi

echo ""
echo -e "🏁 ${BOLD}Concurrency Check Complete.${NC}"
exit 0