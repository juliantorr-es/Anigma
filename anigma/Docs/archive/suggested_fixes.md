# Suggested Fixes for Anigma Build Errors

This document contains automated fix suggestions based on build error analysis.

## Quick Actions


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

