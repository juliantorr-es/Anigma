#!/usr/bin/env bash
# Scripts/remediation/fix-font-tokens.sh
# Automated remediation campaign: Font token migration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "🔧 Remediation Campaign: Font Token Migration"
echo "Campaign ID: contract-002"
echo "Severity: CRITICAL"
echo "Affected Files: 10"
echo ""

# Find all Swift files with hardcoded fonts
FILES=$(grep -rl "\.font(\.system\|Font\.system" \
    "${PROJECT_ROOT}/Sources/AnigmaAppMac/Surfaces" \
    "${PROJECT_ROOT}/Sources/AnigmaAppMac/Components" \
    2>/dev/null | grep -v "DesignSystem.swift" || true)

if [[ -z "${FILES}" ]]; then
    echo "✅ No hardcoded fonts found"
    exit 0
fi

echo "📝 Files to fix:"
echo "${FILES}" | while read -r file; do
    echo "  - ${file#$PROJECT_ROOT/}"
done
echo ""

FIXED_COUNT=0

# Apply fixes
echo "${FILES}" | while read -r file; do
    if [[ ! -f "${file}" ]]; then
        continue
    fi
    
    echo "🔧 Fixing: ${file#$PROJECT_ROOT/}"
    
    # Create backup
    cp "${file}" "${file}.bak"
    
    # Common font replacements
    # .font(.system(size: 14)) -> .font(Bauhaus.Font.body)
    # .font(.system(size: 20, weight: .bold)) -> .font(Bauhaus.Font.header)
    # .font(.system(size: 12)) -> .font(Bauhaus.Font.caption)
    
    # Replace common patterns
    sed -i '' 's/\.font(\.system(size: 20.*))/.font(Bauhaus.Font.header)/g' "${file}"
    sed -i '' 's/\.font(\.system(size: 18.*))/.font(Bauhaus.Font.subHeader)/g' "${file}"
    sed -i '' 's/\.font(\.system(size: 14.*))/.font(Bauhaus.Font.body)/g' "${file}"
    sed -i '' 's/\.font(\.system(size: 12.*))/.font(Bauhaus.Font.caption)/g' "${file}"
    sed -i '' 's/\.font(\.system(size: 11.*))/.font(Bauhaus.Font.caption)/g' "${file}"
    sed -i '' 's/Font\.system(size: 20.*)/Bauhaus.Font.header/g' "${file}"
    sed -i '' 's/Font\.system(size: 18.*)/Bauhaus.Font.subHeader/g' "${file}"
    sed -i '' 's/Font\.system(size: 14.*)/Bauhaus.Font.body/g' "${file}"
    sed -i '' 's/Font\.system(size: 12.*)/Bauhaus.Font.caption/g' "${file}"
    sed -i '' 's/Font\.system(size: 11.*)/Bauhaus.Font.caption/g' "${file}"
    
    # Check if file changed
    if ! diff -q "${file}" "${file}.bak" > /dev/null 2>&1; then
        echo "  ✅ Fixed"
        FIXED_COUNT=$((FIXED_COUNT + 1))
    else
        echo "  ⏭️  No changes needed"
    fi
    
    # Remove backup
    rm "${file}.bak"
done

echo ""
echo "✅ Campaign Complete"
echo "   Fixed: ${FIXED_COUNT} files"
echo ""
echo "📋 Next Steps:"
echo "   1. Review changes: git diff"
echo "   2. Run tests: swift test"
echo "   3. Verify: ./Scripts/ci/check-design-tokens.sh"
echo "   4. Commit: git commit -m 'fix: migrate to Bauhaus.Font tokens (contract-002)'"
