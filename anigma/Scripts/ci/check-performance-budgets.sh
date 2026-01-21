#!/usr/bin/env bash
# Scripts/ci/check-performance-budgets.sh
# Enforces performance contract compliance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUDGETS_FILE="${PROJECT_ROOT}/Docs/PerformanceBudgets.md"

echo "::group::Performance Contract Enforcement"
echo "Root: ${PROJECT_ROOT}"
echo "Budgets: ${BUDGETS_FILE}"
echo ""

violations=0

# Check 1: Performance budgets document exists
if [[ ! -f "${BUDGETS_FILE}" ]]; then
  echo "❌ PerformanceBudgets.md not found"
  violations=$((violations + 1))
  echo "::endgroup::"
  exit 1
fi

echo "✅ Performance budgets document found"

# Check 2: Run performance benchmark suite (if it exists)
BENCHMARK_SUITE="${PROJECT_ROOT}/Tests/AnigmaAppMacTests/PerformanceBenchmarkTests.swift"

if [[ -f "${BENCHMARK_SUITE}" ]]; then
  echo ""
  echo "✓ Running performance benchmarks..."
  
  # Run tests with performance metrics
  if swift test --filter PerformanceBenchmark 2>&1 | tee /tmp/perf-output.txt; then
    echo "✅ Performance benchmarks passed"
  else
    echo "❌ Performance benchmarks failed"
    violations=$((violations + 1))
  fi
else
  echo ""
  echo "⚠️  Performance benchmark suite not yet implemented"
  echo "   Expected: ${BENCHMARK_SUITE}"
  echo "   See Ticket 006 for implementation details"
fi

# Check 3: Verify OperationResult usage for async operations
echo ""
echo "✓ Checking OperationResult compliance..."

# Find async functions that don't return OperationResult
async_funcs=$(grep -rn "func.*async.*->" \
  "${PROJECT_ROOT}/Sources/AnigmaAppMac" \
  | grep -v "OperationResult\|Receipt\|// OK:" \
  | grep -v "Binary file" \
  | wc -l || true)

if [[ "$async_funcs" -gt 20 ]]; then
  echo "⚠️  Found $async_funcs async functions not using OperationResult"
  echo "   (Threshold: 20, consider wrapping in OperationResult for progress tracking)"
fi

# Check 4: Verify progress reporting
echo ""
echo "✓ Checking progress reporting..."

# Count OperationResult usages
operation_results=$(grep -rn "OperationResult<" \
  "${PROJECT_ROOT}/Sources/AnigmaAppMac" \
  | wc -l || true)

if [[ "$operation_results" -lt 5 ]]; then
  echo "⚠️  Only $operation_results OperationResult usages found"
  echo "   (Expected: 5+, see Ticket 001 for migration guide)"
fi

# Check 5: Memory budget compliance (basic check)
echo ""
echo "✓ Checking memory usage patterns..."

# Look for potential memory leaks (strong reference cycles)
strong_self=$(grep -rn "\[self\]" \
  "${PROJECT_ROOT}/Sources/AnigmaAppMac" \
  | grep -v "weak self\|unowned self" \
  | grep -v "Binary file" \
  | wc -l || true)

if [[ "$strong_self" -gt 10 ]]; then
  echo "⚠️  Found $strong_self potential strong reference cycles"
  echo "   (Threshold: 10, use [weak self] in closures)"
fi

echo ""
echo "::endgroup::"

if [[ "$violations" -gt 0 ]]; then
  echo "❌ FAILED: $violations critical performance violations"
  exit 1
fi

echo "✅ PASSED: Performance contract compliance verified"
exit 0
