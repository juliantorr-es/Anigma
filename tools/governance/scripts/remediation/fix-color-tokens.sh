#!/usr/bin/env bash
# Scripts/remediation/fix-color-tokens.sh
# Automated remediation campaign: Color token migration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "🔧 Remediation Campaign: Color Token Migration"
echo "Campaign ID: contract-001"
echo "Severity: CRITICAL"
echo "Affected Files: 16"
echo ""

# Color mappings
declare -A COLOR_MAP=(
    ["Color.red"]="Bauhaus.Color.error"
    ["Color.blue"]="Bauhaus.Color.accent"
    ["Color.green"]="Bauhaus.Color.trusted"
    ["Color.orange"]="Bauhaus.Color.warning"
    ["Color.purple"]="Bauhaus.Color.accent"
    ["Color.yellow"]="Bauhaus.Color.warning"
    ["Color.gray"]="Bauhaus.Color.textSecondary"
    [".red"]="Bauhaus.Color.error"
    [".blue"]="Bauhaus.Color.accent"
    [".green"]="Bauhaus.Color.trusted"
    [".orange"]="Bauhaus.Color.warning"
    [".purple"]="Bauhaus.Color.accent"
    [".yellow"]="Bauhaus.Color.warning"
    [".gray"]="Bauhaus.Color.textSecondary"
)

# Find all Swift files with hardcoded colors
FILES=$(grep -rl "Color\.\(red\|blue\|green\|orange\|purple\|yellow\|gray\)" \
    "${PROJECT_ROOT}/Sources/AnigmaAppMac/Surfaces" \
    "${PROJECT_ROOT}/Sources/AnigmaAppMac/Components" \
    2>/dev/null | grep -v "DesignSystem.swift" || true)

if [[ -z "${FILES}" ]]; then
    echo "✅ No hardcoded colors found"
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
    
    # Apply color token replacements
    for old_color in "${!COLOR_MAP[@]}"; do
        new_color="${COLOR_MAP[$old_color]}"
        
        # Use sed to replace (macOS compatible)
        sed -i '' "s/${old_color}/${new_color}/g" "${file}"
    done
    
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
echo "   4. Commit: git commit -m 'fix: migrate to Bauhaus.Color tokens (contract-001)'"
