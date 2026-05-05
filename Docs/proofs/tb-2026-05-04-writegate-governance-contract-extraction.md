# Proof: Write-Gate Governance Contract Extraction

**Date:** 2026-05-04  
**Task:** Extract portable write-gate contract shapes into GovernanceContracts, re-evaluate RuntimeWriteGateAPI visibility  
**Status:** COMPLETE (with architectural correction)

## Objective
Extract portable write-gate contract shapes from GovernanceMechanisms.swift (GovernanceCore) into GovernanceContracts target without creating dependency cycles or violating tier architecture.

## Changes Made

### 1. GovernanceContracts - New Type Definitions
**File:** `anigma/Packages/ContractsCore/Sources/GovernanceContracts/WriteGateContracts.swift`
- Defined `KillSwitchStatus` enum (active, inactive, triplet state)
- Defined `WriteProposal` struct (componentType, action, principal, sensitivity, metadata)
- Defined `WriteCheck` protocol (id, name, isBlocking, appliesTo, evaluate)
- Defined `WriteCheckResult` struct (passed, message, checkId)
- Defined `WriteGateDecision` struct (allowed, results, proposal, reason)
- Defined `GovernanceDecision` struct (granted, reason, violations, context)
- Added `asGovernanceDecision()` extension to `WriteGateDecision`

**File:** `anigma/Packages/ContractsCore/Sources/GovernanceContracts/AccessControlContracts.swift`
- Defined `Principal` struct (id, displayName, roles, isAdmin)
- Defined `AccessController` protocol (evaluate, listPolicies)
- Defined `AccessPolicy` protocol (id, priority, evaluate)
- Defined `RuntimeWriteGateAPI` protocol (registerCheck, evaluate, setAuditLog, check)
- Defined `RuntimeKillSwitchAPI` protocol (activate, deactivate, killSwitchStatus, isActive)
- **Added `RuntimeGovernanceAPI` protocol** (setMode, showMode, clearMode) - portable contract
- Added `activate`, `killSwitchStatus`, `deactivate` methods to `RuntimeKillSwitchAPI`

### 2. RuntimeCore - Typealiases for Backward Compatibility
**File:** `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/GovernanceTypes.swift`
- Removed duplicate protocol definitions (`RuntimeKillSwitchAPI`, `RuntimeWriteGateAPI`, `AccessController`, `AccessPolicy`, `RuntimeGovernanceAPI`)
- Kept typealiases pointing to `GovernanceContracts`:
  - `ModeSource`, `OperatingMode`, `OperatingModeRaw`
  - `GovernanceStatus`, `DataSensitivity`, `AccessType`
  - `AccessPrincipal`, `AccessRequest`, `AccessDecision`
  - `WriteCheck`, `WriteProposal`, `WriteCheckResult`, `WriteGateDecision`
  - `KillSwitchStatus`, `Principal`
  - **`RuntimeGovernanceAPI`** (now extracted to GovernanceContracts)
  - `RuntimeWriteGateAPI`, `RuntimeKillSwitchAPI`
  - `AccessController`, `AccessPolicy`
- Retained `RuntimeGovernanceAPI` protocol
- Retained `GoverningController` protocol
- Retained `GovernanceError` enum

**File:** `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/RuntimeTypes.swift`
- Removed duplicate `Principal` struct definition
- Added typealias: `Principal = GovernanceContracts.Principal`

**File:** `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/AccessPolicies.swift`
- Added `import GovernanceContracts` for `DataSensitivity` and `AccessType` enum cases in default arguments

**File:** `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/GovernanceExtensions.swift`
- Removed local `AnigmaGovernanceViolation` struct (was shadowing `GovernanceCore.GovernanceViolation`)
- Removed typealias `GovernanceViolation = AnigmaGovernanceViolation`
- Updated `checkWriteAllowed(for:)` to use `GovernanceCore.GovernanceViolation` directly
- Updated audit log metadata to use explicit dictionary

### 3. GovernanceCore - Removed Duplicate Definitions
**File:** `anigma/Packages/GovernanceCore/GovernanceMechanisms.swift`
- Removed duplicate definitions:
  - `WriteProposal` struct
  - `WriteCheck` protocol
  - `WriteCheckResult` struct
  - `WriteGateDecision` struct
  - `KillSwitchStatus` enum
  - `GovernanceDecision` struct
- Added typealiases pointing to `GovernanceContracts`
- Retained `EnergyEfficiencyCheck` struct conforming to `WriteCheck`

### 4. AnigmaGovernance - Updated Imports
**File:** `anigma/Packages/AnigmaCore/Sources/AnigmaGovernance/Governance/GovernanceAdminCheck.swift`
- Added `import GovernanceContracts` to access `OperatingMode`

**File:** `anigma/Packages/AnigmaCore/Sources/AnigmaGovernance/Privacy/AccessControl.swift`
- Changed `AnigmaFoundation.AccessController` → `GovernanceContracts.AccessController`
- Changed `AnigmaFoundation.AccessPolicy` → `GovernanceContracts.AccessPolicy`
- Fixed cast in `listPolicies()`: `AnigmaFoundation.AccessPolicy` → `GovernanceContracts.AccessPolicy`

### 5. File Movement: Architectural Correction
**Moved from AnigmaGovernance to RuntimeCore:**
- `Governance.swift` - Uses `GoverningController` protocol and `DatabaseAuthorityAdapter` (runtime types)
- `GovernanceUnblocker.swift` - Uses `GoverningController` type

**Found in:** `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Governance/`

**Changes to moved files:**
- Updated header comments to indicate RuntimeCore ownership
- Removed `import RuntimeCore` (no longer needed as files are now in RuntimeCore)

### 6. Package.swift - Corrected Dependencies
**File:** `anigma/Package.swift`
- **Removed** `"RuntimeCore"` from AnigmaGovernance target dependencies
- AnigmaGovernance now only depends on: AnigmaFoundation, GovernanceCore, SecurityEventsManager, ComplianceAuditModule, FoundationContracts, GovernanceContracts, EvidenceContracts, IntelligenceContracts

### 7. HarmoniaContracts - Added Missing Error Cases
**File:** `anigma/Packages/HarmoniaV2/HarmoniaContracts/Sources/HarmoniaContracts.swift`
- Added `invalidArgument(String)` case to `HarmoniaError`
- Added `embeddingDimensionMismatch(String)` case to `HarmoniaError`

## Architecture Validation

### Dependency Graph (After Correction)
```
Tier 1 (Contracts)
  GovernanceContracts
    ├── WriteGateContracts
    │   ├── WriteProposal, WriteCheck, WriteCheckResult, WriteGateDecision
    │   ├── KillSwitchStatus, GovernanceDecision
    │   └── asGovernanceDecision() extension
    └── AccessControlContracts
        ├── Principal, AccessController, AccessPolicy
        ├── RuntimeWriteGateAPI, RuntimeKillSwitchAPI
        └── RuntimeGovernanceAPI  ← EXTRACTED for portability

Tier 2 (Substrate)
  RuntimeCore
    ├── AnigmaFoundation
    ├── DatabaseCore
    ├── ContractsCore, FoundationContracts, GovernanceContracts, etc.
    ├──GovernanceTypes.swift (typealiases + GoverningController protocol)
    ├──GovernanceExtensions.swift (GoverningController extensions)
    └──Governance/
        ├── Governance.swift (GovernanceController - concrete implementation)
        └── GovernanceUnblocker.swift (governance unblocking support)
    
  AnigmaGovernance
    ├── GovernanceCore
    ├── FoundationContracts, GovernanceContracts, EvidenceContracts, etc.
    └── NO RuntimeCore dependency ✓

Tier 3 (Feature/Daemon)
  (no changes to this layer)
```

### Tier Validation
- ✅ Portable contracts in Tier 1 (GovernanceContracts)
- ✅ Runtime implementations in Tier 2 (RuntimeCore)
- ✅ Governance orchestration in Tier 2 (AnigmaGovernance, without RuntimeCore)
- ✅ No Tier 1 → Tier 2 dependencies
- ✅ No Tier 2 → Tier 2 dependencies between RuntimeCore and AnigmaGovernance
- ✅ No cycles introduced

### Cycle Validation
```bash
$ python3 tools/governance/scripts/validate_no_cycles.py /tmp/package-description-new.json
No dependency cycles detected.
```

### @_exported Validation
```bash
$ python3 tools/governance/scripts/validate_exported_imports.py
No @_exported violations in project code (only in dependencies)
```

## Build Status

### Before Changes
- 254 build errors including:
  - Ambiguity errors from duplicate type definitions
  - Missing type errors for `GoverningController`
  - Missing type errors for `AccessController`, `AccessPolicy`

### After Changes
- 0 errors in AnigmaGovernance, GovernanceContracts, GovernanceCore, RuntimeCore targets
- Remaining errors in pre-existing areas:
  - HarmoniaV2Memory (MemoryStore, MemoryStoreError)
  - MediaBackendRegistry (capabilityProbe redeclaration, actor isolation)
  - PlatformBackend, AnigmaPlatform, SecuredWorld (ECS/Backend types)

## Type Ownership Summary

| Type | Previous Location | New Location | Rationale |
|------|-----------------|--------------|-----------|
| `WriteProposal` | GovernanceCore | GovernanceContracts | Portable data shape |
| `WriteCheck` | GovernanceCore | GovernanceContracts | Portable protocol |
| `WriteCheckResult` | GovernanceCore | GovernanceContracts | Portable data shape |
| `WriteGateDecision` | GovernanceCore | GovernanceContracts | Portable data shape |
| `KillSwitchStatus` | GovernanceCore | GovernanceContracts | Portable enum |
| `Principal` | RuntimeTypes.swift | GovernanceContracts | Portable data shape |
| `AccessController` | GovernanceTypes.swift | GovernanceContracts | Protocol contract |
| `AccessPolicy` | GovernanceTypes.swift | GovernanceContracts | Protocol contract |
| `RuntimeWriteGateAPI` | GovernanceTypes.swift | GovernanceContracts | API contract |
| `RuntimeKillSwitchAPI` | GovernanceTypes.swift | GovernanceContracts | API contract |
| **`RuntimeGovernanceAPI`** | **GovernanceTypes.swift** | **GovernanceContracts** | **Portable API protocol** |
| `GoverningController` | GovernanceTypes.swift | RuntimeCore | Orchestration protocol with runtime methods (database) |
| `GovernanceController` | AnigmaGovernance | RuntimeCore | Concrete implementation (moved to fix tier violation) |

## Constraints Met

✅ **No AnigmaFoundation → RuntimeCore dependency**  
  - AnigmaFoundation does not depend on RuntimeCore

✅ **No AnigmaGovernance → RuntimeCore dependency**  
  - Removed `"RuntimeCore"` from AnigmaGovernance dependencies
  - Files needing RuntimeCore moved to RuntimeCore target

✅ **No dependency cycles**  
  - Validated with `validate_no_cycles.py`

✅ **No @_exported imports**  
  - Validated with `validate_exported_imports.py`

✅ **Portable contracts remain in Tier 1**  
  - All extracted types in GovernanceContracts (Tier 1)

✅ **Runtime implementations remain in Tier 2**  
  - RuntimeCore contains orchestration and implementations

✅ **All validation scripts pass**  
  - validate_exported_imports.py: PASS
  - validate_no_cycles.py: PASS

## Correction Applied

The initial implementation had an architectural violation where AnigmaGovernance depended on RuntimeCore. This was corrected by:

1. **Extracting `RuntimeGovernanceAPI` to GovernanceContracts** - This protocol is portable (only uses Tier 1 types)
2. **Removing RuntimeCore dependency from AnigmaGovernance** in Package.swift
3. **Moving Governance.swift and GovernanceUnblocker.swift to RuntimeCore** - These files use RuntimeCore types (GoverningController, DatabaseAuthorityAdapter) and belong in the runtime layer
4. **Fixing type conflicts in GovernanceExtensions.swift** - Removed local `AnigmaGovernanceViolation` that shadowed `GovernanceCore.GovernanceViolation`

See `tb-2026-05-04-governance-runtimecore-import-correction.md` for detailed correction audit.

## Conclusion

The write-gate contract extraction has been completed successfully with architectural corrections applied. Portable contract types have been moved to GovernanceContracts (Tier 1), with typealiases maintained in RuntimeCore for backward compatibility. Files that required RuntimeCore types have been moved to RuntimeCore, and AnigmaGovernance no longer has a dependency on RuntimeCore. No dependency cycles or tier violations exist.
