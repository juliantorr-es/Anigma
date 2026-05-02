# RuntimeGovernance Stub Alignment

## Summary

Aligned the RuntimeGovernance struct in AnigmaCoreJobsRuntimeStub.swift with a defined governance interface by:

1. Defining `RuntimeGovernanceAPI` protocol
2. Creating stub `GovernanceController` actor that conforms to the protocol
3. Keeping `RuntimeGovernance` struct for backward compatibility

## Changes Made

### File: Packages/AnigmaCore/Sources/AnigmaCore/AnigmaCoreJobsRuntimeStub.swift

#### 1. Added RuntimeGovernanceAPI Protocol (lines ~1177-1182)
```swift
/// Protocol defining the minimal runtime governance API.
/// Implemented by both stub and real governance controllers.
public protocol RuntimeGovernanceAPI {
    /// Initialize governance (optionally with database persistence)
    func initialize(using database: any DatabaseAuthority) async throws
}
```

#### 2. Kept RuntimeGovernance Struct (lines ~1189-1200)
- Unchanged - provides backward compatibility for CodexModule
- Has `writeGate: RuntimeWriteGate` and `auditLog: RuntimeAuditLog`
- Used by `CodexModule.initialize(governance: RuntimeGovernance)`

#### 3. Added Stub GovernanceController Actor (lines ~1202-1217)
```swift
/// Stub GovernanceController for runtime stub environments.
/// Conforms to RuntimeGovernanceAPI for protocol-based usage.
public actor GovernanceController: RuntimeGovernanceAPI {
    public let writeGate: RuntimeWriteGate
    public let auditLog: RuntimeAuditLog
    
    public init() {
        self.writeGate = RuntimeWriteGate()
        self.auditLog = RuntimeAuditLog()
    }
    
    /// Stub implementation - does nothing
    public func initialize(using database: any DatabaseAuthority) async throws {
        // No-op stub implementation
    }
}
```

## Design Decisions

### Why Two Types?

1. **RuntimeGovernance (struct)**: Legacy type used by CodexModule for governance registration
   - Provides `writeGate` and `auditLog` for module initialization
   - Sendable struct with actor properties

2. **GovernanceController (actor)**: Stub actor matching real governance interface
   - Used by PlatformRuntime
   - Conforms to RuntimeGovernanceAPI
   - Provides same interface as real GovernanceController from Governance.swift

### Protocol Design

The `RuntimeGovernanceAPI` protocol is minimal by design:
- Only defines `initialize(using:)` method
- Can be extended later with additional governance operations
- Allows both stub and real implementations to conform

### No Domain Type Definitions

The stub does NOT define domain types like:
- `OperatingMode` - imported from GovernanceCore
- `WriteProposal` - imported from GovernanceCore
- These should come from real modules, not stubs

## Integration Points

### PlatformRuntime Stub
- Uses `governance: GovernanceController` (line 1229)
- Calls `governance.initialize(using: database)` (line 1230)
- Returns it via `getGovernanceForKernel()` (line 1285)

### CodexModule
- Uses `RuntimeGovernance` for module initialization
- Accesses `governance.writeGate.registerCheck()`
- Accesses `governance.auditLog.record()`

### Future: Real GovernanceController
The real `GovernanceController` in `Governance.swift` can conform to `RuntimeGovernanceAPI` by adding:
```swift
extension GovernanceController: RuntimeGovernanceAPI {
    // Already has initialize(using:) method
}
```

## Testing

To verify:
1. Check CodexModule still compiles with RuntimeGovernance usage
2. Check PlatformRuntime stub compiles with GovernanceController usage
3. Verify no domain types are defined in stub (should import from real modules)

## Risk Assessment

**Risk Level: LOW**

- Added protocol conformance to existing types
- Created new stub actor to match expected interface
- No breaking changes to existing code
- Backward compatible with CodexModule usage

## Commit Message

```
feat(governance): align RuntimeGovernance stub with protocol API

- Add RuntimeGovernanceAPI protocol for governance interface
- Create stub GovernanceController actor implementing protocol
- Keep RuntimeGovernance struct for backward compatibility
- Enable PlatformRuntime stub to use governance as protocol type
- No domain type definitions in stub (import from real modules)
```
