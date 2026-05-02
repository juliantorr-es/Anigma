# Governance Violation Refactoring - Implementation Summary

## What Was Done

Successfully replaced stringly `governanceViolation` errors with a structured payload type that includes complete context for audit logging, policy enforcement, and operator visibility.

## Files Modified

### 1. `/anigma/Packages/GovernanceCore/GovernanceMechanisms.swift`
**Added two new types:**

- **`GovernanceViolation`** (lines 149-201)
  - Detailed violation structure for core governance operations
  - Fields: id, principal, projectId, operation, module, evaluatedModeSource, failedChecks[], timestamp
  - Includes nested `FailedCheck` struct with checkId and message
  - Has `summaryMessage` property for display

- **`GovernanceDecision`** (lines 203-219)
  - Evidence-level governance decision for audit trails
  - Fields: allowed, reason, checkResults[id->bool], evaluatedAt
  - Used by `EvidenceAuthority` to record governance in evidence bundles
  - Separated from CLI-level governance decisions to avoid conflicts

### 2. `/anigma/Packages/AnigmaCLI/Governance/GovernanceEngine.swift`
**Updated two structures:**

- **`GovernanceDecision`** (lines 27-37)
  - Added optional `violation: GovernanceViolationPayload?` field
  - Maintains backward compatibility (defaults to `nil`)
  - Contains allowed flag, issues, and optional structured violation

- **`GovernanceViolationPayload`** (lines 39-69)
  - New lightweight violation struct for task-level governance
  - Fields: principal?, projectId?, operation, module?, evaluatedModeSource?, failedCheckIds[], failedMessages[], timestamp
  - Used when governance check fails to provide detailed denial context

**Updated `GovernanceEngine.evaluate()` method** (lines 78-161)
- Now collects failed check IDs and messages
- Creates `GovernanceViolationPayload` when decision is denied
- Includes all required context for audit trails
- Maps check failures to structured violation fields

### 3. `/anigma/Packages/AnigmaCLI/Executable/Main.swift`
**Updated `AnigmaRunCommand`:**

- Added `@Flag var explain: Bool` for expanded detail display (line 643)
- Updated text output logic (lines 673-718):
  - Compact by default: shows only "governance: denied/approved"
  - Expanded when `--explain` flag or on error: shows principal, operation, module, mode source, failed checks, timestamp
  - Always shows issues list for errors
  - Added violation detail rendering with structured access
- Updated JSON output to include `explain` flag

## Architecture

### Type Hierarchy

**Tier 1 (GovernanceCore - Infrastructure)**
```
GovernanceViolation          // Core violation structure
  - id, principal, projectId, operation, module
  - evaluatedModeSource, failedChecks[], timestamp

GovernanceDecision           // Evidence-level decision
  - allowed, reason, checkResults[id->bool], evaluatedAt

WriteGateDecision            // Write gate results (unchanged)
  - allowed, checkResults[], evaluatedAt

GovernanceDenialReceipt      // Operation denial receipt (unchanged)
  - id, principal, operation, projectId, reason, failingCheckId, timestamp
```

**Tier 2 (AnigmaCLI - Application)**
```
GovernanceDecision           // Task execution governance
  - allowed, issues[], violation?

GovernanceViolationPayload   // Task denial context
  - principal?, projectId?, operation, module?, evaluatedModeSource?
  - failedCheckIds[], failedMessages[], timestamp
```

## Backward Compatibility

✅ **Fully backward compatible**
- Existing `GovernanceDecision` constructors work (violation defaults to nil)
- No breaking changes to function signatures
- Optional fields allow gradual migration
- Evidence-level GovernanceDecision in GovernanceCore doesn't conflict with CLI version (different modules)

## Governance Invariants Maintained

✅ **Kill Switch Enforcement** - Still blocks writes globally/per-project
✅ **Operating Mode Control** - Project/global mode enforcement unchanged
✅ **Write Gate Checks** - All validation checks still enforced
✅ **Admin Check** - Admin operations still checked before schema creation
✅ **Denial Mechanism** - Governance still prevents disallowed operations

## Testing

### New Test File Created
**`/anigma/Tests/GovernanceViolationStructureTests.swift`**
- Tests GovernanceViolation creation and Codable conformance
- Tests Evidence-level GovernanceDecision structure
- Tests CLI-level GovernanceViolationPayload
- Tests CLI-level GovernanceDecision with/without violations
- Integration test showing violation-to-decision flow

### Existing Tests Still Pass
- `GovernanceInvariantsTests` - Kill switch and write gate enforcement
- `GovernanceAdminTests` - Admin check validation
- `GovernancePersistenceTests` - State persistence
- `CLIOrchestratorIntegration` - Uses backward-compatible constructor

## CLI Usage Examples

### Compact Denial (Default)
```bash
$ anigma run "empty summary" --format text
task: empty summary
status: failed
message: Governance denial
governance: denied
issues:
  - error: Task summary is empty.
```

### Expanded Denial (With --explain)
```bash
$ anigma run "empty summary" --format text --explain
task: empty summary
status: failed
message: Governance denial
governance: denied
  principal: unknown
  operation: execute-task
  module: governance-engine
  failed_checks:
    - id: task-summary-empty
      message: Task summary is empty.
  timestamp: 2024-02-07T15:30:00Z
issues:
  - error: Task summary is empty.
```

### JSON Output
```bash
$ anigma run "empty summary" --format json --explain
{
  "source": "daemon",
  "explain": true,
  "outcome": {
    "governance": {
      "allowed": false,
      "issues": [...],
      "violation": {
        "principal": null,
        "projectId": null,
        "operation": "execute-task",
        "module": "governance-engine",
        "evaluatedModeSource": null,
        "failedCheckIds": ["task-summary-empty"],
        "failedMessages": ["Task summary is empty."],
        "timestamp": "2024-02-07T15:30:00Z"
      }
    }
  },
  ...
}
```

## Audit Logging Integration Ready

The structured violation payload enables audit loggers to:
- Record who (principal) attempted what (operation) in which module
- Track which checks failed and why (failedCheckIds, failedMessages)
- Know the governance context (evaluatedModeSource - project/global/default)
- Support temporal analysis with precise timestamps
- Provide detailed compliance reports with complete denial context

## No Breaking Changes

✅ All existing code paths work unchanged
✅ Optional violation field doesn't affect existing constructors
✅ Evidence-level GovernanceDecision doesn't conflict with CLI version
✅ Audit loggers can optionally access violation details
✅ CLI remains functional with default compact output
