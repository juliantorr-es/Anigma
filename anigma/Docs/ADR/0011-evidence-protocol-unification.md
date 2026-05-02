> **⚠️ SATURATED REVIEW PENDING**  
> This ADR is pending review for compatibility with the **Saturated Autonomous** architecture. Use with caution.

# ADR-0011: Evidence Protocol Unification

## Status
ACCEPTED (2025-12-31)

## Context

The Anigma repository had three competing protocols for evidence recording:

1. **`AnigmaCore.EvidenceRecorder`** - Internal protocol for IR graph tracing
2. **`ContractsCore.EvidenceRecording`** - General evidence for state transitions and governance proofs
3. **`AnigmaPrimitives.EvidenceRecorder`** - Tool router loop detection events

This fragmentation created several problems:
- Incompatible method signatures across protocols
- Unclear which protocol to use for new evidence needs
- Evidence chain integrity could not be uniformly verified

## Decision

We unified evidence recording by clarifying semantic boundaries:

| Protocol | Purpose | Location |
|----------|---------|----------|
| `ContractsCore.EvidenceRecording` | State transitions, governance proofs, court-safe evidence | Boundary contracts |
| `AnigmaPrimitives.LoopEvidenceRecorder` | Tool call loop detection, safety telemetry | Tool router |
| `AnigmaCore.EvidenceRecorder` (DEPRECATED) | Internal IR graph tracing | Legacy, migrate away |

### Protocol Boundaries (Enforced)

**ContractsCore.EvidenceRecording** is for:
- Recording workflow state transitions
- Creating audit trails for governance decisions
- Evidence that may need to be presented externally

**AnigmaPrimitives.LoopEvidenceRecorder** is for:
- Tool call loop detection events
- Circuit breaker telemetry
- Internal safety signals (not governance evidence)

**AnigmaCore.EvidenceRecorder** is deprecated and should be migrated to one of the above based on semantic intent.

### Migration Applied

1. Renamed `AnigmaPrimitives.EvidenceRecorder` → `LoopEvidenceRecorder` with `Sendable` conformance
2. Added backward-compatible typealias with deprecation warning
3. Updated all HarmoniaModule callsites (ToolRouter, ToolCallLoopBreaker, MockEvidenceRecorder, FileEvidenceRecorder)
4. Added deprecation warning to `AnigmaCore.EvidenceRecorder`

## Consequences

### Positive
- Clear semantic boundaries prevent protocol confusion
- New evidence needs have unambiguous home
- Evidence chain integrity can be verified per-protocol

### Negative
- Third-party code using deprecated protocols needs migration
- Deprecation warnings will appear until cleanup complete

### Rules for Future Development

1. **Never use LoopEvidenceRecorder for general evidence.** It is specifically for tool-loop safety signals.
2. **Never add evidence methods to AnigmaCore.EvidenceRecorder.** It is deprecated; use ContractsCore.EvidenceRecording.
3. **If unsure, use ContractsCore.EvidenceRecording.** It is the default for new evidence needs.

## Verification

```bash
# Check that only TelemetryCore defines loop evidence
rg "protocol LoopEvidenceRecorder" Sources/

# Verify deprecated protocol has warning
rg "@available.*deprecated.*EvidenceRecorder" Sources/
```

## References

- Convergence Plan Stage 1 (2025-12-31)
- [ToolContracts.swift](file:///Users/user/Developer/GitHub/Anigma/Sources/AnigmaPrimitives/ToolContracts/ToolContracts.swift) - LoopEvidenceRecorder definition
- [ContractsCore.swift](file:///Users/user/Developer/GitHub/Anigma/Sources/ContractsCore/ContractsCore.swift) - EvidenceRecording definition
