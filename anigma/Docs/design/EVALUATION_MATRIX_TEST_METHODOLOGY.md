# Evaluation Matrix and Test Methodology Design

## Status
**Design Phase** (2026-04-17)

## Context

This document defines the evaluation matrix used by the verifier lane. It is not a standalone evaluation platform; it is the reporting and test-method vocabulary for a statically composed runtime.

The design is aligned with:

1. `VERIFIER_LANE_FRAMEWORK_DESIGN.md`
2. `DAEMON_KERNEL_BOUNDARY_SPECIFICATION.md`
3. `FIRST_FEATURE_STATIC_WIRING.md`
4. `STATIC_PLUGIN_REGISTRATION_RESEARCH.md`
5. `PLUGIN_BOUNDARY_ENFORCEMENT_RESEARCH.md`
6. `STATIC_PLUGIN_ARCHITECTURE_STABILIZATION.md`
7. `anigma/Docs/root-docs/architecture/plugins.md`

## Design Goals

1. Use verifier-lane language backed by evidence records.
2. Describe matrix outputs as findings from the composed runtime, not generic test scores.
3. Keep performance, safety, compliance, and reliability as the primary dimensions.
4. Tie each metric to kernel boundary checks, wiring targets, and trace/evidence capture.
5. Avoid any wording that implies dynamic plugin discovery or independent evaluation infrastructure.

## Runtime Shape

```mermaid
graph TD
    Exec[Executable composition root] --> Kernel[DaemonKernel]
    Exec --> Wiring[Static wiring targets]
    Wiring --> Contracts[DaemonFeatureContracts]
    Wiring --> Impl[Feature implementation targets]
    Kernel --> Registry[DaemonFeatureRegistry]
    Kernel --> Bootstrap[bootstrapKernel(_:with:)]
    Exec --> Lane[Verifier Lane Coordinator]
    Lane --> Evidence[Evidence records]
    Lane --> Matrix[Evaluation matrix]
    Lane --> Report[Verification report]
```

The verifier lane observes the statically linked runtime:

- the executable decides which wiring targets ship
- `DaemonKernel` stays contracts-only
- wiring targets bridge contracts to feature implementations
- evidence records capture what the composed runtime actually did

## Shared Vocabulary

- **Kernel**: `DaemonKernel`
- **Contracts**: `DaemonFeatureContracts`
- **Wiring**: `*DaemonFeature` targets
- **Composition root**: the executable target
- **Verifier lane**: the evidence-backed verification path
- **Evidence record**: a traceable finding tied to a run, boundary check, or metric
- **Matrix finding**: a normalized result derived from evidence

## Evaluation Matrix

### Primary dimensions

| Dimension | What it measures | Evidence source |
|---|---|---|
| Performance | latency, throughput, resource cost | run metrics, traces, build timing |
| Safety | failure modes, risk, forbidden behavior, privacy harm | verifier findings, boundary violations, privacy invariant checks |
| Compliance | governance adherence, audit completeness, regulated-decision readiness | policy checks, evidence records, impact assessment references |
| Reliability | stability, recovery, consistency | repeated runs, failure traces, recovery evidence |

### Metric guidance

- **Performance** should describe observed execution behavior in the composed runtime.
- **Safety** should report violations, blocked actions, and failure conditions.
- **Safety** should include privacy failures such as raw sensitive payloads in immutable receipts, cross-tenant retrieval, or unapproved training/eval use.
- **Compliance** should report whether the run stayed within governance, privacy, regulated-decision, and boundary policy.
- **Reliability** should report repeatability, recovery, and deterministic behavior.

These metrics are valid only when attached to a concrete verifier-lane finding.

## Test Methodology

### 1. Define the verification subject

The subject is a specific composed runtime, identified by:

- executable target
- wiring targets included
- kernel build identifier
- trace/evidence identifiers

### 2. Execute against the static runtime

Run scenarios through the executable composition root and the verifier lane. Do not introduce runtime feature discovery or a separate plugin host.

### 3. Capture evidence

Record:

- kernel boundary checks
- wiring-target participation
- trace identifiers
- policy decisions
- privacy class, purpose, retention, provider eligibility, and regulated-decision metadata where applicable
- metric snapshots
- any violated invariant

### 4. Normalize into matrix findings

Map evidence into the four primary dimensions. Keep the raw evidence and the interpretation separate.

### 5. Publish the report

The report should summarize:

- the composed runtime shape
- the evidence used
- the matrix finding per dimension
- any boundary or governance exceptions

## Boundary and Wiring Constraints

The evaluation matrix must reflect the actual architecture:

- `DaemonKernel` depends on `DaemonFeatureContracts` only.
- wiring targets import contracts plus their feature implementation.
- executables explicitly list included wiring targets.
- feature imports in kernel/contracts are policy failures, not just lower scores.
- missing privacy/purpose metadata for sensitive missions and missing human-review metadata for regulated decisions are policy failures, not lower scores.

See:

- `anigma/Docs/design/DAEMON_KERNEL_BOUNDARY_SPECIFICATION.md`
- `anigma/Docs/design/FIRST_FEATURE_STATIC_WIRING.md`
- `anigma/Docs/design/STATIC_PLUGIN_REGISTRATION_RESEARCH.md`
- `anigma/Docs/design/PLUGIN_BOUNDARY_ENFORCEMENT_RESEARCH.md`
- `anigma/Docs/design/PRIVACY_COMPLIANCE_REGULATED_DECISIONING_SPINE.md`
- `anigma/Docs/root-docs/architecture/plugins.md`

## Evidence-Backed Reporting

Preferred report shape:

```swift
struct VerificationFinding: Sendable {
    let dimension: String
    let value: Double
    let evidenceIDs: [String]
    let boundaryReferences: [String]
    let interpretation: String
}
```

The matrix should never invent a score without traceable findings. If a metric cannot be linked to evidence, it is not ready for reporting.

## Success Criteria

- The document uses verifier-lane vocabulary throughout.
- The matrix is described as evidence-backed and architecture-aware.
- Boundary enforcement and static wiring are cross-referenced explicitly.
- No section implies dynamic plugin loading or detached evaluation infrastructure.
- Performance, safety, compliance, and reliability remain the core dimensions.

## References

- `VERIFIER_LANE_FRAMEWORK_DESIGN.md`
- `DAEMON_KERNEL_BOUNDARY_SPECIFICATION.md`
- `FIRST_FEATURE_STATIC_WIRING.md`
- `STATIC_PLUGIN_REGISTRATION_RESEARCH.md`
- `PLUGIN_BOUNDARY_ENFORCEMENT_RESEARCH.md`
- `STATIC_PLUGIN_ARCHITECTURE_STABILIZATION.md`
- `anigma/Docs/root-docs/architecture/plugins.md`
