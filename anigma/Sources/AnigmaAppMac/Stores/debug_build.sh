#!/bin/bash
# debug_build.sh
# Master script to debug Anigma build errors
# Runs capture, analysis, and fix suggestion tools

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                    ANIGMA BUILD DEBUGGER                                   ║"
echo "║                    Complete Error Analysis Suite                           ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Make scripts executable
chmod +x "$SCRIPT_DIR/capture_build_errors.sh"
chmod +x "$SCRIPT_DIR/suggest_fixes.sh"
chmod +x "$SCRIPT_DIR/analyze_build_errors.py"

echo "🚀 Starting comprehensive build analysis..."
echo ""

# Step 1: Capture build errors
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Capturing Build Errors"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if bash "$SCRIPT_DIR/capture_build_errors.sh"; then
    echo ""
    echo "✅ Build succeeded! No errors to analyze."
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════════╗"
    echo "║  🎉 SUCCESS: anigma-app builds without errors!                            ║"
    echo "╚════════════════════════════════════════════════════════════════════════════╝"
    exit 0
else
    BUILD_EXIT_CODE=$?
    echo ""
    echo "⚠️  Build failed (expected). Continuing with analysis..."
    echo ""
fi

# Step 2: Advanced Python analysis (if available)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Advanced Error Analysis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v python3 &> /dev/null; then
    python3 "$SCRIPT_DIR/analyze_build_errors.py" "$SCRIPT_DIR/build_errors_raw.txt" || true
else
    echo "⚠️  Python 3 not found. Skipping advanced analysis."
    echo "   Install Python 3 to enable detailed error categorization."
fi

echo ""

# Step 3: Generate fix suggestions
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Generating Fix Suggestions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

bash "$SCRIPT_DIR/suggest_fixes.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ANALYSIS COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Summary of generated files
echo "📦 Generated Files:"
echo ""
echo "  1. build_errors_raw.txt           - Raw compiler output"
echo "  2. build_errors_report.txt        - Human-readable report"
echo "  3. build_errors_summary.json      - JSON summary"
echo "  4. build_errors_analysis.txt      - Advanced analysis (if Python available)"
echo "  5. build_errors_analysis.json     - Detailed JSON (if Python available)"
echo "  6. suggested_fixes.md             - Fix suggestions and strategies"
echo ""

# Quick statistics
ERROR_COUNT=$(grep -c "error:" "$SCRIPT_DIR/build_errors_raw.txt" || echo "0")
UNIQUE_FILES=$(grep "error:" "$SCRIPT_DIR/build_errors_raw.txt" | sed -E 's/^([^:]+):.*$/\1/' | sort -u | wc -l)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "QUICK STATS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Total Errors:    $ERROR_COUNT"
echo "  Affected Files:  $UNIQUE_FILES"
echo ""

# Top 5 error types
echo "  Top Error Types:"
AMBIGUOUS=$(grep -c "ambiguous use of" "$SCRIPT_DIR/build_errors_raw.txt" 2>/dev/null || echo "0")
NO_MEMBER=$(grep -c "has no member" "$SCRIPT_DIR/build_errors_raw.txt" 2>/dev/null || echo "0")
NOT_FOUND=$(grep -c "cannot find" "$SCRIPT_DIR/build_errors_raw.txt" 2>/dev/null || echo "0")

echo "    - Ambiguous types:    $AMBIGUOUS"
echo "    - Missing members:    $NO_MEMBER"
echo "    - Cannot find:        $NOT_FOUND"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "NEXT STEPS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. 📖 Review the fix suggestions:"
echo "     cat suggested_fixes.md"
echo ""
echo "2. 📊 Check the full error report:"
echo "     cat build_errors_report.txt"
echo ""
echo "3. 🔧 Start fixing (priority order):"
echo "     a. Fix import statements"
echo "     b. Resolve type ambiguities"
echo "     c. Update API calls"
echo "     d. Fix argument mismatches"
echo ""
echo "4. 🔄 Re-run after fixes:"
echo "     bash debug_build.sh"
echo ""
echo "5. 📈 Track progress:"
echo "     grep -c \"error:\" build_errors_raw.txt"
echo ""

# Check if there are known issues in documentation
if [ -f "$SCRIPT_DIR/BINARY_BUNDLE_COMPLETE.md" ]; then
    echo "💡 TIP: Check BINARY_BUNDLE_COMPLETE.md for known issues and fixes"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# If less than 10 errors, show them
if [ "$ERROR_COUNT" -lt 10 ]; then
    echo "🔍 All errors (few enough to show directly):"
    echo ""
    grep "error:" "$SCRIPT_DIR/build_errors_raw.txt" | head -20
    echo ""
fi

# Interactive mode option
echo "Would you like to see suggested fixes now? (y/n)"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    echo ""
    cat "$SCRIPT_DIR/suggested_fixes.md"
fi

exit $BUILD_EXIT_CODE
