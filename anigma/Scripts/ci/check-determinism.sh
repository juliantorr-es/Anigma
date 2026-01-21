#!/usr/bin/env bash
# Scripts/ci/check-determinism.sh
# Verify Tier 1 capsule determinism (bitwise identical outputs)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "::group::Capsule Determinism Check"
echo "Root: ${PROJECT_ROOT}"
echo ""

cd "${PROJECT_ROOT}"

# Check for golden test corpus
GOLDEN_CORPUS="${PROJECT_ROOT}/Tests/CapsuleCoreTests/GoldenCorpus"
if [[ ! -d "${GOLDEN_CORPUS}" ]]; then
    echo "⚠️  Golden test corpus not found at ${GOLDEN_CORPUS}"
    echo "   Determinism checks will be skipped."
    echo "   To add determinism tests, create a directory with test inputs and expected outputs."
    echo "::endgroup::"
    exit 0
fi

echo "Found golden corpus with $(find "${GOLDEN_CORPUS}" -name "*.input" | wc -l) test inputs."

# Build capsule test harness
echo "Building determinism test harness..."
if ! swift build --product CapsuleCore 2>&1 | tee /tmp/determinism-build.log; then
    echo "❌ Failed to build CapsuleCore"
    cat /tmp/determinism-build.log
    echo "::endgroup::"
    exit 1
fi

# Run determinism tests if they exist
TEST_FILE="${PROJECT_ROOT}/Tests/CapsuleCoreTests/DeterminismTests.swift"
if [[ -f "${TEST_FILE}" ]]; then
    echo "Running determinism tests..."
    if swift test --filter DeterminismTests 2>&1 | tee /tmp/determinism-output.log; then
        echo "✅ Determinism tests passed"
    else
        echo "❌ Determinism tests failed"
        cat /tmp/determinism-output.log
        echo "::endgroup::"
        exit 1
    fi
else
    echo "⚠️  DeterminismTests not yet implemented"
    echo "   To add determinism verification, create a test file at Tests/CapsuleCoreTests/DeterminismTests.swift"
    echo "   that runs each Tier 1 capsule multiple times and compares outputs bitwise."
fi

# Additional check: ensure capsules are marked with determinism tier
echo ""
echo "Checking capsule determinism tier annotations..."
# Look for Tier1/Tier2 annotations in capsule headers
VIOLATIONS=0
while IFS= read -r -d '' file; do
    if grep -q "ANIGMA_CAPSULE_TIER" "$file"; then
        tier=$(grep "ANIGMA_CAPSULE_TIER" "$file" | head -1)
        echo "   $file: $tier"
    else
        echo "❌ $file missing ANIGMA_CAPSULE_TIER annotation"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done < <(find Native/Shims/include -name "*.h" -type f -print0)

if [[ $VIOLATIONS -eq 0 ]]; then
    echo "✅ All capsule headers have determinism tier annotations"
else
    echo "❌ $VIOLATIONS capsule headers missing tier annotations"
    echo "::endgroup::"
    exit 1
fi

echo ""
echo "✅ Determinism checks completed"
echo "::endgroup::"
exit 0