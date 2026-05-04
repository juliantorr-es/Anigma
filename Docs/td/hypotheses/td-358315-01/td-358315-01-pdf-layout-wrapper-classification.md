# TD-358315-01: PDFLayoutExtractWrapper Classification Hypothesis

**TD ID:** td-358315-01  
**Parent TD:** td-358315  
**Created:** 2026-05-03  
**Status:** HYPOTHESIS  
**Task:** Resolve PDFLayoutExtractWrapper compilation errors blocking BackendReadinessContractTests

---

## Known Facts

### Current State
- **BackendReadinessContractTests target:** CLEAN (exit_code=0, warning_count=0)
- **BackendReadinessContractTests test:** FAILED (exit_code=1, warning_count=9)
- **td-7c0153 Phase 2:** ACCEPTED FOR ARCHITECTURE - PDFium linkage isolated to PDF-owned targets
- **BackendReadiness has NO directed path** to PDFNative, PDFSidecarNativeShims, or PDFSidecarExecutable

### PDFLayoutExtractWrapper.swift Location
- File: `anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift`
- Target: Part of AnigmaPipeline (in AnigmaCore package)

---

## Exact Errors

```
Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift:37:51: error: 'PageLayout' is not a member type of class 'LayoutEngineCapsule.LayoutEngineCapsule'
Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift:21:43: error: cannot find type 'Data' in scope
Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift:40:59: error: 'LayoutEngineConfig' is not a member type of class 'LayoutEngineCapsule.LayoutEngineCapsule'
Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift:31:44: error: cannot find type 'Data' in scope
Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift:38:52: error: 'TextSegment' is not a member type of class 'LayoutEngineCapsule.LayoutEngineCapsule'
Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift:39:52: error: 'BoundingBox' is not a member type of class 'LayoutEngineCapsule.LayoutEngineCapsule'
Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift:41:58: error: 'LayoutEngineError' is not a member type of class 'LayoutEngineCapsule.LayoutEngineCapsule'
Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift:32:47: error: type 'LayoutEngineCapsuleWrapper' has no member 'extractText'
```

### Missing Types Summary

| Type | Referenced As | Exists In | Status |
|------|--------------|-----------|--------|
| `PageLayout` | `LayoutEngineCapsule.PageLayout` | `LayoutEngineCapsule.LayoutEngineCapsuleWrapper` | **Type path incorrect** |
| `TextSegment` | `LayoutEngineCapsule.TextSegment` | `LayoutEngineCapsule.LayoutEngineCapsuleWrapper` | **Type path incorrect** |
| `BoundingBox` | `LayoutEngineCapsule.BoundingBox` | `LayoutEngineCapsule.LayoutEngineCapsuleWrapper` | **Type path incorrect** |
| `LayoutEngineConfig` | `LayoutEngineCapsule.LayoutEngineConfig` | `LayoutEngineCapsule.LayoutEngineCapsuleWrapper` | **Type path incorrect** |
| `LayoutEngineError` | `LayoutEngineCapsule.LayoutEngineError` | **NOWHERE** | **Does not exist** |
| `Data` | Swift Foundation type | Foundation | **Missing import** |
| `extractText` | `LayoutEngineCapsuleWrapper.extractText` | **NOWHERE** | **Does not exist** |

---

## Ownership Analysis

### Types that DO Exist (in LayoutEngineCapsule.LayoutEngineCapsuleWrapper)

1. **PageLayout** - `anigma/Packages/LayoutEngineCapsule/Sources/LayoutEngineCapsule/LayoutEngineCapsuleWrapper.swift:314`
   ```swift
   public struct PageLayout: Sendable, Codable {
       public let pageIndex: UInt32
       public let segments: [TextSegment]
       // ...
   }
   ```

2. **TextSegment** - `anigma/Packages/LayoutEngineCapsule/Sources/LayoutEngineCapsule/LayoutEngineCapsuleWrapper.swift:247`
   ```swift
   public struct TextSegment: Sendable, Codable {
       public let bbox: BoundingBox
       public let text: String
       // ...
   }
   ```

3. **BoundingBox** - `anigma/Packages/LayoutEngineCapsule/Sources/LayoutEngineCapsule/LayoutEngineCapsuleWrapper.swift:226`
   ```swift
   public struct BoundingBox: Sendable, Codable {
       public var left: Double
       public var top: Double
       public var right: Double
       public var bottom: Double
   }
   ```

4. **LayoutEngineConfig** - `anigma/Packages/LayoutEngineCapsule/Sources/LayoutEngineCapsule/LayoutEngineCapsuleWrapper.swift:210`
   ```swift
   public struct LayoutEngineConfig: Sendable, Codable {
       public var determinismTier: Int
       public var flags: UInt32
   }
   ```

### Types that DO NOT Exist

1. **LayoutEngineError** - Not found anywhere in LayoutEngineCapsule package
   - PDFLayoutExtractWrapper.swift line 41: `public typealias LayoutEngineError = LayoutEngineCapsule.LayoutEngineError`
   - This typealias references a non-existent type

2. **extractText method** - Not found in LayoutEngineCapsuleWrapper
   - PDFLayoutExtractWrapper.swift line 32: `return try LayoutEngineCapsuleWrapper.extractText(data, config: config)`
   - LayoutEngineCapsuleWrapper has `analyzePDF` but NOT `extractText`
   - LayoutEngineCapsule has `analyzePDF` but NOT `extractText`

### Missing Import

1. **Data** - Swift Foundation type, needs `import Foundation`
   - Used in function parameters but Foundation is not imported in PDFLayoutExtractWrapper.swift

---

## PDFLayoutExtractWrapper.swift Content Analysis

```swift
// File: anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift

import AnigmaFoundation
import AnigmaPrimitives
import LayoutEngineCapsule

public enum PDFLayoutExtractWrapper {
    public static func analyzePDF(_ data: Data, config: LayoutEngineConfig) throws -> [PageLayout] {
        return try LayoutEngineCapsuleWrapper.analyzePDF(data, config: config)
    }
    
    public static func extractText(_ data: Data, config: LayoutEngineConfig) throws -> String {
        return try LayoutEngineCapsuleWrapper.extractText(data, config: config)
    }
}

// Type re-exports
public typealias PageLayout = LayoutEngineCapsule.PageLayout
public typealias TextSegment = LayoutEngineCapsule.TextSegment
public typealias BoundingBox = LayoutEngineCapsule.BoundingBox
public typealias LayoutEngineConfig = LayoutEngineCapsule.LayoutEngineConfig
public typealias LayoutEngineError = LayoutEngineCapsule.LayoutEngineError
```

### Problems Identified

1. **Import missing**: `import Foundation` (for `Data` type)
2. **Wrong type paths**: All typealiases reference `LayoutEngineCapsule.X` but types are in `LayoutEngineCapsule.LayoutEngineCapsuleWrapper`
3. **Non-existent method**: `LayoutEngineCapsuleWrapper.extractText` does not exist
4. **Non-existent type**: `LayoutEngineCapsule.LayoutEngineError` does not exist

---

## Classification Questions

### Q1: Does PDFLayoutExtractWrapper belong in a PDF-specific target rather than generic BackendReadiness?

**Hypothesis: YES**

PDFLayoutExtractWrapper:
- Calls `LayoutEngineCapsuleWrapper` which depends on native PDF layout engine
- Uses PDF-specific types (PageLayout, TextSegment, BoundingBox, LayoutEngineConfig)
- Is named "PDF" Layout Extract Wrapper
- Has a comment: "Wrapper for PDF layout extraction functionality to isolate LayoutEngineCapsule dependency"

The wrapper is **PDF-specific implementation**, not generic backend functionality. It should **NOT** be in AnigmaPipeline/Contracts if AnigmaPipeline is part of generic BackendReadiness.

### Q2: Are the types defined in LayoutEngineCapsule but not imported?

**Partially YES, but paths are wrong**

The types exist in `LayoutEngineCapsule.LayoutEngineCapsuleWrapper`, but the typealiases reference `LayoutEngineCapsule.X`. Since LayoutEngineCapsuleWrapper is not public or re-exported by LayoutEngineCapsule, these types are not accessible via `LayoutEngineCapsule.PageLayout`.

### Q3: Are the missing types stale/renamed?

**NO** - The types exist with the same names, just in a different nested path (LayoutEngineCapsuleWrapper, not LayoutEngineCapsule).

### Q4: Is PDFLayoutExtractWrapper compiling in the wrong target?

**YES**

PDFLayoutExtractWrapper is in `AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/` which suggests it's part of generic pipeline contracts. However:
- It directly depends on LayoutEngineCapsule (PDF-specific)
- It uses PDF-specific types
- It calls PDF-specific native functionality

This is **wrong ownership** for a generic contract.

### Q5: Is the correct fix A, B, C, D, or E?

**Option D: Extract portable contract types** - **NOT APPLICABLE**
- The types already exist and are portable (Sendable, Codable)
- The issue is accessibility, not type design

**Option B: Add missing import/dependency** - **PARTIAL FIX ONLY**
- `- import Foundation` would fix the `Data` type errors
- But would NOT fix the wrong type paths or missing extractText method

**Option C: Update stale API names** - **NOT APPLICABLE**
- The API names are not stale, the references are wrong

**Option A: Add missing import/dependency** - **INSUFFICIENT**
- See above

**Option E: Remove stale wrapper from generic readiness** - **RECOMMENDED**

The cleanest fix is to **move PDFLayoutExtractWrapper out of generic BackendReadiness** because:
1. It's PDF-specific implementation (calls LayoutEngineCapsuleWrapper)
2. It depends on non-portable PDF types
3. It cannot be made to work without pulling PDF-specific dependencies into generic contracts
4. The type paths are fundamentally wrong and cannot be fixed without exposing LayoutEngineCapsuleWrapper types through LayoutEngineCapsule

Alternatively:
- Move it to a PDF-specific target (e.g., PDFLayoutExtract)
- Or exclude it from BackendReadinessContractTests

---

## Proposed Fix: Option E (Remove/Move from Generic Readiness)

### Rationale

1. **PDFSidecarExecutable is NOT part of generic BackendReadiness** (constraint from td-7c0153)
2. **PDFium types should NOT leak into contract modules** (constraint from td-7c0153)
3. **LayoutEngineCapsuleWrapper is PDF-specific native functionality**
4. **PDFLayoutExtractWrapper directly depends on LayoutEngineCapsuleWrapper**

Therefore: **PDFLayoutExtractWrapper should NOT be in generic BackendReadiness contracts.**

### Steps

1. **Check if PDFLayoutExtractWrapper is used anywhere else**
   ```bash
   rg -n "PDFLayoutExtractWrapper" anigma/Packages --type swift
   ```

2. **If only used in PDF-specific code:**
   - Move PDFLayoutExtractWrapper.swift to a PDF-specific target
   - Update imports in PDF-specific code to use the new location

3. **If used in generic code:**
   - Create a portable contract interface
   - Move PDF-specific implementation to PDF target
   - Keep only the contract interface in generic code

4. **Fix the immediate type path issues:**
   - Change `LayoutEngineCapsule.X` to `LayoutEngineCapsule.LayoutEngineCapsuleWrapper.X`
   - BUT: LayoutEngineCapsuleWrapper may not be publicly accessible

5. **Fix missing extractText:**
   - LayoutEngineCapsuleWrapper does NOT have extractText method
   - Either add it to LayoutEngineCapsuleWrapper, OR
   - Remove the extractText call from PDFLayoutExtractWrapper

6. **Fix LayoutEngineError:**
   - Define LayoutEngineError in LayoutEngineCapsule, OR
   - Change the typealias to reference CapsuleNativeError (which is what LayoutEngineCapsuleWrapper actually throws)

---

## Decision Matrix

| Option | Fixes Data | Fixes Type Paths | Fixes extractText | Fixes LayoutEngineError | Keeps Architecture Clean | Risk |
|--------|-----------|------------------|------------------|------------------------|--------------------------|------|
| A. Add imports | ✅ | ❌ | ❌ | ❌ | ❌ | Low (insufficient) |
| B. Move to PDF target | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | Medium |
| C. Make types accessible | ❌ | ✅ | ❌ | ❌ | ❌ | Medium |
| D. Extract contracts | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | High |
| E. Remove from generic | ✅ | ✅ | ✅ | ✅ | ✅ | **Low** |

**Recommended: E + B** - Remove from generic BackendReadiness AND move to PDF-specific target

---

## Implementation Plan

### Phase 1: Research (THIS DOCUMENT)
- [x] Identify exact errors
- [x] Locate type definitions
- [x] Classify ownership issue

### Phase 2: Validate Usage
```bash
# Find all usages of PDFLayoutExtractWrapper
rg -n "PDFLayoutExtractWrapper" anigma/ --type swift

# Find all usages of the missing types
rg -n "PageLayout|TextSegment|BoundingBox|LayoutEngineConfig|LayoutEngineError" anigma/Packages/AnigmaPipeline --type swift
```

### Phase 3: Decide Ownership
Based on usage analysis:
- If PDFLayoutExtractWrapper is **only used by PDF-specific code**: Move to PDF-specific target
- If PDFLayoutExtractWrapper is **used by generic code**: Extract portable interface, move implementation to PDF target

### Phase 4: Implement Fix

**Most likely:** Move PDFLayoutExtractWrapper.swift to a PDF-specific package/target and update references.

---

## Files Likely Affected

- `anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift` - Move or fix
- Possibly: `anigma/Packages/LayoutEngineCapsule/Sources/LayoutEngineCapsule/LayoutEngineCapsule.swift` - Add extractText method?
- Possibly: Package.swift - Update target dependencies
- Possibly: Files that import/use PDFLayoutExtractWrapper

---

## Architecture Constraints

- Do NOT link PDFium into BackendReadiness
- Do NOT expose PDFium types in contract modules
- Do NOT create @_exported imports
- Do NOT create fake stubs
- Do NOT make PDFSidecarExecutable part of generic BackendReadiness
- Do NOT broaden umbrella imports
- Do NOT add package graph edges without pre/post graph evidence

---

## Validation Results

### Usage Analysis

**Call sites of PDFLayoutExtractWrapper:**
```
anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractContract.swift:220:
    pageLayouts = try PDFLayoutExtractWrapper.analyzePDF(input.payload.rawData, config: config)
```

**Only one call site:** PDFLayoutExtractContract.swift (also in AnigmaPipeline)

### LayoutEngineCapsule Public Interface

**LayoutEngineCapsule.swift** (`anigma/Packages/LayoutEngineCapsule/Sources/LayoutEngineCapsule/LayoutEngineCapsule.swift`):
- Has `LayoutEngineCapsule` class (public)
- Uses `LayoutEngineConfig` (not public in LayoutEngineCapsule module)
- Uses `PageLayout` (not public in LayoutEngineCapsule module)
- Does NOT re-export LayoutEngineCapsuleWrapper types

**LayoutEngineCapsuleWrapper.swift** (`anigma/Packages/LayoutEngineCapsule/Sources/LayoutEngineCapsule/LayoutEngineCapsuleWrapper.swift`):
- Defines `PageLayout` (line 314) - **NOT public**
- Defines `TextSegment` (line 247) - **NOT public**
- Defines `BoundingBox` (line 226) - **NOT public**
- Defines `LayoutEngineConfig` (line 210) - **NOT public**
- Does NOT define `LayoutEngineError`
- Does NOT have `extractText` method

### Key Finding

**LayoutEngineCapsule does NOT publicly export the types from LayoutEngineCapsuleWrapper.**

Therefore, **AnigmaPipeline CANNOT access PageLayout, TextSegment, BoundingBox, LayoutEngineConfig** from LayoutEngineCapsule, even though AnigmaPipeline depends on LayoutEngineCapsule.

This means PDFLayoutExtractWrapper.swift is **fundamentally broken** in its current location because it references types that are not accessible.

### Options to Fix (Revised)

#### Option A: Make LayoutEngineCapsuleWrapper types public
- Change `struct PageLayout` to `public struct PageLayout` in LayoutEngineCapsuleWrapper.swift
- Change `struct TextSegment` to `public struct TextSegment`
- Change `struct BoundingBox` to `public struct BoundingBox`
- Change `struct LayoutEngineConfig` to `public struct LayoutEngineConfig`
- Add `public typealias LayoutEngineError = CapsuleNativeError` or similar
- Add `extractText` method to LayoutEngineCapsule (public wrapper)
- **Risk:** Makes PDF-specific types accessible to all LayoutEngineCapsule consumers
- **Constraint:** Would this violate tier principles? LayoutEngineCapsule is already in the dependency chain

#### Option B: Move PDFLayoutExtractWrapper + PDFLayoutExtractContract to PDF-specific target
- Create new target: PDFLayoutExtract (depends on LayoutEngineCapsule)
- Move PDFLayoutExtractWrapper.swift to PDFLayoutExtract target
- Move PDFLayoutExtractContract.swift to PDFLayoutExtract target
- Remove these files from AnigmaPipeline
- **Risk:** Changes architecture, may affect other pipeline contracts
- **Benefit:** Correct ownership - PDF-specific code in PDF-specific target

#### Option C: Add extractText to LayoutEngineCapsule
- LayoutEngineCapsuleWrapper has `analyzePDF` but NOT `extractText`
- LayoutEngineCapsule has `analyzePDF` but NOT `extractText`
- Need to add this method somewhere accessible
- **But:** Doesn't solve the type accessibility issue

#### Option D: Fix type paths + make types accessible
- Change `LayoutEngineCapsule.X` to `LayoutEngineCapsule.LayoutEngineCapsuleWrapper.X` in PDFLayoutExtractWrapper
- **But:** LayoutEngineCapsuleWrapper is NOT a public module - can't access via this path

---

## Revised Classification

### Primary Issue: **Wrong Target Ownership**

PDFLayoutExtractWrapper and PDFLayoutExtractContract are PDF-specific code in a generic target (AnigmaPipeline). The types they need from LayoutEngineCapsule are NOT publicly accessible.

### Root Causes:

1. **Type accessibility**: LayoutEngineCapsuleWrapper types are NOT public
2. **Wrong type paths**: Even if they were public, the paths are wrong
3. **Missing method**: `extractText` doesn't exist
4. **Missing type**: `LayoutEngineError` doesn't exist
5. **Missing import**: `Foundation` not imported (for `Data`)

### Recommended Fix: **Option B** (Move to PDF-specific target)

Move PDFLayoutExtractWrapper.swift and PDFLayoutExtractContract.swift to a PDF-specific target that:
1. Depends on LayoutEngineCapsule
2. Can access LayoutEngineCapsuleWrapper types (either by making them public or by being in the same module)
3. Does NOT pull PDF-specific dependencies into generic BackendReadiness

OR **Option A** (Make types public):
1. Make LayoutEngineCapsuleWrapper types public
2. Fix type paths in PDFLayoutExtractWrapper
3. Fix missing method and type
4. Add Foundation import

** Lean towards Option B** because:
- It's architecturally cleaner (PDF-specific code in PDF-specific target)
- Doesn't expose LayoutEngineCapsuleWrapper types to all consumers
- Aligns with td-7c0153 principle: PDF-specific functionality should be isolated

---

## Decision

**Move PDFLayoutExtractWrapper.swift and PDFLayoutExtractContract.swift to a PDF-specific target.**

This is the cleanest fix that:
- Resolves the compilation errors
- Maintains PDFium isolation (td-7c0153)
- Doesn't expose PDF-specific types to generic contracts
- Follows the principle "each capability owns its native shims"

---

## Hypothesis Conclusion

**Primary Issue:** PDFLayoutExtractWrapper is PDF-specific implementation incorrectly placed in generic BackendReadiness contracts.

**Root Cause:** Wrong target ownership + wrong type paths + missing method + missing type + missing import

**Recommended Fix:** Move PDFLayoutExtractWrapper out of generic BackendReadiness into a PDF-specific target, OR extract a portable contract interface and move the implementation.

**Do NOT:** Add broad dependencies to make LayoutEngineCapsuleWrapper types accessible from generic contracts. This would violate the PDFium isolation principle from td-7c0153.

---

*Document Status: HYPOTHESIS - AWAITING VALIDATION*
*Next Step: Validate usage with graph audit*
