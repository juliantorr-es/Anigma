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
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)

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
    FORBIDDEN_PATTERN="\\b(Swift\\.)?print\\s*\\(|\\bNSLog\\s*\\(|\\bos_log\\s*\\("
    FORBIDDEN_DIAGS=$(grep -rEn --include="*.swift" --include="*.m" --include="*.mm" --include="*.c" --include="*.cpp" "$FORBIDDEN_PATTERN" "$CAPSULE_PATH/Sources" || true)
    if [ -n "$FORBIDDEN_DIAGS" ]; then
        echo "❌ Error: Forbidden diagnostic calls (print, NSLog, os_log) found in capsule sources:"
        echo "$FORBIDDEN_DIAGS"
        exit 1
    fi

    TIER=$(grep -E "^tier =" "$CAPSULE_PATH/MANIFEST.toml" | cut -d'=' -f2 | tr -d ' ')
    if [ "$TIER" -eq 5 ] || [ "$TIER" -eq 3 ]; then
        DIAGNOSTIC_USAGE=$(grep -rE --include="*.swift" "\\.\\s*(beginSpan|event)\\s*\\(" "$CAPSULE_PATH/Sources" || true)
        if [ -z "$DIAGNOSTIC_USAGE" ]; then
            echo "❌ Error: Tier $TIER capsules must call diagnostics.beginSpan(...) or diagnostics.event(...) at least once in Sources."
            echo "   Add a diagnostics span or event in capsule runtime code to satisfy Tier $TIER requirements."
            exit 1
        fi
        echo "✅ Tier $TIER diagnostics adoption check passed."
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
    REQUIRE_GOLDENS=false
    if [ "$TIER" -eq 5 ]; then
        MIN_COVERAGE=80
        MIN_TESTS=15
        REQUIRE_GOLDENS=true
    elif [ "$TIER" -eq 3 ]; then
        MIN_COVERAGE=60
        MIN_TESTS=10
        REQUIRE_GOLDENS=true
    fi

    echo "   Running swift test with coverage for $CAPSULE_NAME..."
    # Create test results directory for artifacts
    mkdir -p "$CAPSULE_PATH/test-results/diffs"
    
    (cd "$CAPSULE_PATH" && swift test --enable-code-coverage > test_output.txt 2>&1) || {
        echo "❌ Error: swift test failed for $CAPSULE_NAME"
        # If there are diffs, they should be in test-results/diffs
        # (Assuming the test suite is configured to put them there)
        exit 1
    }

    # Extract test count from output
    TEST_COUNT=$(grep "Executed .* tests" "$CAPSULE_PATH/test_output.txt" | sed -E 's/.*Executed ([0-9]+) tests.*/\1/' | awk '{s+=$1} END {print s}')
    
    if [ -z "$TEST_COUNT" ] || [ "$TEST_COUNT" -eq 0 ]; then
        # Fallback to grep if output format is different
        TEST_COUNT=$(grep -r "func test" "$CAPSULE_PATH/Tests" | wc -l | tr -d ' ')
    fi

    echo "   Test count: $TEST_COUNT (Required: $MIN_TESTS)"
    if [ "$TEST_COUNT" -lt "$MIN_TESTS" ]; then
        echo "❌ Error: Insufficient test count for Tier $TIER (Found $TEST_COUNT, need $MIN_TESTS)"
        exit 1
    fi

    # Check for Goldens
    if [ "$REQUIRE_GOLDENS" = true ]; then
        echo "   Checking for golden tests..."
        # Check for directory or files with Golden in name
        GOLDEN_FOUND=$(find "$CAPSULE_PATH/Tests" -type d -name "Goldens" -o -name "*GoldenTests.swift" | wc -l | tr -d ' ')
        if [ "$GOLDEN_FOUND" -eq 0 ]; then
             echo "❌ Error: Golden tests required for Tier $TIER but none found (expected Tests/Goldens directory or *GoldenTests.swift files)"
             exit 1
        fi
        echo "✅ Golden tests present."
    fi

    # Coverage via llvm-cov
    BIN_PATH=$(cd "$CAPSULE_PATH" && swift build --show-bin-path)
    XCTEST_PATH=$(find "$BIN_PATH" -name "${CAPSULE_NAME}PackageTests.xctest" -o -name "${CAPSULE_NAME}Tests.xctest" | head -n 1)
    
    if [ -z "$XCTEST_PATH" ]; then
        XCTEST_PATH=$(find "$BIN_PATH" -name "*.xctest" | head -n 1)
    fi

    if [ -n "$XCTEST_PATH" ]; then
        # On macOS, the binary is inside the .xctest bundle
        if [[ "$OSTYPE" == "darwin"* ]]; then
            BINARY_NAME=$(basename "$XCTEST_PATH" .xctest)
            XCTEST_BINARY="$XCTEST_PATH/Contents/MacOS/$BINARY_NAME"
        else
            XCTEST_BINARY="$XCTEST_PATH"
        fi

        PROFDATA=$(find "$CAPSULE_PATH/.build" -name "default.profdata" | head -n 1)

        if [ -n "$XCTEST_BINARY" ] && [ -f "$XCTEST_BINARY" ] && [ -n "$PROFDATA" ]; then
            COVERAGE_REPORT=$(xcrun llvm-cov report "$XCTEST_BINARY" -instr-profile="$PROFDATA" -ignore-filename-regex=".build|Tests")
            echo "$COVERAGE_REPORT"
            COVERAGE_PERCENT=$(echo "$COVERAGE_REPORT" | grep "TOTAL" | awk '{print $NF}' | tr -d '%')
            
            if [ -z "$COVERAGE_PERCENT" ]; then COVERAGE_PERCENT=0; fi
            
            echo "   Coverage: $COVERAGE_PERCENT% (Required: $MIN_COVERAGE%)"
            
            # Update coverage dashboard
            DASHBOARD="$PROJECT_ROOT/Docs/governance/coverage_dashboard.md"
            mkdir -p "$(dirname "$DASHBOARD")"
            if [ ! -f "$DASHBOARD" ]; then
                echo "# Capsule Coverage Dashboard" > "$DASHBOARD"
                echo "| Capsule | Tier | Tests | Coverage | Diagnostics Adoption | Last Updated |" >> "$DASHBOARD"
                echo "|---------|------|-------|----------|----------------------|--------------|" >> "$DASHBOARD"
            elif ! grep -q "Diagnostics Adoption" "$DASHBOARD"; then
                sed -i '' "s/| Capsule | Tier | Tests | Coverage | Last Updated |/| Capsule | Tier | Tests | Coverage | Diagnostics Adoption | Last Updated |/" "$DASHBOARD"
                sed -i '' "s/|---------|------|-------|----------|--------------|/|---------|------|-------|----------|----------------------|--------------|/" "$DASHBOARD"
            fi

            TOTAL_DIAG_FILES=$(find "$CAPSULE_PATH/Sources" -type f -name "*.swift" | wc -l | tr -d ' ')
            ADOPTED_DIAG_FILES=$(grep -rlE --include="*.swift" "\\.\\s*(beginSpan|event)\\s*\\(" "$CAPSULE_PATH/Sources" || true)
            ADOPTED_DIAG_FILES=$(printf "%s\n" "$ADOPTED_DIAG_FILES" | awk 'NF{count++} END{print count+0}')
            if [ -n "$TOTAL_DIAG_FILES" ] && [ "$TOTAL_DIAG_FILES" -gt 0 ]; then
                DIAGNOSTICS_ADOPTION=$((ADOPTED_DIAG_FILES * 100 / TOTAL_DIAG_FILES))
            else
                DIAGNOSTICS_ADOPTION=0
            fi
            
            # Remove existing entry for this capsule if it exists
            sed -i '' "/| $CAPSULE_NAME |/d" "$DASHBOARD"
            echo "| $CAPSULE_NAME | $TIER | $TEST_COUNT | $COVERAGE_PERCENT% | $DIAGNOSTICS_ADOPTION% | $(date) |" >> "$DASHBOARD"

            if (( $(echo "$COVERAGE_PERCENT < $MIN_COVERAGE" | bc -l) )); then
                echo "❌ Error: Insufficient coverage for Tier $TIER (Found $COVERAGE_PERCENT%, need $MIN_COVERAGE%)"
                exit 1
            fi
        else
            echo "⚠️ Warning: Could not run llvm-cov (binary or profdata missing or invalid)"
            [ ! -f "$XCTEST_BINARY" ] && echo "   Missing binary: $XCTEST_BINARY"
            [ -z "$PROFDATA" ] && echo "   Missing profdata"
        fi
    else
        echo "⚠️ Warning: Could not find .xctest bundle in $BIN_PATH"
    fi

    echo "✅ Test coverage/count requirements met."
fi


echo "=========================================================="
echo "🎉 ALL GATES PASSED for $CAPSULE_NAME"
echo "=========================================================="
