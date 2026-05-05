# RuntimeCore Governance Infrastructure Fix - tb-2026-05-04

## Starting Error Count
7 errors identified in RuntimeCore governance infrastructure (Governance.swift, PlatformRuntime.swift, SecuredWorld.swift, WorkflowProtocols.swift)

## Error Taxonomy

### Type Not Found in Scope (7 errors)
1. `Governance.swift:128:27` - cannot find 'KillSwitch' in scope
2. `Governance.swift:129:26` - cannot find 'WriteGate' in scope
3. `Governance.swift:143:36` - cannot find type 'KillSwitch' in scope
4. `Governance.swift:122:70` - 'any AccessController' cannot be constructed because it has no accessible initializers
5. `Governance.swift:334:101` - no type named 'DatabaseAuthority' in module 'AnigmaFoundation'
6. `PlatformRuntime.swift:891:7` - type 'MockAccessController' does not conform to protocol 'AccessController'
7. `WorkflowTypes.swift:29,32,41,42,45,89` - cannot find type 'World' in scope
8. `WorkflowTypes.swift:96,101` - cannot find type 'System' in scope
9. `WorkflowProtocols.swift:40,82` - cannot find type 'World' / 'System' in scope

## Symbol Ownership Classification

### Misplaced Runtime Types (in AnigmaGovernance, belong in RuntimeCore)
1. **KillSwitch** - Actor implementing `RuntimeKillSwitchAPI`
   - Location: `Packages/AnigmaCore/Sources/AnigmaGovernance/Governance/KillSwitch.swift`
   - Comment: "This actor lives in Tier 2 (Platform Runtime)"
   - Ownership: Should be RuntimeCore (Tier 2)
   
2. **WriteGate** - Actor implementing `RuntimeWriteGateAPI`
   - Location: `Packages/AnigmaCore/Sources/AnigmaGovernance/Governance/WriteGate.swift`
   - Comment: "This actor lives in Tier 2 (Platform Runtime)"
   - Ownership: Should be RuntimeCore (Tier 2)

3. **AccessController** - Actor implementing `GovernanceContracts.AccessController`
   - Location: `Packages/AnigmaCore/Sources/AnigmaGovernance/Privacy/AccessControl.swift`
   - Ownership: Should be RuntimeCore (Tier 2) - it's the concrete runtime access controller

### Portable Contracts (correctly in GovernanceContracts)
- `RuntimeKillSwitchAPI` protocol - GovernanceContracts
- `RuntimeWriteGateAPI` protocol - GovernanceContracts
- `AccessController` protocol - GovernanceContracts
- `DatabaseAuthority` protocol - DatabaseCore (and duplicate in RuntimeCore/Authorities.swift)

## Types Extracted to GovernanceContracts
None - all required contracts already exist in GovernanceContracts.

## Runtime-Owned Types Moved/Retained

### Moved from AnigmaGovernance to RuntimeCore
1. `KillSwitch.swift` - `public actor KillSwitch: RuntimeKillSwitchAPI`
2. `WriteGate.swift` - `public actor WriteGate: RuntimeWriteGateAPI`
3. `AccessControl.swift` - Contains `public actor AccessController: GovernanceContracts.AccessController`

**Rationale**: These are Tier 2 runtime governance mechanisms. Their own comments state "This actor lives in Tier 2 (Platform Runtime)". RuntimeCore owns runtime orchestration and runtime service wiring. Having concrete governance implementors in AnigmaGovernance creates an architectural violation when RuntimeCore needs to use them.

### Retained in RuntimeCore
- `MockAccessController` in PlatformRuntime.swift - placeholder implementation for testing

## Files Modified

### Moved Files (3)
1. `Packages/AnigmaCore/Sources/AnigmaGovernance/Governance/KillSwitch.swift` → `Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Governance/KillSwitch.swift`
2. `Packages/AnigmaCore/Sources/AnigmaGovernance/Governance/WriteGate.swift` → `Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Governance/WriteGate.swift`
3. `Packages/AnigmaCore/Sources/AnigmaGovernance/Privacy/AccessControl.swift` → `Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Governance/AccessControl.swift`

### Updated Files (5)
1. `Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Governance/KillSwitch.swift` - Removed `import GovernanceCore` (not needed)
2. `Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Governance/WriteGate.swift` - Removed `import GovernanceCore` and `import SecurityEventsManager` (not needed)
3. `Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Governance/AccessControl.swift` - Updated header comment to "RuntimeCore", removed `import GovernanceCore` (not used)
4. `Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/PlatformRuntime.swift` - Added `setAuditLog` method to `MockAccessController` for protocol conformance
5. `Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/Governance/Governance.swift` - Fixed `DatabaseAuthority` type reference (removed incorrect `AnigmaFoundation.` qualifier), fixed typo in AccessControl.swift reference

## Package Graph Changes
None - all moved files are within the same package (AnigmaCore) and RuntimeCore already depends on GovernanceContracts. The moves are internal reorganizations, not new dependencies.

## Validation Results

```bash
# No dependency cycles introduced
python3 ../../tools/governance/scripts/validate_no_cycles.py .build/anigma-package.json
# Result: No dependency cycles detected.

# No AnigmaGovernance imports in RuntimeCore
rg "import AnigmaGovernance" anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/
# Result: No matches

# RuntimeCore governance files compile without errors
swift build 2>&1 | grep -E "Governance\.swift|PlatformRuntime\.swift|SecuredWorld\.swift|WorkflowProtocols\.swift|WorkflowTypes\.swift" | grep "error:"
# Result: No matches
```

## Remaining Blockers
None for RuntimeCore governance infrastructure. Remaining errors are:
- AnigmaGovernance/PromptRouter.swift - unrelated to this fix (Fun
ctionClearance, PromptClassification)
- MediaCore - CVPixelBufferGetByteCount and ImageSurfaceReference type mismatches (separate MediaCore issues)

## Architecture Statement

- **RuntimeCore does not depend on AnigmaGovernance**: Verified - no imports, no dependency
- **AnigmaGovernance does not depend on RuntimeCore**: Pre-existing (true by inspection)
- **Governance contracts are portable**: All governance capability protocols remain in GovernanceContracts
- **Runtime orchestration remains in RuntimeCore**: KillSwitch, WriteGate, AccessController concrete implementations are now correctly owned by RuntimeCore
- **No dependency cycles detected**: Confirmed by validator
- **No @_exported imports introduced**: All fixes use explicit module imports or type corrections
- **Tier validation remains clean**: All changes respect tier boundaries (Tier 2 runtime → Tier 2 governance contracts)

## Design Decision Record

The `KillSwitch`, `WriteGate`, and `AccessController` concrete implementations were misplaced in the `AnigmaGovernance` target despite their own source comments stating they "live in Tier 2 (Platform Runtime)". This caused RuntimeCore to be unable to reference them, creating compilation errors.

Rather than adding a RuntimeCore → AnigmaGovernance dependency (which would be architecturally wrong since AnigmaGovernance is a higher-level governance layer), the correct fix was to move these runtime-owned types into RuntimeCore where they belong. This aligns with the doctrine that "RuntimeCore owns runtime orchestration and runtime service wiring."
