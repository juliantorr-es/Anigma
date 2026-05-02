#!/bin/bash
# suggest_fixes.sh
# Interactive fix suggestion tool based on build errors

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW_OUTPUT="$SCRIPT_DIR/build_errors_raw.txt"
FIXES_OUTPUT="$SCRIPT_DIR/suggested_fixes.md"

if [ ! -f "$RAW_OUTPUT" ]; then
    echo "❌ Error: Build errors not captured yet."
    echo ""
    echo "Run this first:"
    echo "  bash capture_build_errors.sh"
    echo ""
    exit 1
fi

echo "=========================================="
echo "Anigma Fix Suggestion Tool"
echo "=========================================="
echo ""

# Count different error types
AMBIGUOUS_COUNT=$(grep -c "ambiguous use of" "$RAW_OUTPUT" 2>/dev/null || echo "0")
NO_MEMBER_COUNT=$(grep -c "has no member" "$RAW_OUTPUT" 2>/dev/null || echo "0")
CANNOT_FIND_COUNT=$(grep -c "cannot find type" "$RAW_OUTPUT" 2>/dev/null || echo "0")
ARGUMENT_COUNT=$(grep -c "argument.*to parameter" "$RAW_OUTPUT" 2>/dev/null || echo "0")

echo "📊 Error Distribution:"
echo "  Ambiguous types:    $AMBIGUOUS_COUNT"
echo "  Missing members:    $NO_MEMBER_COUNT"
echo "  Cannot find types:  $CANNOT_FIND_COUNT"
echo "  Argument mismatches: $ARGUMENT_COUNT"
echo ""

# Start building the fixes document
cat > "$FIXES_OUTPUT" << 'HEADER'
# Suggested Fixes for Anigma Build Errors

This document contains automated fix suggestions based on build error analysis.

## Quick Actions

HEADER

# Suggest fixes for ambiguous types
if [ "$AMBIGUOUS_COUNT" -gt 0 ]; then
    cat >> "$FIXES_OUTPUT" << 'AMBIGUOUS'

### Fix Ambiguous Types

**Problem:** Multiple modules define types with the same name.

**Solution:** Use fully qualified type names.

```bash
# Find all ambiguous type errors
grep "ambiguous use of" build_errors_raw.txt | sed -E "s/.*ambiguous use of '([^']+)'.*/\1/" | sort -u
```

**Typical fixes:**

AMBIGUOUS

    # Extract ambiguous types and suggest fixes
    grep "ambiguous use of" "$RAW_OUTPUT" | \
        sed -E "s/.*ambiguous use of '([^']+)'.*/\1/" | \
        sort -u | \
        head -10 | \
        while read -r type_name; do
            echo "- Replace \`$type_name\` with \`AnigmaHostMac.$type_name\` or \`ExportCore.$type_name\`" >> "$FIXES_OUTPUT"
            echo "  Find occurrences: \`grep -r \"$type_name\" Sources/AnigmaAppMac/\`" >> "$FIXES_OUTPUT"
        done
fi

# Suggest fixes for missing members
if [ "$NO_MEMBER_COUNT" -gt 0 ]; then
    cat >> "$FIXES_OUTPUT" << 'MISSING'

### Fix Missing Members

**Problem:** Types don't have expected properties or methods.

**Possible Causes:**
1. API changed in dependency module
2. Using wrong type
3. Property was renamed or removed

**Common fixes:**

MISSING

    # Extract missing member errors
    grep "has no member" "$RAW_OUTPUT" | \
        head -5 | \
        sed -E "s/^([^:]+):([0-9]+):.*/- Check \`\1\` line \2/" >> "$FIXES_OUTPUT"
    
    cat >> "$FIXES_OUTPUT" << 'MISSING_FOOTER'

**Action Items:**
1. Check module documentation for API changes
2. Search for migration guides in the module
3. Look for similar properties with different names

MISSING_FOOTER
fi

# Suggest fixes for cannot find type
if [ "$CANNOT_FIND_COUNT" -gt 0 ]; then
    cat >> "$FIXES_OUTPUT" << 'NOTFOUND'

### Fix Cannot Find Type Errors

**Problem:** Swift compiler cannot resolve type names.

**Solutions:**
1. Add missing import statement
2. Check spelling
3. Verify module is built

**Files affected:**

NOTFOUND

    grep "cannot find type" "$RAW_OUTPUT" | \
        sed -E 's/^([^:]+):.*cannot find type.*$/- `\1`/' | \
        sort -u | \
        head -10 >> "$FIXES_OUTPUT"
fi

# Suggest fixes for argument mismatches
if [ "$ARGUMENT_COUNT" -gt 0 ]; then
    cat >> "$FIXES_OUTPUT" << 'ARGUMENTS'

### Fix Argument Mismatches

**Problem:** Function/initializer signatures have changed.

**Action:** Update call sites to match new signatures.

**Examples:**

ARGUMENTS

    grep "argument.*to parameter\|missing argument\|extra argument" "$RAW_OUTPUT" | \
        head -10 | \
        sed -E 's/^([^:]+):([0-9]+):.*$/- Line \2 in `\1`/' >> "$FIXES_OUTPUT"
fi

# Add general recommendations
cat >> "$FIXES_OUTPUT" << 'FOOTER'

## General Fix Strategy

### 1. Priority Order
Fix errors in this order for fastest resolution:
1. **Import statements** - Add missing imports first
2. **Type ambiguities** - Qualify ambiguous types
3. **Missing members** - Update to new API
4. **Argument mismatches** - Fix function calls

### 2. Batch Fixes

For ambiguous types, create a typealias file:
```swift
// Sources/AnigmaAppMac/TypeAliases.swift
import AnigmaHostMac
import ExportCore

// Resolve ambiguities
typealias PipelineStage = AnigmaHostMac.PipelineStage
typealias PipelineProtocol = ExportCore.PipelineStages
```

### 3. Find and Replace Patterns

```bash
# Example: Fix PipelineStage references
find Sources/AnigmaAppMac -name "*.swift" -exec sed -i '' 's/\bPipelineStage\b/AnigmaHostMac.PipelineStage/g' {} \;
```

### 4. Verify Each Fix

After each fix:
```bash
swift build --product anigma-app 2>&1 | grep "error:" | wc -l
```

Watch the error count decrease!

## Module-Specific Issues

### Model Registry API Changes

The Model Registry API has changed. Update usage:

**Old API:**
```swift
let model = try await modelRegistry.get(id)
let spec = model.spec
```

**New API:**
```swift
let entry = try await modelRegistry.getModel(id: id)
// Use entry properties directly: entry.taskKind, entry.backendFormat
```

### RunSpec Changes

Check `ContractsCore` for the current `RunSpec` initializer signature.

### ModelBackendCompatibility

Check if enum cases changed. Update references accordingly.

## Next Steps

1. Review this file: `cat suggested_fixes.md`
2. Start with Priority #1 fixes
3. Re-run build after each batch of fixes
4. Track progress: errors should decrease with each iteration

## Useful Commands

```bash
# Re-capture errors after fixes
bash capture_build_errors.sh

# Count remaining errors
grep -c "error:" build_errors_raw.txt

# Find specific pattern in source
grep -r "PATTERN" Sources/AnigmaAppMac/

# Build specific target
swift build --product anigma-app
```

FOOTER

echo "✅ Fix suggestions generated!"
echo ""
echo "📄 Review the suggestions:"
echo "   cat $FIXES_OUTPUT"
echo ""
echo "   or"
echo ""
echo "   open $FIXES_OUTPUT"
echo ""
