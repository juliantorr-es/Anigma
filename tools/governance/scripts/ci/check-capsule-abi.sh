#!/usr/bin/env bash
# Scripts/ci/check-capsule-abi.sh
# Check C++ capsule code for ABI violations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "::group::Capsule ABI Boundary Validation"
echo "Root: ${PROJECT_ROOT}"
echo ""

cd "${PROJECT_ROOT}"

VIOLATIONS=0

# Pattern 1: std::string in C header files (should use const char*)
echo "Checking for std::string in C ABI headers..."
while IFS= read -r -d '' file; do
    if grep -n "std::string" "$file" > /dev/null; then
        echo "❌ $file contains std::string (should use const char* or anigma_buffer_t)"
        grep -n "std::string" "$file"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done < <(find Native/Shims/include -name "*.h" -type f -print0)

# Pattern 2: C++ exceptions not caught at boundary (simple check for 'throw' in .cpp files)
echo "Checking for uncaught exceptions in capsule implementations..."
while IFS= read -r -d '' file; do
    # Count 'throw' statements not inside a try-catch block (simplistic)
    # This is a naive check; for now we just warn.
    if grep -n "throw " "$file" > /dev/null; then
        echo "⚠️  $file contains throw statements (ensure caught at ABI boundary)"
        grep -n "throw " "$file"
    fi
done < <(find Native/Shims/src -name "*.cpp" -type f -print0)

# Pattern 3: Non-POD types in C function signatures (complex, skip for now)

# Pattern 4: C++ references in C headers (should use pointers)
echo "Checking for C++ references in C headers..."
while IFS= read -r -d '' file; do
    if grep -n "&[^;]*)" "$file" | grep -v "//" | head -5; then
        echo "⚠️  $file contains C++ references in function signatures (use pointers)"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done < <(find Native/Shims/include -name "*.h" -type f -print0)

# Pattern 5: Missing extern "C" in public headers
echo "Checking for missing extern \"C\" in public headers..."
while IFS= read -r -d '' file; do
    if ! grep -q 'extern "C"' "$file"; then
        echo "❌ $file missing extern \"C\" wrapper"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done < <(find Native/Shims/include -name "*.h" -type f -print0)

if [[ $VIOLATIONS -eq 0 ]]; then
    echo ""
    echo "✅ PASSED: No ABI boundary violations detected"
    echo "::endgroup::"
    exit 0
else
    echo ""
    echo "❌ FAILED: $VIOLATIONS ABI boundary violation(s) detected"
    echo "::endgroup::"
    exit 1
fi