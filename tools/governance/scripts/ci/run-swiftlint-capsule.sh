#!/usr/bin/env bash
# Scripts/ci/run-swiftlint-capsule.sh
# Run SwiftLint with capsule marshalling rules

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "::group::SwiftLint Capsule Marshalling Validation"
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

# Run SwiftLint with capsule config
cd "${PROJECT_ROOT}"

CONFIG_PATH="Configs/swiftlint-capsule.yml"
if [[ ! -f "${CONFIG_PATH}" ]]; then
    echo "❌ Capsule SwiftLint config not found at ${CONFIG_PATH}"
    exit 1
fi

echo "✓ Running SwiftLint with capsule marshalling rules..."
if swiftlint lint --strict --config "${CONFIG_PATH}"; then
    echo ""
    echo "✅ PASSED: No capsule marshalling violations"
    echo "::endgroup::"
    exit 0
else
    echo ""
    echo "❌ FAILED: Capsule marshalling violations detected"
    echo "::endgroup::"
    exit 1
fi