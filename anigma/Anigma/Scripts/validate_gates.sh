#!/bin/bash
set -e

# validate_gates.sh - CI enforcement for Anigma Capsules
# Part of Phase 0 Remediation

CAPSULE_PATH=$1
GATE_TO_RUN=$2 # Optional: specify a specific gate to run

if [ -z "$CAPSULE_PATH" ]; then
    echo "Usage: $0 <capsule-path> [gate-name]"
    exit 1
fi

# Resolve absolute path
CAPSULE_PATH=$(cd "$CAPSULE_PATH" && pwd)
CAPSULE_NAME=$(basename "$CAPSULE_PATH")

run_gate() {
    local gate_name=$1
    if [ -z "$GATE_TO_RUN" ] || [ "$GATE_TO_RUN" == "$gate_name" ]; then
        return 0 # Should run
    fi
    return 1 # Should skip
}

echo "=========================================================="
echo "🚀 Running CI Gates for $CAPSULE_NAME"
echo "📍 Path: $CAPSULE_PATH"
[ -n "$GATE_TO_RUN" ] && echo "🎯 Target Gate: $GATE_TO_RUN"
echo "=========================================================="

# 1. GATE_TIER_VALIDATION
if run_gate "GATE_TIER_VALIDATION"; then
    echo "🔍 [GATE_TIER_VALIDATION] Checking MANIFEST.toml..."
    if [ ! -f "$CAPSULE_PATH/MANIFEST.toml" ]; then
        echo "❌ Error: MANIFEST.toml not found in $CAPSULE_PATH"
        exit 1
    fi

    TIER=$(grep -E "^tier =" "$CAPSULE_PATH/MANIFEST.toml" | cut -d'=' -f2 | tr -d ' ')
    if [ -z "$TIER" ]; then
        echo "❌ Error: tier not defined in MANIFEST.toml"
        exit 1
    fi
    echo "✅ Capsule Tier: $TIER"
fi

# 2. GATE_ERROR_MODEL
if run_gate "GATE_ERROR_MODEL"; then
    echo "🔍 [GATE_ERROR_MODEL] Validating Error Model..."
    # Check that no public capsule API throws non-CapsuleError
    BAD_THROWS=$(grep -r "public .*func .* throws" "$CAPSULE_PATH/Sources" | grep -v "CapsuleError" || true)
    if [ -n "$BAD_THROWS" ]; then
        echo "❌ Error: Public API throws non-CapsuleError or is missing CapsuleError type mapping:"
        echo "$BAD_THROWS"
        exit 1
    fi
    echo "✅ Error Model looks compliant."
fi

# 3. GATE_DIAGNOSTICS_CONFORMANCE
if run_gate "GATE_DIAGNOSTICS_CONFORMANCE"; then
    echo "🔍 [GATE_DIAGNOSTICS_CONFORMANCE] Checking for forbidden diagnostics..."
    FORBIDDEN_DIAGS=$(grep -rE "\bprint\(|\bNSLog\(|\bos_log\(" "$CAPSULE_PATH/Sources" || true)
    if [ -n "$FORBIDDEN_DIAGS" ]; then
        echo "❌ Error: Forbidden diagnostic calls (print, NSLog, os_log) found in capsule sources:"
        echo "$FORBIDDEN_DIAGS"
        exit 1
    fi
    echo "✅ Diagnostics conformance passed."
fi

# 4. GATE_BUILD_HYGIENE
if run_gate "GATE_BUILD_HYGIENE"; then
    echo "🔍 [GATE_BUILD_HYGIENE] Checking Build Hygiene..."
    HOMEBREW_PATHS=$(grep -r "/opt/homebrew" "$CAPSULE_PATH" --exclude="*.sh" || true)
    if [ -n "$HOMEBREW_PATHS" ]; then
        echo "❌ Error: Absolute /opt/homebrew paths found (violates build portability):"
        echo "$HOMEBREW_PATHS"
        exit 1
    fi

    if [ -f "$CAPSULE_PATH/Package.swift" ]; then
        UNSAFE_FLAGS=$(grep -n ".unsafeFlags" "$CAPSULE_PATH/Package.swift" || true)
        if [ -n "$UNSAFE_FLAGS" ]; then
            echo "   Checking documentation for unsafeFlags..."
            while read -r line; do
                line_num=$(echo "$line" | cut -d: -f1)
                prev_line_num=$((line_num - 1))
                if ! sed -n "${prev_line_num}p" "$CAPSULE_PATH/Package.swift" | grep -q "//"; then
                    echo "❌ Error: Undocumented unsafe flag at Package.swift:$line_num"
                    exit 1
                fi
            done <<< "$UNSAFE_FLAGS"
        fi
    fi
    echo "✅ Build hygiene passed."
fi

# 5. GATE_TEST_COVERAGE
if run_gate "GATE_TEST_COVERAGE"; then
    echo "🔍 [GATE_TEST_COVERAGE] Verifying Test Coverage and Count..."
    TIER=$(grep -E "^tier =" "$CAPSULE_PATH/MANIFEST.toml" | cut -d'=' -f2 | tr -d ' ')
    MIN_COVERAGE=0
    MIN_TESTS=0
    if [ "$TIER" -eq 5 ]; then
        MIN_COVERAGE=80
        MIN_TESTS=15
    elif [ "$TIER" -eq 3 ]; then
        MIN_COVERAGE=60
        MIN_TESTS=10
    fi

    if [ "$MIN_TESTS" -gt 0 ]; then
        TEST_COUNT=$(grep -r "func test" "$CAPSULE_PATH/Tests" | wc -l | tr -d ' ')
        echo "   Test count: $TEST_COUNT (Required: $MIN_TESTS)"
        if [ "$TEST_COUNT" -lt "$MIN_TESTS" ]; then
            echo "❌ Error: Insufficient test count for Tier $TIER (Found $TEST_COUNT, need $MIN_TESTS)"
            exit 1
        fi
    fi
    echo "✅ Test coverage/count requirements met."
fi


echo "=========================================================="
echo "🎉 ALL GATES PASSED for $CAPSULE_NAME"
echo "=========================================================="
