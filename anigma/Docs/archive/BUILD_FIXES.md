# Build Errors and Warnings Fix Guide

This document provides step-by-step instructions to fix all errors and warnings in the Anigma project.

## Table of Contents
1. [Critical Issues (Swift 6 Errors)](#critical-issues-swift-6-errors)
2. [Database Actor Warnings](#database-actor-warnings)
3. [Unused Variable Warnings](#unused-variable-warnings)
4. [Unreachable Code Warnings](#unreachable-code-warnings)
5. [Verification Steps](#verification-steps)

---

## Critical Issues (Swift 6 Errors)

### Issue: Actor Convenience Initializer
**Severity:** 🔴 **CRITICAL** - Will be an error in Swift 6  
**File:** `Sources/AnigmaCore/Pipeline/PipelineRunner.swift`  
**Line:** 62

#### Problem
```swift
public convenience init(engine: GrapheneEngine) async throws {
```

The `convenience` keyword is not allowed on actor initializers in Swift 6.

#### Fix
**Step 1:** Open `Sources/AnigmaCore/Pipeline/PipelineRunner.swift`

**Step 2:** Find line 62 (around the convenience initializer)

**Step 3:** Remove the `convenience` keyword:
```swift
// Before:
public convenience init(engine: GrapheneEngine) async throws {

// After:
public init(engine: GrapheneEngine) async throws {
```

**Step 4:** Save the file

---

## Database Actor Warnings

### Issue: Unnecessary `await` Keywords
**Severity:** 🟡 **WARNING** - 30+ instances  
**Files:**
- `Sources/DatabaseCore/DatabaseActor+LedgerSegmentation.swift`
- `Sources/DatabaseCore/DatabaseActor+Maintenance.swift`
- `Sources/DatabaseCore/DatabaseActor+GarbageCollection.swift`

#### Problem
The `execute()` method is synchronous but marked with `await`, causing compiler warnings.

#### Fix Method 1: Search and Replace (Recommended)

**Step 1:** Use your editor's search and replace feature

**Step 2:** In the `Sources/DatabaseCore/` directory, search for:
```swift
try await execute(
```

**Step 3:** Replace with:
```swift
try execute(
```

**Step 4:** Review each change to ensure it's in the correct context

#### Fix Method 2: Manual Fixes

##### File: `DatabaseActor+LedgerSegmentation.swift`

**Lines to fix:** 9, 22, 23, 24, 87, 107, 110, 132, 149, 174, 188, 189, 190, 191, 194

**Example - Line 9:**
```swift
// Before:
try await execute("""
    CREATE TABLE IF NOT EXISTS ledger_segments (
        segment_id TEXT PRIMARY KEY,
        ...
""")

// After:
try execute("""
    CREATE TABLE IF NOT EXISTS ledger_segments (
        segment_id TEXT PRIMARY KEY,
        ...
""")
```

**Example - Lines 22-24:**
```swift
// Before:
try await execute("CREATE INDEX IF NOT EXISTS idx_segments_created ON ledger_segments(created_at)")
try await execute("CREATE INDEX IF NOT EXISTS idx_segments_status ON ledger_segments(status)")
try await execute("CREATE INDEX IF NOT EXISTS idx_segments_closed ON ledger_segments(closed_at)")

// After:
try execute("CREATE INDEX IF NOT EXISTS idx_segments_created ON ledger_segments(created_at)")
try execute("CREATE INDEX IF NOT EXISTS idx_segments_status ON ledger_segments(status)")
try execute("CREATE INDEX IF NOT EXISTS idx_segments_closed ON ledger_segments(closed_at)")
```

**Example - Line 110:**
```swift
// Before:
try await execute("ALTER TABLE master_ledger RENAME TO master_ledger_legacy_backup")

// After:
try execute("ALTER TABLE master_ledger RENAME TO master_ledger_legacy_backup")
```

##### File: `DatabaseActor+Maintenance.swift`

**Lines to fix:** 9, 21, 32, 33, 143

**Example - Line 9:**
```swift
// Before:
try await execute("""
    CREATE TABLE IF NOT EXISTS maintenance_history (
        operation_id TEXT PRIMARY KEY,
        ...
""")

// After:
try execute("""
    CREATE TABLE IF NOT EXISTS maintenance_history (
        operation_id TEXT PRIMARY KEY,
        ...
""")
```

**Example - Lines 32-33:**
```swift
// Before:
try await execute("CREATE INDEX IF NOT EXISTS idx_maintenance_operation_type ON maintenance_history(operation_type)")
try await execute("CREATE INDEX IF NOT EXISTS idx_maintenance_started_at ON maintenance_history(started_at)")

// After:
try execute("CREATE INDEX IF NOT EXISTS idx_maintenance_operation_type ON maintenance_history(operation_type)")
try execute("CREATE INDEX IF NOT EXISTS idx_maintenance_started_at ON maintenance_history(started_at)")
```

##### File: `DatabaseActor+GarbageCollection.swift`

**Line to fix:** 41

```swift
// Before:
try await execute("""
    INSERT INTO invariant_checks (
        check_id, timestamp, passed, details_json,
        ...
""")

// After:
try execute("""
    INSERT INTO invariant_checks (
        check_id, timestamp, passed, details_json,
        ...
""")
```

---

## Unused Variable Warnings

### Issue 1: Unused Variable `currentSegmentDate`
**Severity:** 🟡 **WARNING**  
**File:** `Sources/DatabaseCore/DatabaseActor+LedgerSegmentation.swift`  
**Line:** 54

#### Problem
```swift
var currentSegmentDate: Date?
```
Variable is written to but never read.

#### Fix Options

**Option A - Prefix with underscore (if needed for future use):**
```swift
// Before:
var currentSegmentDate: Date?

// After:
var _currentSegmentDate: Date?  // Silences warning while keeping the variable
```

**Option B - Remove entirely (if not needed):**
```swift
// Before:
var currentSegmentId: String?
var currentSegmentDate: Date?

// After:
var currentSegmentId: String?
// Remove the line entirely
```

---

### Issue 2: Unused Variable `fileHashBefore`
**Severity:** 🟡 **WARNING**  
**File:** `Sources/DatabaseCore/DatabaseActor+MasterLedger.swift`  
**Line:** 129

#### Problem
```swift
let fileHashBefore = fileBeforeData.map { ContentHashing.computeSHA256($0) }
```
Variable is never used after initialization.

#### Fix Options

**Option A - Explicitly discard:**
```swift
// Before:
let preconditionHash = preconditionData.map { ContentHashing.computeSHA256($0) }
let fileHashBefore = fileBeforeData.map { ContentHashing.computeSHA256($0) }

// After:
let preconditionHash = preconditionData.map { ContentHashing.computeSHA256($0) }
let _ = fileBeforeData.map { ContentHashing.computeSHA256($0) }
```

**Option B - Remove entirely (if computation not needed):**
```swift
// Before:
let preconditionHash = preconditionData.map { ContentHashing.computeSHA256($0) }
let fileHashBefore = fileBeforeData.map { ContentHashing.computeSHA256($0) }

// After:
let preconditionHash = preconditionData.map { ContentHashing.computeSHA256($0) }
// Remove the line entirely if the computation isn't needed
```

---

### Issue 3: Unused Binding `selectedCandidateId`
**Severity:** 🟡 **WARNING**  
**File:** `Sources/AnigmaCore/Reasoning/MakerEngine.swift`  
**Line:** 269

#### Problem
```swift
if let selectedCandidateId = decision.selectedCandidate {
    guard let selectedCandidate else {
        throw MakerEngineError.selectedCandidateNotFound
    }
    // ... selectedCandidateId is never used
}
```

#### Fix
Replace optional binding with nil check:

```swift
// Before:
if let selectedCandidateId = decision.selectedCandidate {
    guard let selectedCandidate else {
        throw MakerEngineError.selectedCandidateNotFound
    }
    // ...
}

// After:
if decision.selectedCandidate != nil {
    guard let selectedCandidate else {
        throw MakerEngineError.selectedCandidateNotFound
    }
    // ...
}
```

---

### Issue 4: Unused Variable `determinismContext`
**Severity:** 🟡 **WARNING**  
**File:** `Sources/AnigmaCore/Reasoning/MakerEngine.swift`  
**Line:** 1047

#### Problem
```swift
let determinismContext = enhancementContext.determinismContext
```
Variable is never used after initialization.

#### Fix Options

**Option A - Explicitly discard:**
```swift
// Before:
let inputHash = enhancementContext.inputHash
let deterministicStepId = enhancementContext.deterministicStepId
let determinismContext = enhancementContext.determinismContext

// After:
let inputHash = enhancementContext.inputHash
let deterministicStepId = enhancementContext.deterministicStepId
let _ = enhancementContext.determinismContext
```

**Option B - Remove entirely:**
```swift
// Before:
let inputHash = enhancementContext.inputHash
let deterministicStepId = enhancementContext.deterministicStepId
let determinismContext = enhancementContext.determinismContext

// After:
let inputHash = enhancementContext.inputHash
let deterministicStepId = enhancementContext.deterministicStepId
// Remove the line entirely
```

---

## Unreachable Code Warnings

### Issue: Unreachable Default Case
**Severity:** 🟡 **WARNING**  
**File:** `Sources/AnigmaCore/Analytics/ReflexiveAnalytics.swift`  
**Line:** 369

#### Problem
```swift
case .resourceExhausted, .timeout:
    return .resource
default:  // ⚠️ This default case is unreachable
    return .other
```

All enum cases are already covered, making the default case unreachable.

#### Fix Options

**Option A - Remove the default case (if all cases truly covered):**
```swift
// Before:
case .resourceExhausted, .timeout:
    return .resource
default:
    return .other

// After:
case .resourceExhausted, .timeout:
    return .resource
```

**Option B - Use @unknown default (for future-proofing):**
```swift
// Before:
case .resourceExhausted, .timeout:
    return .resource
default:
    return .other

// After:
case .resourceExhausted, .timeout:
    return .resource
@unknown default:
    return .other
```

**Recommendation:** Use Option B (`@unknown default`) if you want to handle future enum cases that might be added.

---

## Verification Steps

After applying all fixes, verify the build is clean:

### Step 1: Clean Build
```bash
cd /path/to/anigma
swift package clean
```

Or in Xcode:
```
Product → Clean Build Folder (Shift + Cmd + K)
```

### Step 2: Rebuild
```bash
swift build
```

Or in Xcode:
```
Product → Build (Cmd + B)
```

### Step 3: Check for Remaining Issues

Look for:
- ✅ **0 errors**
- ✅ **Significantly fewer warnings** (ideally 0)
- ✅ **Successful build completion**

### Step 4: Run Tests
```bash
swift test
```

Or in Xcode:
```
Product → Test (Cmd + U)
```

---

## Summary of Changes

| Issue Type | File Count | Line Count | Priority |
|-----------|-----------|-----------|----------|
| Actor convenience initializer | 1 | 1 | 🔴 Critical |
| Unnecessary await | 3 | 30+ | 🟡 Medium |
| Unused variables | 2 | 4 | 🟡 Low |
| Unreachable code | 1 | 1 | 🟡 Low |

---

## Quick Reference: Files to Modify

1. ✅ **`Sources/AnigmaCore/Pipeline/PipelineRunner.swift`**
   - Line 62: Remove `convenience` keyword

2. ✅ **`Sources/DatabaseCore/DatabaseActor+LedgerSegmentation.swift`**
   - Lines 9, 22-24, 87, 107, 110, 132, 149, 174, 188-194: Remove `await`
   - Line 54: Fix unused variable `currentSegmentDate`

3. ✅ **`Sources/DatabaseCore/DatabaseActor+Maintenance.swift`**
   - Lines 9, 21, 32-33, 143: Remove `await`

4. ✅ **`Sources/DatabaseCore/DatabaseActor+GarbageCollection.swift`**
   - Line 41: Remove `await`

5. ✅ **`Sources/DatabaseCore/DatabaseActor+MasterLedger.swift`**
   - Line 129: Fix unused variable `fileHashBefore`

6. ✅ **`Sources/AnigmaCore/Reasoning/MakerEngine.swift`**
   - Line 269: Fix unused binding `selectedCandidateId`
   - Line 1047: Fix unused variable `determinismContext`

7. ✅ **`Sources/AnigmaCore/Analytics/ReflexiveAnalytics.swift`**
   - Line 369: Remove or annotate unreachable default case

---

## Additional Notes

### Module Maps
The following module.modulemap files have been created for C/C++ interop:

1. ✅ `Packages/TableExtractionCapsule/Native/include/module.modulemap`
2. ✅ `Packages/MathOCRCapsule/Native/include/module.modulemap`
3. ✅ `Packages/CitationExtractionCapsule/Native/include/module.modulemap`
4. ✅ `Packages/ReferenceResolutionCapsule/Native/include/module.modulemap`
5. ✅ `Packages/DiffCapsule/Native/include/module.modulemap`

These should be automatically picked up by the Swift Package Manager.

### If Header Files Are Named Differently

If you encounter errors about missing headers, check the actual header file names:

```bash
ls -la Packages/TableExtractionCapsule/Native/include/
ls -la Packages/MathOCRCapsule/Native/include/
ls -la Packages/CitationExtractionCapsule/Native/include/
ls -la Packages/ReferenceResolutionCapsule/Native/include/
ls -la Packages/DiffCapsule/Native/include/
```

Then update the corresponding `module.modulemap` file with the correct header name.

---

## Need Help?

If you encounter any issues:

1. **Check the specific error message** - It will guide you to the exact line
2. **Ensure you're in the correct directory** - All paths are relative to the project root
3. **Clean and rebuild** after each major change
4. **Verify module maps are in place** - They should be in the Native/include directories

---

**Document Version:** 1.0  
**Last Updated:** February 6, 2026  
**Project:** Anigma  
