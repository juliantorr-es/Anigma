#!/bin/bash

# Print to OSLog Conversion Script
# Converts print() statements to OSLog in Swift files

set -e

echo "=== Print to OSLog Conversion Script ==="
echo "Generated: $(date)"
echo ""

if [ -z "$1" ]; then
    echo "Usage: $0 <file.swift>"
    echo "Example: $0 Sources/Module/File.swift"
    exit 1
fi

FILE="$1"

if [ ! -f "$FILE" ]; then
    echo "❌ File not found: $FILE"
    exit 1
fi

# Check if file already has OSLog import
if grep -q "import os.log" "$FILE"; then
    echo "✅ OSLog already imported"
else
    # Add OSLog import after other imports
    echo "Adding OSLog import..."
    # Find the last import line and add after it
    # This is a simple approach - may need manual adjustment
    sed -i '' '/^import.*/a\\nimport os.log' "$FILE"
    echo "✅ OSLog import added"
fi

# Check if file has a logger defined
if grep -q "private let log = Logger" "$FILE"; then
    echo "✅ Logger already defined"
else
    # Add logger definition after property declarations
    # Find a good place to insert (after 'private let' or similar)
    echo "Adding logger definition..."
    # Simple approach: add after the last 'private let' or at class start
    # This may need manual adjustment for complex files
    sed -i '' '/^public class\|^public struct\|^public actor/{\n    N\n    a\\n    private let log = Logger(subsystem: "com.anigma.backend", category: "general")\n}' "$FILE"
    echo "✅ Logger definition added"
fi

# Replace simple print statements
# Note: This is a basic conversion and may need manual refinement
PRINT_COUNT=$(grep -c 'print(' "$FILE" 2>/dev/null || echo "0")

if [ "$PRINT_COUNT" -gt "0" ]; then
    echo "Found $PRINT_COUNT print() statements to convert"
    
    # Replace print("message") with log.info("message")
    sed -i '' 's/print("\([^"]*\)")/log.info("\1")/g' "$FILE"
    
    # Replace print("message: \(var)") with structured logging
    # This is more complex and may need manual work
    echo "⚠️  Complex print statements may need manual conversion"
else
    echo "✅ No print() statements found"
fi

echo ""
echo "✅ Conversion complete for: $FILE"
echo "⚠️  Review the file for:"
echo "   - Complex print statements needing manual conversion"
echo "   - Proper logger category (change 'general' to module-specific)"
echo "   - Privacy settings for sensitive data"
echo "   - Appropriate log levels (.info, .debug, .warning, .error)"

echo ""
echo "Suggested manual improvements:"
echo "1. Set appropriate categories (e.g., 'workflow', 'network')"
echo "2. Add metadata for important logs"
echo "3. Use proper privacy settings (.public vs .private)"
echo "4. Check log levels match importance"
echo "5. Remove debug prints from production code"
