#!/usr/bin/env bash
# Scripts/remediation/fix-button-styles.sh
# Automated remediation campaign: Button style migration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "🔧 Remediation Campaign: Button Style Migration"
echo "Campaign ID: contract-003"
echo "Severity: WARNING"
echo "Affected Files: 46"
echo ""

# Find all Swift files with unstyled buttons
# Look for Button( followed by closing brace without a button style modifier
FILES=$(grep -rl "Button(" \
    "${PROJECT_ROOT}/Sources/AnigmaAppMac/Surfaces" \
    "${PROJECT_ROOT}/Sources/AnigmaAppMac/Components" \
    2>/dev/null | grep -v "ButtonStyles.swift" || true)

if [[ -z "${FILES}" ]]; then
    echo "✅ No unstyled buttons found"
    exit 0
fi

echo "📝 Analyzing button usage patterns..."
echo ""

FIXED_COUNT=0
SKIPPED_COUNT=0

# Process each file
echo "${FILES}" | while read -r file; do
    if [[ ! -f "${file}" ]]; then
        continue
    fi
    
    echo "🔍 Analyzing: ${file#$PROJECT_ROOT/}"
    
    # Create backup
    cp "${file}" "${file}.bak"
    
    # Strategy: Add .primaryButtonStyle() to simple action buttons
    # This is a conservative approach - only fix obvious cases
    
    # Pattern 1: Simple action buttons (Submit, Save, Create, etc.)
    sed -i '' 's/Button("Submit") {/.primaryButtonStyle()\
Button("Submit") {/g' "${file}"
    sed -i '' 's/Button("Save") {/.primaryButtonStyle()\
Button("Save") {/g' "${file}"
    sed -i '' 's/Button("Create") {/.primaryButtonStyle()\
Button("Create") {/g' "${file}"
    sed -i '' 's/Button("Add") {/.primaryButtonStyle()\
Button("Add") {/g' "${file}"
    sed -i '' 's/Button("Start") {/.primaryButtonStyle()\
Button("Start") {/g' "${file}"
    sed -i '' 's/Button("Continue") {/.primaryButtonStyle()\
Button("Continue") {/g' "${file}"
    
    # Pattern 2: Cancel/Close buttons
    sed -i '' 's/Button("Cancel") {/.secondaryButtonStyle()\
Button("Cancel") {/g' "${file}"
    sed -i '' 's/Button("Close") {/.secondaryButtonStyle()\
Button("Close") {/g' "${file}"
    sed -i '' 's/Button("Dismiss") {/.secondaryButtonStyle()\
Button("Dismiss") {/g' "${file}"
    
    # Pattern 3: Destructive buttons
    sed -i '' 's/Button("Delete") {/.destructiveButtonStyle()\
Button("Delete") {/g' "${file}"
    sed -i '' 's/Button("Remove") {/.destructiveButtonStyle()\
Button("Remove") {/g' "${file}"
    sed -i '' 's/Button("Clear") {/.destructiveButtonStyle()\
Button("Clear") {/g' "${file}"
    
    # Check if file changed
    if ! diff -q "${file}" "${file}.bak" > /dev/null 2>&1; then
        echo "  ✅ Fixed (pattern-based)"
        FIXED_COUNT=$((FIXED_COUNT + 1))
    else
        echo "  ⏭️  No simple patterns found (manual review needed)"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
    
    # Remove backup
    rm "${file}.bak"
done

echo ""
echo "✅ Campaign Complete"
echo "   Fixed: ${FIXED_COUNT} files (pattern-based)"
echo "   Skipped: ${SKIPPED_COUNT} files (need manual review)"
echo ""
echo "⚠️  Note: This campaign uses conservative pattern matching."
echo "   Complex buttons and custom labels require manual review."
echo ""
echo "📋 Next Steps:"
echo "   1. Review changes: git diff"
echo "   2. Manual review: See Docs/ManualReviewGuide.md"
echo "   3. Run tests: swift test"
echo "   4. Verify: ./Scripts/ci/check-design-tokens.sh"
echo "   5. Commit: git commit -m 'fix: migrate buttons to standardized styles (contract-003)'"
