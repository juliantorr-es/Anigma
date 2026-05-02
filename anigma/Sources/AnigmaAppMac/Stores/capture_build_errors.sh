#!/bin/bash
# capture_build_errors.sh
# Captures and parses Swift build errors for debugging

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
OUTPUT_FILE="$PROJECT_ROOT/build_errors_report.txt"
RAW_OUTPUT="$PROJECT_ROOT/build_errors_raw.txt"
SUMMARY_FILE="$PROJECT_ROOT/build_errors_summary.json"

echo "=========================================="
echo "Anigma Build Error Capture & Analysis"
echo "=========================================="
echo ""
echo "Project Root: $PROJECT_ROOT"
echo "Output Files:"
echo "  - Raw output: $RAW_OUTPUT"
echo "  - Parsed report: $OUTPUT_FILE"
echo "  - JSON summary: $SUMMARY_FILE"
echo ""

# Clean previous outputs
rm -f "$RAW_OUTPUT" "$OUTPUT_FILE" "$SUMMARY_FILE"

echo "[1/3] Building anigma-app and capturing output..."
echo ""

# Build and capture all output
if swift build --product anigma-app 2>&1 | tee "$RAW_OUTPUT"; then
    echo ""
    echo "✅ Build succeeded! No errors to report."
    exit 0
else
    BUILD_EXIT_CODE=$?
    echo ""
    echo "❌ Build failed with exit code: $BUILD_EXIT_CODE"
    echo ""
fi

echo "[2/3] Parsing errors..."
echo ""

# Parse the raw output and create a structured report
cat > "$OUTPUT_FILE" << 'HEADER'
================================================================================
ANIGMA BUILD ERROR REPORT
================================================================================
Generated: $(date)

This report contains all compilation errors, warnings, and notes from building
the anigma-app executable. Errors are grouped by type and file for easy fixing.

================================================================================
HEADER

# Extract error count
ERROR_COUNT=$(grep -c "error:" "$RAW_OUTPUT" || echo "0")
WARNING_COUNT=$(grep -c "warning:" "$RAW_OUTPUT" || echo "0")
NOTE_COUNT=$(grep -c "note:" "$RAW_OUTPUT" || echo "0")

echo "ERROR SUMMARY" >> "$OUTPUT_FILE"
echo "================================================================================
" >> "$OUTPUT_FILE"
echo "Total Errors:   $ERROR_COUNT" >> "$OUTPUT_FILE"
echo "Total Warnings: $WARNING_COUNT" >> "$OUTPUT_FILE"
echo "Total Notes:    $NOTE_COUNT" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Print summary to console
echo "📊 Summary:"
echo "  Errors:   $ERROR_COUNT"
echo "  Warnings: $WARNING_COUNT"
echo "  Notes:    $NOTE_COUNT"
echo ""

if [ "$ERROR_COUNT" -eq 0 ]; then
    echo "✅ No compilation errors found!"
    exit 0
fi

# Extract and group errors
echo "COMPILATION ERRORS (Grouped by Type)" >> "$OUTPUT_FILE"
echo "================================================================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Function to extract errors by pattern
extract_errors_by_pattern() {
    local pattern="$1"
    local title="$2"
    local count=$(grep -c "$pattern" "$RAW_OUTPUT" || echo "0")
    
    if [ "$count" -gt 0 ]; then
        echo "────────────────────────────────────────────────────────────────────────────" >> "$OUTPUT_FILE"
        echo "$title ($count occurrences)" >> "$OUTPUT_FILE"
        echo "────────────────────────────────────────────────────────────────────────────" >> "$OUTPUT_FILE"
        grep -A 3 "$pattern" "$RAW_OUTPUT" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi
}

# Group errors by common patterns
extract_errors_by_pattern "ambiguous use of" "🔶 AMBIGUOUS TYPE ERRORS"
extract_errors_by_pattern "cannot find type" "🔶 MISSING TYPE ERRORS"
extract_errors_by_pattern "cannot find.*in scope" "🔶 SCOPE ERRORS"
extract_errors_by_pattern "type.*has no member" "🔶 MISSING MEMBER ERRORS"
extract_errors_by_pattern "value of type.*has no member" "🔶 PROPERTY/METHOD NOT FOUND"
extract_errors_by_pattern "initializer.*requires that" "🔶 INITIALIZER ERRORS"
extract_errors_by_pattern "argument.*to parameter" "🔶 ARGUMENT MISMATCH ERRORS"
extract_errors_by_pattern "missing argument" "🔶 MISSING ARGUMENT ERRORS"
extract_errors_by_pattern "extra argument" "🔶 EXTRA ARGUMENT ERRORS"
extract_errors_by_pattern "expected.*but found" "🔶 TYPE MISMATCH ERRORS"

# Extract all errors with context
echo "" >> "$OUTPUT_FILE"
echo "ALL ERRORS (Detailed)" >> "$OUTPUT_FILE"
echo "================================================================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Get errors with 2 lines of context
grep -B 2 -A 2 "error:" "$RAW_OUTPUT" >> "$OUTPUT_FILE" || echo "No errors with context found" >> "$OUTPUT_FILE"

# Extract file locations for quick reference
echo "" >> "$OUTPUT_FILE"
echo "FILES WITH ERRORS (Quick Reference)" >> "$OUTPUT_FILE"
echo "================================================================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

grep "error:" "$RAW_OUTPUT" | sed -E 's/^([^:]+:[^:]+):.*error:.*/\1/' | sort -u >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"
echo "================================================================================
" >> "$OUTPUT_FILE"
echo "END OF REPORT" >> "$OUTPUT_FILE"
echo "================================================================================" >> "$OUTPUT_FILE"

echo "[3/3] Creating JSON summary for programmatic access..."
echo ""

# Create a JSON summary for easier parsing
cat > "$SUMMARY_FILE" << JSON_START
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "build_target": "anigma-app",
  "exit_code": $BUILD_EXIT_CODE,
  "summary": {
    "total_errors": $ERROR_COUNT,
    "total_warnings": $WARNING_COUNT,
    "total_notes": $NOTE_COUNT
  },
  "errors": [
JSON_START

# Extract structured error information
grep "error:" "$RAW_OUTPUT" | head -20 | while IFS= read -r line; do
    # Extract file, line, column, and message
    FILE=$(echo "$line" | sed -E 's/^([^:]+):.*$/\1/')
    LINE_NUM=$(echo "$line" | sed -E 's/^[^:]+:([0-9]+):.*$/\1/')
    MESSAGE=$(echo "$line" | sed -E 's/^[^:]+:[^:]+:[^:]+: error: (.*)$/\1/')
    
    cat >> "$SUMMARY_FILE" << JSON_ERROR
    {
      "file": "$FILE",
      "line": "$LINE_NUM",
      "type": "error",
      "message": "$MESSAGE"
    },
JSON_ERROR
done

# Remove trailing comma and close JSON
sed -i '' '$ s/,$//' "$SUMMARY_FILE" 2>/dev/null || sed -i '$ s/,$//' "$SUMMARY_FILE"
cat >> "$SUMMARY_FILE" << JSON_END
  ],
  "affected_files": [
$(grep "error:" "$RAW_OUTPUT" | sed -E 's/^([^:]+):.*$/    "\1"/' | sort -u | paste -sd, -)
  ]
}
JSON_END

echo "✅ Error capture complete!"
echo ""
echo "=========================================="
echo "REPORT LOCATION"
echo "=========================================="
echo ""
echo "📄 Human-readable report:"
echo "   $OUTPUT_FILE"
echo ""
echo "📄 Raw build output:"
echo "   $RAW_OUTPUT"
echo ""
echo "📄 JSON summary (for scripts):"
echo "   $SUMMARY_FILE"
echo ""
echo "=========================================="
echo "QUICK VIEW"
echo "=========================================="
echo ""

# Show first 50 lines of the report
head -50 "$OUTPUT_FILE"

echo ""
echo "... (See full report in $OUTPUT_FILE)"
echo ""
echo "=========================================="
echo "NEXT STEPS"
echo "=========================================="
echo ""
echo "1. Review the report:"
echo "   cat $OUTPUT_FILE"
echo ""
echo "2. Focus on the first few errors (often cascading)"
echo ""
echo "3. Common fixes:"
echo "   - Type ambiguity: Add module prefix (e.g., AnigmaHostMac.TypeName)"
echo "   - Missing members: Check API changes in dependencies"
echo "   - Argument mismatches: Check initializer signatures"
echo ""

exit $BUILD_EXIT_CODE
