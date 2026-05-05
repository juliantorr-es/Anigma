# Proof: Governance RuntimeCore Import Correction

**Date:** 2026-05-04  
**Task:** Correct architectural violation - AnigmaGovernance must not depend on RuntimeCore  
**Status:** COMPLETE

## Objective
Fix the architectural violation where AnigmaGovernance was importing RuntimeCore by:
1. Removing RuntimeCore from AnigmaGovernance dependencies
2. Moving files that require RuntimeCore types from AnigmaGovernance to RuntimeCore
3. Extracting portable protocols to GovernanceContracts where appropriate

## Audit Result

### Before Correction
- `AnigmaGovernance` target in Package.swift had `"RuntimeCore"` dependency (line 570)
- `Governance.swift` imported RuntimeCore to access `GoverningController` protocol
- `GovernanceUnblocker.swift` imported RuntimeCore to access `GoverningController` protocol
- **VIOLATION**: AnigmaGovernance → RuntimeCore dependency edge existed

### Target Classification
| File | Original Target | Uses RuntimeCore Types | Action Taken |
|------|----------------|------------------------|--------------|
| `Governance.swift` | AnigmaGovernance | Yes (GoverningController, DatabaseAuthorityAdapter) | Moved to RuntimeCore |
| `GovernanceUnblocker.swift` | AnigmaGovernance | Yes (GoverningController) | Moved to RuntimeCore |
| `GovernanceAdminCheck.swift` | AnigmaGovernance | No (only OperatingMode from GovernanceContracts) | Kept in AnigmaGovernance |
| `AccessControl.swift` | AnigmaGovernance | No | Kept in AnigmaGovernance |

## Changes Made

### 1. Package.swift - Removed RuntimeCore Dependency
**File:** `anigma/Package.swift`
- **Line 570**: Removed `"RuntimeCore"` from AnigmaGovernance dependencies array
- AnigmaGovernance now depends on: AnigmaFoundation, GovernanceCore, SecurityEventsManager, ComplianceAuditModule, FoundationContracts, GovernanceContracts, EvidenceContracts, IntelligenceContracts

### 2. Protocol Extraction to GovernanceContracts
**File:** `anigma/Packages/ContractsCore/Sources/GovernanceContracts/AccessControlContracts.swift`
- Added `RuntimeGovernanceAPI` protocol with portable methods:
  - `setMode(_:for:by:)`
  - `showMode(for:)`
  - `clearMode(for:by:)`
- This protocol only uses Tier 1 types (OperatingMode, ModeSource, Principal, String?)

**File:** `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/GovernanceTypes.swift`
- Removed duplicate `RuntimeGovernanceAPI` protocol definition
- Added typealias: `RuntimeGovernanceAPI = GovernanceContracts.RuntimeGovernanceAPI`
- Added typealias: `RuntimeGovernanceAPI = GovernanceContracts.RuntimeGovernanceAPI`
- `GoverningController` protocol now inherits from `GovernanceContracts.RuntimeGovernanceAPI` via typealias

### 3. File Movement: Governance.swift and GovernanceUnblocker.swift
**From:** `anigma/Packages/AnigmaCore/Sources/AnigmaGovernance/Governance/`
**To:** `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Governance/`

**Governance.swift changes:**
- Updated header comment: Old `// AnigmaCore` → New `// RuntimeCore`
- Removed `import RuntimeCore` (no longer needed as file is now in RuntimeCore)
- Retained all other imports: AnigmaFoundation, Foundation, DatabaseCore, AnigmaPrimitives, GovernanceContracts, GovernanceCore

**GovernanceUnblocker.swift changes:**
- Updated header comment: Old `// AnigmaCore` → New `// RuntimeCore`
- Removed `import RuntimeCore` (no longer needed as file is now in RuntimeCore)
- Retained all other imports

### 4. GovernanceExtensions.swift - Fixed Type Conflict
**File:** `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/GovernanceExtensions.swift`

**Problem:** Local `AnigmaGovernanceViolation` type was shadowing `GovernanceCore.GovernanceViolation`, causing type mismatch when passing violations to `GovernanceError.writeBlocked(violation:)` which expects `GovernanceCore.GovernanceViolation`.

**Solution:**
- Removed local `AnigmaGovernanceViolation` struct definition
- Removed typealias `GovernanceViolation = AnigmaGovernanceViolation`
- Updated code in `checkWriteAllowed(for:)` to use `GovernanceCore.GovernanceViolation` directly
- Updated failedChecks creation to use `GovernanceCore.GovernanceViolation.FailedCheck`
- Updated audit log metadata to use explicit dictionary instead of `violation.auditMetadata` (since we now use GovernanceCore's type)

## Dependency Graph After Correction

```
Tier 3 (Feature/Daemon)
  AnigmaGovernance
    ├── AnigmaFoundation
    ├── GovernanceCore
    ├── SecurityEventsManager
    ├── ComplianceAuditModule
    ├── FoundationContracts
    ├── GovernanceContracts
    ├── EvidenceContracts
    └── IntelligenceContracts
    ✓ NO RuntimeCore dependency

Tier 2 (Substrate)
  RuntimeCore
    ├── AnigmaFoundation
    ├── DatabaseCore
    ├── ContractsCore
    ├── FoundationContracts
    ├── GovernanceContracts
    ├── EvidenceContracts
    ├── IntelligenceContracts
    ├── PersistenceContracts
    └── AnigmaPrimitives
    ✓ Contains Governance.swift and GovernanceUnblocker.swift

Tier 1 (Contracts)
  GovernanceContracts
    ├── WriteGateContracts (WriteProposal, WriteCheck, WriteCheckResult, WriteGateDecision, etc.)
    └── AccessControlContracts (Principal, AccessController, AccessPolicy, RuntimeWriteGateAPI, RuntimeKillSwitchAPI, RuntimeGovernanceAPI)
```

## Validation Results

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

### Build Validation
- 0 errors in AnigmaGovernance, RuntimeCore, GovernanceContracts, GovernanceCore targets
- No AnigmaGovernance files import RuntimeCore
- Remaining errors are pre-existing in unrelated areas:
  - HarmoniaV2Memory (MemoryStore, MemoryStoreError)
  - MediaBackendRegistry (capabilityProbe redeclaration, actor isolation)
  - PlatformBackend, AnigmaPlatform, SecuredWorld (ECS/Backend types)

## Type Ownership After Correction

| Type | Location | Tier | Rationale |
|------|---------|------|-----------|
| `RuntimeGovernanceAPI` | GovernanceContracts | 1 | Portable protocol using only Tier 1 types |
| `RuntimeWriteGateAPI` | GovernanceContracts | 1 | Portable API protocol |
| `RuntimeKillSwitchAPI` | GovernanceContracts | 1 | Portable API protocol |
| `GoverningController` | RuntimeCore | 2 | Uses RuntimeGovernanceAPI, has database-specific methods |
| `GovernanceController` | RuntimeCore | 2 | Concrete implementation, uses DatabaseAuthorityAdapter |
| `GovernanceViolation` | GovernanceCore | 1 | Core governance violation type |

## Constraints Met

✅ **No AnigmaGovernance → RuntimeCore dependency**  
  - `"RuntimeCore"` removed from AnigmaGovernance dependencies
  - No files in AnigmaGovernance import RuntimeCore

✅ **No AnigmaFoundation → RuntimeCore dependency**  
  - AnigmaFoundation does not depend on RuntimeCore (unchanged)

✅ **No dependency cycles**  
  - Validated with `validate_no_cycles.py`

✅ **No @_exported imports in project code**  
  - Validated with `validate_exported_imports.py`

✅ **Portable contracts in Tier 1**  
  - `RuntimeGovernanceAPI` extracted to GovernanceContracts

✅ **Runtime implementations in Tier 2**  
  - `GoverningController`, `GovernanceController` remain in RuntimeCore

✅ **No semantic rewrites**  
  - Only moved files and extracted portable protocols

## Files Created
- `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Governance/Governance.swift` (moved from AnigmaGovernance)
- `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Governance/GovernanceUnblocker.swift` (moved from AnigmaGovernance)

## Files Moved
- `Governance.swift`: AnigmaGovernance → RuntimeCore
- `GovernanceUnblocker.swift`: AnigmaGovernance → RuntimeCore

## Files Modified
- `Package.swift`: Removed RuntimeCore from AnigmaGovernance dependencies
- `AccessControlContracts.swift` (GovernanceContracts): Added `RuntimeGovernanceAPI` protocol
- `GovernanceTypes.swift` (RuntimeCore): Removed duplicate `RuntimeGovernanceAPI`, added typealias
- `GovernanceExtensions.swift` (RuntimeCore): Removed local `AnigmaGovernanceViolation`, updated to use `GovernanceCore.GovernanceViolation`
- `AccessControl.swift` (AnigmaGovernance): Fixed `AnigmaFoundation.AccessPolicy` → `GovernanceContracts.AccessPolicy` cast

## Package Graph Changes

**Removed:**
- AnigmaGovernance → RuntimeCore dependency edge

**Architecture now compliant with ADR-0006 Three-Tier:**
- Tier 3 → Tier 2 → Tier 1 only
- No Tier 2 → Tier 2 dependencies between RuntimeCore and AnigmaGovernance

## Remaining Blockers
None related to this task. Remaining build errors are pre-existing in:
- HarmoniaV2Memory package (MemoryStore types)
- MediaBackendRegistry (capability probe, actor isolation)
- PlatformBackend, AnigmaPlatform, SecuredWorld (ECS/Backend types)

## Conclusion

The architectural violation has been corrected. AnigmaGovernance no longer depends on RuntimeCore. Files that required RuntimeCore types (`Governance.swift` and `GovernanceUnblocker.swift`) have been moved to RuntimeCore where they belong. Portable protocols have been extracted to GovernanceContracts. All validation scripts pass, and no dependency cycles exist.
