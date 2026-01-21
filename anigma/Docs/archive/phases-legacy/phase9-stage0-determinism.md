# Phase 9.1 Stage 0 Determinism Rules

## Overview

Phase 9.1 introduces Stage 0 (Target Enumeration) as a first-class deterministic stage in the autonomous self-improvement loop. This ensures that multi-target enumeration maintains the same strong determinism guarantees as the rest of the Phase 9.0 pipeline.

## Stage 0: Target Enumeration

### What it does
- Deterministically enumerates improvement targets from IR within a bounded scope
- Applies policy-driven scoring to rank targets (highest score first)
- Limits output to `maxTargetsToProcess` from StopCondition policy
- Emits a Stage 0 artifact containing enumeration results, policy hashes, and metadata

### Determinism requirements
- **Canonical ordering**: Targets must be sorted deterministically by score then targetId
- **Policy pinning**: ScoringPolicy and StopCondition are recorded as pinned inputs
- **Workspace integrity**: Enumeration references a single workspace snapshot hash
- **Sequential ranks**: Ranks must be 1..N with no gaps (validated by TargetEnumerationContract)

## In-Run Determinism Validation

### Enumeration Determinism
```swift
// Validator catches divergence before stage boundary completes
try await determinismValidator.recordEnumeration(
    scope: "directory:sources", 
    targets: enumeratedTargets,
    scoringPolicyHash: policyHash,
    digest: enumerationHash
)
```

Validation checks:
- **Digest consistency**: Same scope+policy must produce identical digest across runs
- **Target ordering**: Target IDs must maintain exact ordering across runs
- **Policy hash**: ScoringPolicy changes immediately fail enumeration determinism

### Selection Determinism
```swift
// Enforces rank-1 selection constraint
try await determinismValidator.recordSelection(
    selectedTargetId: target.targetId,
    rank: 1,  // Must be rank 1
    rationale: "Top-ranked target from enumeration"
)
```

Constraints:
- **Rank-1 only**: Selected target must be rank 1 (highest score)
- **Selection hash**: Same enumeration must produce same selection across runs
- **Rationale tracking**: Selection reasons are recorded for audit

### Single-Commit Invariant
```swift
// Enforces exactly one commit per run
try await commitEnforcer.attemptCommit(reason: "Stage 6 state transition")
```

Invariant:
- **One transition**: Maximum one state transition per run (even with multi-target enumeration)
- **Policy enforcement**: StopCondition.maxSuccessfulTransitions limits commits
- **Rejection on violation**: Second commit attempt immediately fails with precise error

## Runtime Evidence Collection

### Stage Evidence Records
At each stage boundary, RuntimeEvidenceCollector captures:
- **Inputs**: Parameters, policies, and environmental state
- **Outputs**: Results, hashes, and derived data
- **Artifacts**: Stage boundary artifacts and validation results
- **Metrics**: Performance and determinism metrics
- **Governance**: Policy decisions and enforcement actions

### Evidence Verification
```swift
// End-to-end evidence chain verification
let verification = try evidenceCollector.verifyEvidenceChain()
assertion(verification.stageCount == 8)  // Stages 0-7
assertion(verification.verified)         // No broken links
```

Verification checks:
- **Stage sequence**: All stages 0-7 present in order
- **Digest integrity**: Each stage has valid evidence digest
- **Snapshot consistency**: Workspace snapshot unchanged across stages

## Failure Modes and Recovery

### Enumeration Divergence
**Detection**: `DeterminismError.enumerationDivergence`
- **Cause**: Same inputs produce different enumeration results
- **Recovery**: Check IR state, policy version, and workspace snapshot
- **Remediation**: Reset environment, repin inputs, re-run enumeration

### Target Ordering Drift
**Detection**: `DeterminismError.targetOrderingDivergence`
- **Cause**: Non-deterministic iteration order or unstable comparison
- **Recovery**: Use canonical sorting (score then targetId), verify comparison functions
- **Remediation**: Ensure sorting functions are pure and deterministic

### Selection Violation
**Detection**: `DeterminismError.selectionViolation`
- **Cause**: Selected target not rank 1 or selection changes across runs
- **Recovery**: Check scoring policy, enumeration results, ranking algorithm
- **Remediation**: Verify ranking is stable and top target is consistently selected

### Single-Commit Violation
**Detection**: `SingleCommitError.multipleCommitAttempts`
- **Cause**: Multiple state transition attempts in single run
- **Recovery**: Review StopCondition settings and transition logic
- **Remediation**: Ensure invariant checking occurs before every commit attempt

## Testing and Verification

### Unit Tests
- `Phase9Stage0Tests`: Enumeration, selection, and single-commit invariant tests
- Negative tests verify violations are caught immediately
- Positive tests verify deterministic behavior across runs

### Integration Tests
- Dual-run verification tests prove Stage 0-7 determinism end-to-end
- Concurrency stress tests validate in-run validation under load
- Failure fixture tests verify surgical error reporting

### CI Integration
- Must run dual-run with Stage 0 enabled
- Requires full evidence chain verification pass
- Validates single-commit invariant enforcement

## Implementation Details

### Key Components
- **InRunDeterminismValidator**: Live validation during execution
- **SingleCommitInvariantEnforcer**: Enforces one transition per run
- **RuntimeEvidenceCollector**: Comprehensive evidence capture
- **StageArtifact**: Unified stage boundary structure

### Integration Points
- **Phase90Orchestrator**: Main loop driver with validation hooks
- **Phase9LoopKernel**: Pure computation with deterministic guarantees
- **Phase9ReplayVerifier**: End-to-end verification of canonical artifacts

## Migration from Phase 9.0

### Changes Required
1. Update test harnesses to expect 8 stages instead of 7
2. Add Stage 0 validation to dual-run tests
3. Capture evidence at all stage boundaries
4. Verify single-commit invariant in commit Stage 6

### Backward Compatibility
- Phase 9.0 runs without Stage 0 still supported via legacy mode
- Verification automatically detects and validates both 7-stage and 8-stage runs
- Evidence collection is optional but recommended for audit

### Performance Impact
- In-run validation adds minimal overhead (<1ms per stage)
- Evidence collection lightweight (KB per stage, not MB)
- Determinism validation prevents expensive verification failures later

## Future Enhancements

### Phase 9.2: Concurrency Hardening
- Actor isolation for per-target work
- Concurrent enumeration with deterministic ordering
- Stress tests for multi-threaded environments

### Phase 9.3: Policy Evolution
- Versioned ScoringPolicy with rollback
- Governance gates for policy updates
- Metrics-driven policy effectiveness

## Conclusion

Phase 9.1 Stage 0 brings deterministic multi-target enumeration while preserving the strong determinism guarantees of Phase 9.0. The in-run validation, single-commit invariant enforcement, and evidence collection systems ensure that non-deterministic behavior is caught immediately, not just during verification.