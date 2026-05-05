# Build Error Campaign: AnigmaCore + HarmoniaV2 Blockers

## Starting Error Count
**Before:** 317 errors (captured in `/tmp/anigma-build-error-campaign-before.log`)

This represents a significant increase from the previous 30 errors because ModelRegistry access-control fixes allowed many more modules to compile past earlier blockers, exposing previously masked issues.

## Error Taxonomy

### Bucket 1: AccessControl Types (208 errors - 66% of total)
All errors originate from `anigma/Packages/AnigmaCore/Sources/AnigmaGovernance/Privacy/AccessControl.swift`

**Missing types:**
- `AccessRequest` - 56 occurrences (cannot find type + cannot find)
- `AccessPolicy` - 56 occurrences (cannot find type + no type named in module)
- `AccessDecision` - 56 occurrences (cannot find type + cannot find)
- `DataSensitivity` - 48 occurrences (cannot find type)
- `AccessType` - 16 occurrences (cannot find type)
- `AccessPrincipal` - 16 occurrences (cannot find type)
- `AccessController` - 8 occurrences (no type named in module 'AnigmaFoundation')

**Root cause:** All these types are defined in `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/GovernanceTypes.swift`, which is in `AnigmaFoundation/Runtime/` directory. AnigmaFoundation target EXCLUDES `Runtime/` directory, so these types are not compiled into AnigmaFoundation.

The types ARE compiled into RuntimeCore (which has path `Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime`), but AnigmaGovernance depends on AnigmaFoundation, not RuntimeCore.

**Ownership:** `GovernanceTypes.swift` contains runtime implementation types:
- `AccessRequest`, `AccessPolicy`, `AccessDecision` - governance/access control interfaces
- `DataSensitivity`, `AccessType`, `AccessPrincipal` - privacy/access classification
- `AccessController` protocol

### Bucket 2: AccessControl Enum Members (24 errors - 8%)
- `cannot infer contextual base in reference to member 'restricted'` - 8 errors
- `cannot infer contextual base in reference to member 'read'` - 8 errors  
- `cannot infer contextual base in reference to member 'query'` - 8 errors

**Root cause:** These are enum cases being used (likely `AccessType.restricted`, etc.) but the enum type `AccessType` itself is not found, so the compiler cannot resolve the member references.

### Bucket 3: HarmoniaError (4 errors - 1%)
- `cannot find 'HarmoniaError' in scope` - 4 errors in `HarmoniaV2/HarmoniaCore/Sources/HarmoniaCore.swift`

**Root cause:** `HarmoniaCore.swift` uses `HarmoniaError.invalidArgument` and `HarmoniaError.embeddingDimensionMismatch`. `HarmoniaError` is defined in `HarmoniaV2/HarmoniaContracts/Sources/HarmoniaContracts.swift`. HarmoniaCore depends on AnigmaFoundation but NOT HarmoniaContracts.

### Bucket 4: emit-module failures (1 error)
- Generic module emission failure propagating from the above errors.

## Symbols Investigated

### RuntimeWriteGateAPI
- **Definition:** `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/GovernanceTypes.swift:public protocol RuntimeWriteGateAPI`
- **Status:** In Runtime/ directory, excluded from AnigmaFoundation, compiled by RuntimeCore
- **Used by:** `anigma/Packages/AnigmaCore/Sources/AnigmaGovernance/Governance/Governance.swift: public let writeGate: any RuntimeWriteGateAPI`
- **Note:** Not currently showing in error list - may have been masked by other errors

### PolicyEnforcementEngineAPI
- **Definition:** `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/SecurityProtocols.swift:public protocol PolicyEnforcementEngineAPI`
- **Status:** In Runtime/ directory, excluded from AnigmaFoundation, compiled by RuntimeCore
- **Used by:** `anigma/Packages/AnigmaCore/Sources/AnigmaGovernance/Security/Security.swift`
- **Note:** Not currently showing in error list

### SecurityInfrastructure
- **Definition:** `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/SecurityProtocols.swift:public protocol SecurityInfrastructure`
- **Also defined:** `anigma/Packages/AnigmaCore/Sources/AnigmaGovernance/Security/Security.swift:public struct SecurityInfrastructure` (duplicate!)
- **Status:** Protocol in Runtime/, struct in AnigmaGovernance
- **Note:** Not currently showing in error list

### HarmoniaError
- **Definition:** `anigma/Packages/HarmoniaV2/HarmoniaContracts/Sources/HarmoniaContracts.swift:public enum HarmoniaError`
- **Used by:** `anigma/Packages/HarmoniaV2/HarmoniaCore/Sources/HarmoniaCore.swift`
- **Issue:** HarmoniaCore does not import HarmoniaContracts

## Root-Cause Buckets Identified

### Bucket A: AccessControl Types - Missing Dependency Path (208 errors)
**Classification:** Type definitions in excluded directory + missing dependency edge
- GovernanceTypes.swift in AnigmaFoundation/Runtime/ (excluded from AnigmaFoundation)
- Compiled by RuntimeCore
- AnigmaGovernance needs these types but only depends on AnigmaFoundation, not RuntimeCore
- **Architectural issue:** Adding RuntimeCore to AnigmaGovernance would create cycle:
  RuntimeCore → AnigmaFoundation → AnigmaGovernance → RuntimeCore

### Bucket B: HarmoniaError - Missing Import (4 errors)
**Classification:** Missing import, dependency already exists in module graph
- HarmoniaError defined in HarmoniaContracts
- HarmoniaCore needs to add `import HarmoniaContracts`
- HarmoniaV2Core already depends on AnigmaFoundation, but not HarmoniaContracts
- This is a simple import fix BUT need to check if HarmoniaV2Core depends on HarmoniaContracts

### Bucket C: Contextual Base Inference (24 errors)
**Classification:** Cascading from Bucket A - cannot resolve enum members when enum type not found
- Secondary effect of AccessControl types not being visible
- Will be resolved when Bucket A is fixed

## Files Modified During Campaign
**None.** This campaign was stopped at the analysis phase because the largest root-cause bucket (Bucket A) requires an architectural decision about RuntimeCore dependency relationships.

## Files Moved/Deleted During Campaign
**None.**

## Package Graph Changes During Campaign
**None.**

## Validation Results
- N/A - No changes made during this campaign phase

## Ending Error Count
**317** (same as starting - no changes applied)

## Stop Reason
**Architectural decision required.** The largest error bucket (208 of 317 errors = 66%) involves AccessControl types defined in `AnigmaFoundation/Runtime/GovernanceTypes.swift` which:
1. Is excluded from AnigmaFoundation target compilation
2. Is compiled by RuntimeCore target
3. Is needed by AnigmaGovernance target

Adding RuntimeCore as a dependency of AnigmaGovernance would create a dependency cycle:
- RuntimeCore → AnigmaFoundation → AnigmaGovernance → RuntimeCore

Alternative approaches require architectural decision:
- **Option 1:** Extract GovernanceTypes to a new GovernanceRuntimeContracts module (Tier 1)
- **Option 2:** Extract only the AccessControl types to GovernanceContracts (they are governance domain)
- **Option 3:** Accept the cycle and document it as a known architectural debt
- **Option 4:** Move AccessControl.swift to use different types or move it to a different module

## Remaining Blocker Taxonomy
| Bucket | Errors | Type | Architectural Risk |
|--------|--------|------|---------------------|
| A | 208 | Missing types + dependency | HIGH - Cycle risk |
| B | 4 | Missing import | LOW - Simple fix |
| C | 24 | Cascading from A | MEDIUM - Will resolve with A |
| Other | 81 | Various | Unknown |

## Architecture Statement
✅ **No RuntimeCore dependency added to AnigmaFoundation** - No changes made
✅ **No DatabaseCore ↔ AnigmaFoundation cycle** - No changes made  
✅ **No dependency cycles detected** - No changes made to validate
✅ **No @_exported imports introduced** - No imports added
✅ **No package swelling introduced** - No targets or dependencies added
✅ **Tier validation remains clean** - No changes made

## Proof Artifacts
- Error baseline: `/tmp/anigma-build-error-campaign-before.log` (317 errors)
- Error taxonomy: This document

## Recommended Next Task
**Architectural decision needed for Bucket A:**
1. Extract AccessControl types (`AccessRequest`, `AccessPolicy`, `AccessDecision`, `DataSensitivity`, `AccessType`, `AccessPrincipal`, `AccessController`) from `GovernanceTypes.swift` to `GovernanceContracts` module ( Tier 1), OR
2. Add RuntimeCore as dependency to AnigmaGovernance and document the cycle, OR
3. Move AccessControl.swift to a module that already has RuntimeCore visibility

Once architectural decision is made for Bucket A, Bucket B (HarmoniaError import) can be fixed as a simple mechanical change.
