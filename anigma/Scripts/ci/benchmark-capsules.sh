#!/usr/bin/env bash
# Scripts/ci/benchmark-capsules.sh
# Run capsule performance benchmarks and enforce marshalling budgets

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "::group::Capsule Performance Benchmarks"
echo "Root: ${PROJECT_ROOT}"
echo ""

cd "${PROJECT_ROOT}"

# Build the CapsuleCore module to ensure benchmarks compile
echo "Building CapsuleCore..."
if ! swift build --product CapsuleCore 2>&1 | tee /tmp/capsule-build.log; then
    echo "❌ Failed to build CapsuleCore"
    cat /tmp/capsule-build.log
    echo "::endgroup::"
    exit 1
fi

# Check if there are any benchmark implementations
# For now, we'll run a simple test to verify the benchmark infrastructure works.
# In the future, we should discover and run all CapsuleBenchmark conformances.

echo "Running capsule benchmark suite..."
# Placeholder: run a test that uses CapsuleBenchmark
# We'll create a simple test that validates the protocol compiles and can be instantiated.

TEST_FILE="${PROJECT_ROOT}/Tests/CapsuleCoreTests/CapsuleBenchmarkTests.swift"
if [[ -f "${TEST_FILE}" ]]; then
    echo "Found CapsuleBenchmarkTests, running..."
    if swift test --filter CapsuleBenchmarkTests 2>&1 | tee /tmp/benchmark-output.log; then
        echo "✅ Capsule benchmark tests passed"
    else
        echo "❌ Capsule benchmark tests failed"
        cat /tmp/benchmark-output.log
        echo "::endgroup::"
        exit 1
    fi
else
    echo "⚠️  CapsuleBenchmarkTests not yet implemented"
    echo "   To add benchmarks, create a test file at Tests/CapsuleCoreTests/CapsuleBenchmarkTests.swift"
    echo "   and implement benchmarks conforming to CapsuleBenchmark."
fi

# Check marshalling budgets against telemetry
echo ""
echo "Validating marshalling budgets..."
# This would iterate over each capsule, run a workload, and verify telemetry against budgets.
# For now, we'll run the budget validation script.
if ./Scripts/check_marshalling_budgets.swift; then
    echo "✅ Marshalling budget validation passed"
else
    echo "❌ Marshalling budget validation failed"
    echo "::endgroup::"
    exit 1
fi

echo ""
echo "✅ Capsule benchmark suite completed"
echo "::endgroup::"
exit 0