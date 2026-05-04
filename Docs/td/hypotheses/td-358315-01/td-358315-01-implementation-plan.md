# TD-358315-01 Implementation Plan

**TD ID:** td-358315-01  
**Parent TD:** td-358315  
**Status:** IMPLEMENTATION PLANNED  
**Blocker:** Pre-existing Package.swift syntax errors in repository HEAD

---

## Summary from Research

### Key Findings

1. **PDFLayoutExtractContract.swift** has wrong import:
   - Current: `import PDFLayoutExtract` (non-existent module)
   - Should be: `import LayoutEngineCapsule`

2. **PDFLayoutExtractWrapper.swift** references non-accessible types:
   - `LayoutEngineCapsule.PageLayout` → should be from LayoutEngineCapsule module
   - But LayoutEngineCapsuleWrapper types (PageLayout, TextSegment, BoundingBox, LayoutEngineConfig) are `internal`
   - AnigmaPipeline is a different module, cannot access `internal` types

3. **LayoutEngineCapsule module structure:**
   - `LayoutEngineCapsule.swift` - Public capsule class
   - `LayoutEngineCapsuleWrapper.swift` - Internal implementation with types
   - Same Swift module → types accessible within module, NOT outside

4. **PDFLayoutExtractWrapper is only used by:** PDFLayoutExtractContract.swift (line 220)

---

## Implementation Plan

### Step 1: Fix Import Regression (IMMEDIATE)

**File:** `anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractContract.swift`

Change line 16:
```swift
import PDFLayoutExtract  // WRONG - module doesn't exist
```
to:
```swift
import LayoutEngineCapsule  // CORRECT - the actual module
```

**But this alone won't fix it** because LayoutEngineCapsule types are internal.

---

### Step 2: Create PDFLayoutExtract Target

**New Target in anigma/Package.swift:**
```swift
.target(
    name: "PDFLayoutExtract",
    dependencies: ["LayoutEngineCapsule"],
    path: "Packages/PDFLayoutExtract/Sources",
    exclude: [],
    swiftSettings: strictConcurrencySettings
),
```

**Directory Structure:**
```
Packages/PDFLayoutExtract/
└── Sources/
    ├── PDFLayoutExtractWrapper.swift  (moved from AnigmaPipeline)
    └── PDFLayoutExtractContract.swift   (moved from AnigmaPipeline)
```

---

### Step 3: Move Files

**Move:**
- `anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift` → `anigma/Packages/PDFLayoutExtract/Sources/PDFLayoutExtractWrapper.swift`
- `anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractContract.swift` → `anigma/Packages/PDFLayoutExtract/Sources/PDFLayoutExtractContract.swift`

**Update PDFLayoutExtractContract.swift:**
- Change `import PDFLayoutExtract` to `import LayoutEngineCapsule` (or remove if PDFLayoutExtract imports it)

---

### Step 4: Fix PDFLayoutExtractWrapper.swift

**File:** `anigma/Packages/PDFLayoutExtract/Sources/PDFLayoutExtractWrapper.swift`

**Fixes needed:**

1. **Add Foundation import:**
   ```swift
   import Foundation
   ```

2. **Fix type paths:** Since PDFLayoutExtractWrapper is now in the same target as... wait, no. PDFLayoutExtract would depend on LayoutEngineCapsule. The types would still be internal to LayoutEngineCapsule module.

   **Actually:** We need to move PDFLayoutExtractWrapper INTO LayoutEngineCapsule target, or make the types public.

   **Better approach:** Since PDFLayoutExtract target would depend on LayoutEngineCapsule, and types are internal, we still can't access them.

   **Revised Step 4:** Two sub-options:

   **Option 4A: Move PDFLayoutExtractWrapper INTO LayoutEngineCapsule target**
   - Add PDFLayoutExtractWrapper.swift to LayoutEngineCapsule/Sources/
   - PDFLayoutExtractContract.swift stays in AnigmaPipeline but calls LayoutEngineCapsule directly
   - PDFLayoutExtractContract uses LayoutEngineCapsule public API only

   **Option 4B: Make LayoutEngineCapsuleWrapper types public**
   - Change `struct PageLayout` → `public struct PageLayout` in LayoutEngineCapsuleWrapper.swift
   - Same for TextSegment, BoundingBox, LayoutEngineConfig
   - Add `public typealias LayoutEngineError = CapsuleNativeError`
   - PDFLayoutExtractWrapper stays in AnigmaPipeline
   - **Risk:** Exposes implementation types to all LayoutEngineCapsule consumers

   **Option 4C: All in LayoutEngineCapsule**
   - Move PDFLayoutExtractWrapper.swift to LayoutEngineCapsule/Sources/
   - Move PDFLayoutExtractContract.swift to LayoutEngineCapsule/Sources/
   - Regenerate any build artifacts
   - But PDFLayoutExtractContract depends on AnigmaGovernance, AnigmaJobs, etc. (circular?)

Let me re-check PDFLayoutExtractContract dependencies:
```swift
import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import FoundationContracts
import EvidenceContracts
import Foundation
import PDFLayoutExtract  // currently broken
```

PDFLayoutExtractContract depends on many AnigmaCore things. So Option 4C would create a cycle if LayoutEngineCapsule depends on AnigmaCore.

**Option 4A is blocked:** LayoutEngineCapsule likely depends on AnigmaCore foundations, so we can't put AnigmaPipeline contracts in LayoutEngineCapsule.

**Option 4B analysis:** Making types public in LayoutEngineCapsuleWrapper
- LayoutEngineCapsule is already in the dependency chain of AnigmaPipeline
- Making these types public exposes them to AnigmaPipeline
- But these ARE portable types (Sendable, Codable) representing layout data
- The question is: are they "internal implementation details" or "portable contract types"?

Looking at the types:
- `PageLayout`: Represents layout data (portable)
- `TextSegment`: Represents text with positioning (portable)
- `BoundingBox`: Represents coordinates (portable)
- `LayoutEngineConfig`: Configuration for engine (less portable, but Sendable/Codable)

These could reasonably be public API of LayoutEngineCapsule. The fact that they're in LayoutEngineCapsuleWrapper.swift is an implementation detail.

**However td-7c0153 doctrine says:** "Do NOT expose PDFium types in contract modules"

Are these PDFium types? They're layout types used by the layout engine which uses PDFium internally. But they're Swift structs, not PDFium C++ types.

**Decision: Option 4B is acceptable IF the types are truly portable.**

But there's still the issue of missing `LayoutEngineError` and `extractText`.

---

### Step 5: Check for extractText and LayoutEngineError

From earlier research:
- `LayoutEngineCapsuleWrapper.extractText` does NOT exist
- `LayoutEngineCapsule LayoutEngineError` does NOT exist
- `LayoutEngineCapsuleWrapper` throws `CapsuleNativeError`

**For PDFLayoutExtractWrapper:**

Current:
```swift
public static func extractText(_ data: Data, config: LayoutEngineConfig) throws -> String {
    return try LayoutEngineCapsuleWrapper.extractText(data, config: config)
}

public typealias LayoutEngineError = LayoutEngineCapsule.LayoutEngineError
```

**Fix Options:**

**A. Remove extractText from PDFLayoutExtractWrapper**
- Only keep `analyzePDF` which does exist
- Remove the extractText call site in PDFLayoutExtractContract

**B. Add extractText to LayoutEngineCapsule**
- Implement: `public func extractText(_ data: Data, config: LayoutEngineConfig) throws -> String`
- Would need to add native binding

**C. Define LayoutEngineError**
- In LayoutEngineCapsule: `public enum LayoutEngineError: Error { ... }`
- Or typealias: `public typealias LayoutEngineError = CapsuleNativeError`

---

## Recommended Implementation (Option 4B + Cleanup)

### 1. Make LayoutEngineCapsuleWrapper types public

**File:** `anigma/Packages/LayoutEngineCapsule/Sources/LayoutEngineCapsule/LayoutEngineCapsuleWrapper.swift`

```swift
// Change from:
struct PageLayout: Sendable, Codable { ... }
struct TextSegment: Sendable, Codable { ... }
struct BoundingBox: Sendable, Codable { ... }
struct LayoutEngineConfig: Sendable, Codable { ... }

// To:
public struct PageLayout: Sendable, Codable { ... }
public struct TextSegment: Sendable, Codable { ... }
public struct BoundingBox: Sendable, Codable { ... }
public struct LayoutEngineConfig: Sendable, Codable { ... }
```

**Add LayoutEngineError typealias:**
```swift
public typealias LayoutEngineError = CapsuleNativeError
```

### 2. Add extractText to LayoutEngineCapsule

**File:** `anigma/Packages/LayoutEngineCapsule/Sources/LayoutEngineCapsule/LayoutEngineCapsule.swift`

Add method:
```swift
public func extractText(_ data: Data, config: LayoutEngineConfig) throws -> String {
    // Delegate to wrapper or implement natively
    // For now, if wrapper doesn't have it, need to add to wrapper first
}
```

But LayoutEngineCapsuleWrapper doesn't have extractText. Need to add it there first.

**File:** `anigma/Packages/LayoutEngineCapsule/Sources/LayoutEngineCapsule/LayoutEngineCapsuleWrapper.swift`

Add method (after analyzePDF):
```swift
public func extractText(_ data: Data, config: LayoutEngineConfig) throws -> String {
    // Similar to analyzePDF but returns concatenated text
    // Would need native binding: anigma_layout_engine_capsule_extract_text
    // For now, could return concatenation of text from analyzePDF
    let layouts = try analyzePDF(data, config: config)
    return layouts.flatMap { $0.segments }.map { $0.text }.joined(separator: " ")
}
```

### 3. Fix PDFLayoutExtractWrapper type paths

**File:** `anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift`

```swift
// Change from:
public typealias PageLayout = LayoutEngineCapsule.PageLayout
public typealias TextSegment = LayoutEngineCapsule.TextSegment
public typealias BoundingBox = LayoutEngineCapsule.BoundingBox
public typealias LayoutEngineConfig = LayoutEngineCapsule.LayoutEngineConfig
public typealias LayoutEngineError = LayoutEngineCapsule.LayoutEngineError

// To:
// These typealiases are no longer needed if we use the types directly
// OR keep them but with correct paths:
public typealias PageLayout = LayoutEngineCapsule.PageLayout
public typealias TextSegment = LayoutEngineCapsule.TextSegment  
public typealias BoundingBox = LayoutEngineCapsule.BoundingBox
public typealias LayoutEngineConfig = LayoutEngineCapsule.LayoutEngineConfig
public typealias LayoutEngineError = LayoutEngineCapsule.LayoutEngineError
```

Since LayoutEngineCapsule now exports these types (Step 1), the paths stay `LayoutEngineCapsule.X` which is correct.

### 4. Add Foundation import

**File:** `anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractWrapper.swift`

Add at top:
```swift
import Foundation
```

### 5. Fix PDFLayoutExtractContract import

**File:** `anigma/Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline/Contracts/PDFLayoutExtractContract.swift`

Change line 16:
```swift
import PDFLayoutExtract  // WRONG
```
to:
```swift
import LayoutEngineCapsule  // CORRECT
```

---

## Implementation Order

1. Fix LayoutEngineCapsuleWrapper.swift (make types public, add LayoutEngineError)
2. Add extractText to LayoutEngineCapsuleWrapper.swift
3. Fix PDFLayoutExtractContract.swift import
4. Fix PDFLayoutExtractWrapper.swift (import Foundation, type paths should already be correct)
5. Test compilation
6. Run validation scripts

---

## Files to Modify

| File | Change | Risk |
|------|--------|------|
| LayoutEngineCapsuleWrapper.swift | Make types public, add LayoutEngineError typealias | Low - these are portable types |
| LayoutEngineCapsuleWrapper.swift | Add extractText method | Medium - needs correct implementation |
| PDFLayoutExtractContract.swift | Fix import | Low |
| PDFLayoutExtractWrapper.swift | Add Foundation import | Low |

---

## Validation

After implementation:

```bash
swift build --target BackendReadinessContractTests
swift test BackendReadinessContractTests

python3 Scripts/anigma_package_graph_audit.py explain-edge BackendReadinessContractTests PDFNative
python3 Scripts/anigma_package_graph_audit.py explain-edge BackendReadinessContractTests PDFSidecarNativeShims
python3 Scripts/anigma_package_graph_audit.py explain-edge BackendReadinessContractTests PDFSidecarExecutable

python3 tools/governance/scripts/validate_tiers.py
python3 Scripts/validate_no_cycles.py .build/anigma-package.json
```

---

## Non-Blocking Note

The current repository HEAD has pre-existing Package.swift syntax errors unrelated to td-358315-01 or td-7c0153. These must be resolved before the above changes can be validated with swift build. However, the implementation plan itself is sound and can be executed once Package.swift is restored to a buildable state.

---

*Status: IMPLEMENTATION PLANNED*
*Next: Execute implementation when Package.swift is buildable*
