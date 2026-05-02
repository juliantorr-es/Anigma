#!/bin/bash
#
# check_stubs.sh - Run stub guardrail tests
#
# This script runs the automated stub detection tests that prevent
# silent stubs from being added to the codebase.
#
# Usage:
#   ./check_stubs.sh              # Run both tests
#   ./check_stubs.sh silent       # Run only silent stub detection
#   ./check_stubs.sh tracked      # Run only tracking detection
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/Tests/GovernanceHarness"
GUARDRAIL_TEST_FILE="$TEST_DIR/Tests/GovernanceTests/StubGuardrailTests.swift"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🛡️  Running Stub Guardrail Tests..."
echo ""

validate_required_guardrail_tests() {
    local missing=0
    local required_tests=("testNoSilentStubs" "testLoudStubsAreTracked")

    if [ ! -f "$GUARDRAIL_TEST_FILE" ]; then
        echo -e "${RED}❌ Missing guardrail test file:${NC} $GUARDRAIL_TEST_FILE"
        return 1
    fi

    for test_name in "${required_tests[@]}"; do
        if ! grep -q "func $test_name" "$GUARDRAIL_TEST_FILE"; then
            echo -e "${RED}❌ Missing required guardrail test:${NC} $test_name"
            missing=1
        fi
    done

    if [ $missing -ne 0 ]; then
        echo ""
        echo "Guardrail gate is incomplete. Restore required stub tests before merge."
        return 1
    fi
}

run_guardrail_test() {
    local filter="$1"
    if swift test --filter "$filter"; then
        return 0
    fi
    return 1
}

validate_required_guardrail_tests

cd "$TEST_DIR"
exit_code=0

case "${1:-all}" in
    silent)
        echo "📋 Checking for silent stubs..."
        run_guardrail_test testNoSilentStubs || exit_code=1
        ;;
    tracked)
        echo "📋 Checking for untracked loud stubs..."
        run_guardrail_test testLoudStubsAreTracked || exit_code=1
        ;;
    all)
        echo "📋 Running all stub guardrail tests..."
        run_guardrail_test testNoSilentStubs || exit_code=1
        run_guardrail_test testLoudStubsAreTracked || exit_code=1
        ;;
    *)
        echo -e "${YELLOW}Usage:${NC} ./check_stubs.sh [all|silent|tracked]"
        exit 2
        ;;
esac

echo ""
if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}✅ All stub guardrails passed!${NC}"
    echo ""
    echo "No silent stubs detected."
    echo "All loud stubs are properly tracked."
else
    echo -e "${RED}❌ Stub guardrail violations detected!${NC}"
    echo ""
    echo "See test output above for specific file:line locations."
    echo "Refer to STUB_GUARDRAILS.md for remediation steps."
fi

exit $exit_code
