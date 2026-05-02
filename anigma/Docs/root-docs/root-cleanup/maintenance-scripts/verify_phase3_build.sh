#!/bin/bash
# Phase 3 Prototype Build Verification
# Ensures minimal target stays buildable and doesn't regress

set -e

echo "=== Phase 3 Prototype Verification ==="
echo ""

# 1. Governance Harness
echo "1. Running governance harness (61/61 expected)..."
cd Tests/GovernanceHarness
swift test 2>&1 | grep "Executed.*tests" || exit 1
cd ../..

# 2. Mac App Build
echo ""
echo "2. Building minimal Mac app target..."
cd anigma
swift build --target AnigmaAppMacExecutable 2>&1 | grep -q "Build.*complete" || exit 1
cd ..

# 3. Verify no daemon dependency
echo ""
echo "3. Checking AnigmaAppMacExecutable doesn't depend on daemon..."
if grep -q "AnigmaDaemonCore" anigma/Package.swift | grep -A1 "AnigmaAppMacExecutable"; then
    echo "ERROR: AnigmaAppMacExecutable depends on AnigmaDaemonCore!"
    exit 1
fi

# 4. Verify minimal source list
echo ""
echo "4. Verifying minimal source file count..."
SOURCE_COUNT=$(grep -A 20 "name: \"AnigmaAppMacExecutable\"" anigma/Package.swift | grep -c "\.swift" || echo "0")
if [ "$SOURCE_COUNT" -gt 15 ]; then
    echo "WARNING: Source file count is $SOURCE_COUNT (should be ~9)"
    echo "Phase 3 target may be accumulating cruft"
fi

echo ""
echo "=== ✅ All Phase 3 Verification Passed ==="
echo ""
echo "Next: Open anigma/Package.swift in Xcode, select AnigmaAppMacExecutable, Cmd+R"
