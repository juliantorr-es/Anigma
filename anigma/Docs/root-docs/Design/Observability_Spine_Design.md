# Design: Anigma Observability Spine

**Author:** Gemini CLI (ses_f7e637)
**Status:** DRAFT (Design Phase)
**Date:** 2026-01-11
**Version:** 1.0.0

## 1. Overview
The Observability Spine provides the unified identity, provenance, and evidence trail for the statically composed Tier 2 runtime. It prevents provenance drift by enforcing a strict hierarchy of identifiers and by separating governed evidence from redacted telemetry.

This document is aligned with the implementation-backed static architecture set:

- `anigma/Docs/design/DAEMON_KERNEL_BOUNDARY_SPECIFICATION.md`
- `anigma/Docs/design/FIRST_FEATURE_STATIC_WIRING.md`
- `anigma/Docs/design/VERIFIER_LANE_FRAMEWORK_DESIGN.md`
- `anigma/Docs/design/EVALUATION_MATRIX_TEST_METHODOLOGY.md`
- `anigma/Docs/design/STATIC_PLUGIN_REGISTRATION_RESEARCH.md`
- `anigma/Docs/design/PLUGIN_BOUNDARY_ENFORCEMENT_RESEARCH.md`
- `anigma/Docs/guides/STATIC_PLUGIN_ARCHITECTURE_STABILIZATION.md`
- `docs/architecture/plugins.md`

## 2. Canonical Identity and Provenance Registry

All identifiers MUST conform to the hierarchical namespace to preserve provenance at every scale.

```swift
public struct AnigmaSpineIdentity: Sendable, Codable {
    public let projectID: ProjectID     // Institutional tenant boundary
    public let principalID: PrincipalID // Request originator
    public let sessionID: SessionID     // Interaction window
    public let runID: RunID             // Task execution
    public let episodeID: EpisodeID     // Provenance segment
}
```

- **Validation Rule**: All Tier 2 authorities (`Database`, `Evidence`, `Execution`) must validate that inbound requests contain a valid `ProjectID` and `RunID` before processing.
- **Propagation**: identity and provenance flow via `CorrelationIDContext` (`TaskLocal`).

## 3. Implicit Context Flow (`@TaskLocal`)

To preserve provenance across `async` boundaries without explicit context passing in every API, we use Swift 6 task locals.

```swift
public struct CorrelationIDContext {
    @TaskLocal public static var current: AnigmaSpineIdentity?
    
    public static func withContext<T>(_ identity: AnigmaSpineIdentity, operation: () async throws -> T) async rethrows -> T {
        try await $current.withValue(identity) {
            try await operation()
        }
    }
}
```

- **Usage**: Every daemon, bridge, or orchestrator entry point is wrapped in `withContext` before it reaches the kernel or verifier lane.

## 4. The Dual-Stream Evidence Plane

### 4.1 Audit Flow (The Governed Evidence Path)
The `EvidenceAuthority` provides high-fidelity, tamper-evident evidence.
- **Input**: `EvidencePayload` (Workflow result, Model Hash, Decision).
- **Storage**: synchronous ACID transaction in PostgreSQL `audit_logs`.
- **Integrity**: Each record is cryptographically linked to the previous one via a `previousHash` field (Hash-Chaining).

### 4.2 Telemetry Flow (The Redacted Observability Path)
The `TelemetryClient` provides high-performance, privacy-first telemetry.
- **Pipeline**: `Sampling -> Redaction (DiagnosticRedactionRules) -> Hashing (BLAKE3) -> WireRedactedEvent`.
- **Sink Strategy**: `RotatingFileTelemetrySink` for local persistence; `CompositeTelemetrySink` for live monitoring (console/memory).

## 5. Spine State Tracking (Provenance View)

The `HarmoniaConductor` maintains an active provenance tree.
- **Mechanism**: Agents emit `TraceEvent` records during execution.
- **UI Mechanism**: The Provenance View subscribes to these events using a lightweight `AsyncStream` subscription, allowing real-time tree visualization of active episodes and runs.

## 6. Implementation Interfaces

```swift
/// Protocol all authorities must implement for logging/provenance
public protocol SpineEnabledAuthority: Actor {
    func record(
        event: TelemetryEvent, 
        audit: EvidencePayload?
    ) async throws
}
```

## 7. Alignment Notes

- `DAEMON_KERNEL_BOUNDARY_SPECIFICATION.md` defines the hard contracts-only kernel boundary that this spine must respect.
- `FIRST_FEATURE_STATIC_WIRING.md` defines the explicit wiring pattern that feeds provenance and evidence into the composed runtime.
- `VERIFIER_LANE_FRAMEWORK_DESIGN.md` defines how the verifier lane consumes the same composed runtime shape.
- `EVALUATION_MATRIX_TEST_METHODOLOGY.md` defines the evidence-backed reporting vocabulary that should match this spine.
- `STATIC_PLUGIN_REGISTRATION_RESEARCH.md` and `PLUGIN_BOUNDARY_ENFORCEMENT_RESEARCH.md` provide the implementation evidence for the static split.
- `STATIC_PLUGIN_ARCHITECTURE_STABILIZATION.md` and `docs/architecture/plugins.md` are the broader architecture references.

---
**Status**: Aligned with implementation-backed design set
**Next Steps**: Keep terminology synchronized with the kernel boundary, verifier lane, and evaluation matrix docs.
