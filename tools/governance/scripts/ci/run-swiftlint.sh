#!/usr/bin/env bash
# Scripts/ci/run-swiftlint.sh
# Run SwiftLint with contract enforcement rules

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_PATH=".swiftlint.yml"

echo "::group::SwiftLint Contract Enforcement"
echo "Root: ${PROJECT_ROOT}"
echo ""

# Check if SwiftLint is installed
if ! command -v swiftlint &> /dev/null; then
    echo "⚠️  SwiftLint not installed. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install swiftlint
    else
        echo "❌ Homebrew not found. Please install SwiftLint manually:"
        echo "   https://github.com/realm/SwiftLint#installation"
        exit 1
    fi
fi

echo "✓ SwiftLint version: $(swiftlint version)"
echo ""

# Run SwiftLint
cd "${PROJECT_ROOT}"

if [[ ! -f "${CONFIG_PATH}" ]]; then
    echo "❌ SwiftLint config not found at ${CONFIG_PATH}"
    echo "::endgroup::"
    exit 1
fi

echo "ℹ️  Remediation priority: P0 → P1 → P2 (see Docs/development/swiftlint-remediation-plan.md)"
echo "✓ Running SwiftLint with contract rules..."
if swiftlint lint --strict --config "${CONFIG_PATH}"; then
    echo ""
    echo "✅ PASSED: No SwiftLint violations"
    echo "::endgroup::"
    exit 0
else
    echo ""
    echo "❌ FAILED: SwiftLint violations detected"
    echo "::endgroup::"
    exit 1
fi
