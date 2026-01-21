# Phase 9.0 Replay Verifier Implementation

## Overview

The Phase9ReplayVerifier subsystem provides surgical failure reporting with byte-level divergence detection for deterministic replay verification. It implements the complete verification pipeline described in the Phase 9.0 specifications, ensuring that autonomous self-improvement loops can be proven deterministic and auditable.

## Component Architecture

### Core Components

#### 1. VerificationTypes.swift - Foundational Data Structures
- **VerificationInputs**: Deterministic inputs required for replay verification
- **VerificationResult**: Pass/Fail results with detailed failure information
- **ReplayFailureReport**: Surgical failure report with byte-offset diagnostics
- **StageArtifact**: Stage boundary artifact with canonical encoding and BLAKE3 digest

#### 2. GovernanceEventLogParser.swift - Event Log Processing
- **GovernanceEventLogParser**: Deserializes event log bytes into structured data
- **ParsedEventLog**: Structured log with metadata for verification
- **EventLogMetadata**: Extracted event metadata for validation

#### 3. LogPrecheck.swift - Pinned Input Validation
- **LogPrecheck**: Validates pinned inputs before expensive verification
- **PrecheckResult**: Precheck validation results
- **PinnedInputs**: Extracted pinned inputs for comparison

#### 4. StageArtifactIndex.swift - Stage Artifact Indexing
- **StageArtifactIndex**: Efficient lookup for stage boundary artifacts
- **ArtifactIndexBuilder**: Builds reliable indexes with validation
- **ArtifactExtractionResult**: Results of artifact extraction

#### 5. Phase9RecomputePlan.swift - Deterministic Recomputation
- **Phase9RecomputePlan**: Implements StageArtifactProducer protocol
- **ReplayVerificationPayload**: Results of recomputation
- **Phase9RecomputePlanBuilder**: Builder with validation and caching

#### 6. StageArtifactComparator.swift - Byte-Level Diffing
- **StageArtifactComparator**: Surgical failure detection and reporting
- **PayloadComparisonResult**: Payload-level comparison results
- **findFirstDiffOffset()**: Locates first byte divergence

#### 7. Phase9ReplayVerifier.swift - Entry Point
- **Phase9ReplayVerifier**: Main verification entry point
- **VerificationDiagnosticsResult**: Detailed diagnostics for debugging
- **Phase9ReplayVerifierFactory**: Factory for creating configured verifiers

## Key Features

### Surgical Failure Reporting
The verifier provides byte-level precision in failure reporting:
- First divergent stage identifier
- Exact byte offset where divergence occurs
- Context window (32 bytes) around the divergence point
- Classification of divergence type (canonicalization drift, ordering drift, etc.)

### Deterministic Verification Pipeline
The verification follows these steps:
1. Parse event log into structured data
2. Precheck pinned inputs for basic environment mismatch
3. Extract recorded stage boundary artifacts
4. Recompute artifacts deterministically from inputs only
5. Compare artifacts byte-by-byte to detect divergence
6. Report first divergence with surgical detail

### Comprehensive Test Suite
The determinism harness includes 8 comprehensive tests:
- **Single Replay Test**: Verifies single execution passes
- **Dual Run Test**: Ensures identical results on repeated execution
- **Concurrency Stress Test**: Validates thread safety with parallel verification
- **Input Variance Test**: Proves failure when inputs change
- **Environment Variance Test**: Validates environment hash detection
- **Byte-Level Divergence Test**: Tests precise byte offset reporting
- **Diagnostics Test**: Validates detailed failure reporting
- **Artifact Index Test**: Validates artifact extraction and indexing

## Integration with Phase 8.5 Foundation

The verifier builds on the Phase 8.5 deterministic foundation:
- Uses **CanonicalJSONEncoder** for stable serialization
- Uses **BLAKE3Hasher** for collision-resistant hashing
- Leverages **GovernanceEventSchemas** for structured event processing
- Integrates with **Phase9LoopKernel** for deterministic computation

## Usage Example

```swift
// Create verification inputs
let inputs = VerificationInputs(
    eventLogBytes: eventLogBytes,
    workspaceSnapshotHash: "workspace-12345",
    policyPackHash: "policy-67890",
    normalizerVersion: "1.0.0",
    toolchainFingerprint: "swift-5.9.0-macos",
    sessionSeed: "seed-42"
)

// Create verifier
let kernel = Phase9LoopKernel(...)
let verifier = Phase9ReplayVerifierFactory.createStandard(kernel: kernel)

// Run verification
let result = try verifier.verify(inputs)

switch result {
case .pass(let artifact):
    print("Verification passed for \(artifact.stageCount) stages")
case .fail(let report):
    print("Verification failed with \(report.classification) at stage \(report.stage)")
}
```

## Future Work

The verifier is ready for integration with Phase 9.0 autonomous loops and can be extended with:

1. **Parallel verification optimization**: Improve concurrency stress test performance
2. **Artifact caching**: Cache recomputation results for efficiency
3. **More divergence classifications**: Expand classification categories
4. **Delta compression**: Store only divergent bytes for large payloads
5. **Cross-run correlation**: Correlate failures across multiple runs

## Testing

Run the complete test suite with:

```bash
swift test --target HarmoniaModuleTests --filter Phase9DeterminismTests
```

The tests verify the verifier works correctly under various conditions and can confidently detect actual divergences with surgical precision.