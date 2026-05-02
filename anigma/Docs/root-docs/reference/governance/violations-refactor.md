# Governance Violation Refactoring

## Overview

Replaced stringly `governanceViolation` errors with a structured payload type that provides complete context for audit logging, policy enforcement, and operator visibility.

## Changes Made

### 1. Created `GovernanceViolation` Struct in GovernanceCore (`GovernanceMechanisms.swift`)

A detailed structured payload for governance violations that carries:
- **id**: UUID for unique violation tracking
- **principal**: Who attempted the operation
- **projectId**: Which project (if applicable)
- **operation**: What operation was denied (e.g., "execute-task")
- **module**: Which module enforced the denial
- **evaluatedModeSource**: Where the operating mode came from ("project" | "global" | "default")
- **failedChecks**: Array of failed check structures with (checkId, message)
- **timestamp**: When the violation occurred

```swift
public struct GovernanceViolation: Sendable, Codable {
    public let id: UUID
    public let principal: String
    public let projectId: String?
    public let operation: String
    public let module: String?
    public let evaluatedModeSource: String?
    public let failedChecks: [FailedCheck]
    public let timestamp: Date
}
```

### 2. Added Evidence-Level `GovernanceDecision` to GovernanceCore

Also in `GovernanceMechanisms.swift`, added a struct for evidence recording:
- Used by `EvidenceAuthority` for recording governance decisions in evidence trails
- Contains: allowed, reason, checkResults (dict of check outcomes), evaluatedAt

```swift
public struct GovernanceDecision: Sendable, Codable {
    public let allowed: Bool
    public let reason: String?
    public let checkResults: [String: Bool]
    public let evaluatedAt: Date
}
```

### 3. Updated CLI-Level `GovernanceDecision` in AnigmaCLI.Governance

Extended task-level governance decisions to include structured violation payload:

```swift
public struct GovernanceDecision: Sendable, Codable, Hashable {
    public let allowed: Bool
    public let issues: [GovernanceIssue]
    public let violation: GovernanceViolationPayload?  // NEW
}

public struct GovernanceViolationPayload: Sendable, Codable, Hashable {
    public let principal: String?
    public let projectId: String?
    public let operation: String
    public let module: String?
    public let evaluatedModeSource: String?
    public let failedCheckIds: [String]
    public let failedMessages: [String]
    public let timestamp: Date
}
```

### 4. Updated `GovernanceEngine.evaluate()` in AnigmaCLI

Now builds structured `GovernanceViolationPayload` when governance check fails:
- Collects failed check IDs and messages
- Creates violation only when decision is denied (`allowed == false`)
- Includes all required context for audit trails

### 5. Updated CLI Output in `Main.swift`

Added `--explain` flag for expanded governance denial details:

**Compact output (default)**:
```
governance: denied
issues:
  - error: Task summary is empty.
```

**Expanded output (with `--explain`)** or when governance denied:
```
governance: denied
  principal: unknown
  operation: execute-task
  module: governance-engine
  failed_checks:
    - id: task-summary-empty
      message: Task summary is empty.
  timestamp: 2024-02-07T10:30:00Z
issues:
  - error: Task summary is empty.
```

## Governance Invariants Maintained

✅ **Write Gate Enforcement**: Kill switch checks still block writes
✅ **Operating Mode Control**: Project and global modes still enforced  
✅ **Backward Compatibility**: Existing `GovernanceDecision` constructors default `violation` to `nil`
✅ **Audit Trail**: Structured violations enable comprehensive audit logging
✅ **Denial Visibility**: Operators can see detailed reasons for governance denials

## Type Architecture

### Tier 1 (GovernanceCore)
- `GovernanceViolation` - Detailed violation structure for core operations
- `GovernanceDecision` - Evidence-level governance record
- `WriteGateDecision` - Write gate evaluation results
- `GovernanceDenialReceipt` - Operation denial receipt

### Tier 2 (AnigmaCLI)
- `GovernanceDecision` (CLI-level) - Task execution governance with issues and violations
- `GovernanceViolationPayload` - Lightweight violation for task routing
- `GovernanceEngine` - Task contract evaluation

## Testing

All existing governance tests continue to pass:
- `GovernanceInvariantsTests` - Kill switch and write gate enforcement
- `GovernanceAdminTests` - Admin check policies
- `GovernancePersistenceTests` - State persistence across restarts

New violation payloads are created but don't break existing code paths.

## Migration Notes

- No changes required to existing code using `GovernanceDecision` 
- The `violation` field is optional (defaults to `nil`)
- Audit loggers can now access structured violation payloads via `outcome.governance.violation`
- CLI expands detailed denial info with `--explain` flag
