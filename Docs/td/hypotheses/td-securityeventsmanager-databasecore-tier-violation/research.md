# SecurityEventsManager → DatabaseCore Tier Violation - Research

## Task Statement
Eliminate the SecurityEventsManager → DatabaseCore architectural boundary violation by restoring the correct architecture boundary.

## Baseline Validator Output

### validate_tiers.py Output (from anigma directory)
```
=== ANIGMA TIER VALIDATION (ADR-0006) ===

[ARCHITECTURE VIOLATION] Tier 1 Boundary Breach
  Module: SecurityEventsManager
  Illegal Dependencies: DatabaseCore
  Remediation: Tier 1 (Policy) MUST NOT depend on Tier 2 (Platform) or Tier 3 (Capability). Move shared logic to AnigmaPrimitives.
  Reference: Docs/ADR/0006-three-tier-runtime-architecture.md

=== SUMMARY ===
❌ Found 1 architectural boundary violations.
```

## Exact Violating Edge

**Source:** SecurityEventsManager (Tier 1 - Policy/Governance)
**Target:** DatabaseCore (Tier 2 - Platform)
**Edge Type:** Package.swift dependency + source import

## Files Involved

### Primary Files
1. **anigma/Package.swift:974**
   ```swift
   .target(
     name: "SecurityEventsManager", dependencies: ["DatabaseCore"],
     path: "Packages/SecurityEventsManager",
     swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)])
   ```

2. **anigma/Packages/SecurityEventsManager/SecurityEventsManager.swift:1**
   ```swift
   import DatabaseCore
   import Foundation
   ```

### Supporting Files
3. **anigma/Packages/SecurityEventsManager/SecurityTypes.swift** - Contains portable DTOs
4. **anigma/Packages/ContractsCore/Sources/PersistenceContracts/DatabaseContracts.swift** - Contains DatabaseExecutor, DatabaseParameter, DatabaseRow
5. **anigma/Packages/DatabaseCore/DatabaseExecutor.swift** - Defines DatabaseExecutor protocol

## Symbols Involved

### Types from DatabaseCore used in SecurityEventsManager
- `DatabaseExecutor` - protocol
- `DatabaseParameter` - enum
- `DatabaseRow` - struct

### SecurityTypes already portable (no DatabaseCore dependency)
- `SecurityEventType` - enum
- `SecurityEventSeverity` - enum  
- `SecurityEventDetails` - struct
- `SecurityEvent` - struct
- `SecurityEventStats` - struct

## Current Dependency Path

```
SecurityEventsManager (Tier 1)
  └── imports DatabaseCore (Tier 2) ✗ VIOLATION
        └── defines DatabaseExecutor, DatabaseParameter, DatabaseRow
        └── depends on ContractsCore (Tier 1) ❄️
              └── defines DatabaseExecutor, DatabaseParameter, DatabaseRow in PersistenceContracts
```

**Key Insight:** The database types SecurityEventsManager needs are already defined in ContractsCore/PersistenceContracts (Tier 1). SecurityEventsManager doesn't actually need to depend on DatabaseCore at all!

## Proposed Inversion Shape

### Option: Use Existing ContractsCore Types
Since DatabaseExecutor, DatabaseParameter, and DatabaseRow are already defined in ContractsCore (Tier 1), we can simply change SecurityEventsManager to import from there instead of DatabaseCore.

**Before:**
```swift
import DatabaseCore

public actor SecurityEventsManager: Sendable {
    private let database: any DatabaseExecutor
    // ... uses DatabaseExecutor, DatabaseParameter, DatabaseRow
}
```

**After:**
```swift
import Foundation
import ContractsCore  // or specifically PersistenceContracts

public actor SecurityEventsManager: Sendable {
    private let database: any DatabaseExecutor
    // ... uses DatabaseExecutor, DatabaseParameter, DatabaseRow
}
```

This requires NO new contract creation - just pointing to the existing Tier 1 versions of these types.

### Alternative: Create SecurityEventsContracts (if we want stronger abstraction)
If we want to hide the database operations behind a more security-specific interface:

```
ContractsCore/Sources/SecurityEventsContracts/
├── SecurityEventRecord.swift      // DTO (already exists as SecurityTypes)
├── SecurityEventSink.swift         // Protocol
└── SecurityEventStore.swift        // Protocol with query methods
```

But this is NOT necessary since the database types are already portable.

## Expected Changed Files

| File | Change Type | Description |
|------|-------------|-------------|
| anigma/Package.swift | Modify | Remove "DatabaseCore" from SecurityEventsManager dependencies |
| anigma/Packages/SecurityEventsManager/SecurityEventsManager.swift | Modify | Change import from DatabaseCore to ContractsCore |
| anigma/Packages/SecurityEventsManager/SecurityTypes.swift | Modify | Add import Foundation (already has it) - NO CHANGE NEEDED |

**Note:** If we want to be more explicit about the dependency, we could create a SecurityEventsContracts target and move SecurityTypes.swift there, but that's not strictly necessary.

## Minimal Change Approach (RECOMMENDED)

Since the database types are already available in ContractsCore (Tier 1), the minimal fix is:

1. Update Package.swift: Remove DatabaseCore dependency from SecurityEventsManager
2. Update SecurityEventsManager.swift: Change import from DatabaseCore to ContractsCore

This preserves all existing behavior and types while fixing the tier violation.

## Validation Plan

1. Run validate_tiers.py - should show 0 violations for SecurityEventsManager
2. Run validate_no_cycles.py - should show no new cycles
3. Run validate_exported_imports.py - should show no new issues
4. Run xcodebuild Debug for affected schemes
5. Verify SecurityEventsManager still compiles and works

## Risks

- **Low Risk:** DatabaseExecutor from ContractsCore has slightly different methods than DatabaseCore. Need to verify compatibility.
- **Medium Risk:** Some DatabaseCore extensions to DatabaseExecutor might be used in SecurityEventsManager.
- **Mitigation:** Check if SecurityEventsManager uses any DatabaseCore-specific extensions.

## Follow-up Questions

- Does SecurityEventsManager use any DatabaseCore-specific extensions to DatabaseExecutor?
- Are there any other Tier 1 modules importing DatabaseCore?
- Should we also move SecurityTypes.swift to ContractsCore for consistency?