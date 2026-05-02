# ARCHIVED SPECULATIVE DESIGN: Daemon Kernel Boundary Specification

> [!WARNING]
> **SPECULATIVE DESIGN ONLY**: This document describes a speculative system-call/kernel-space model that is **NOT** implemented in the current Anigma architecture. It is preserved here for historical design context only.
>
> **Current Implementation**: See `anigma/Docs/design/DAEMON_KERNEL_BOUNDARY_SPECIFICATION.md` for the active static-plugin architecture.
>
> **TD Status**: TD is the source of truth for live task status, blockers, dependency order, and review state.

**Author:** Mistral Vibe
**Status:** ARCHIVED / SPECULATIVE
**Date:** 2026-04-16
**Version:** 1.0.0 (NON-IMPLEMENTED)
**Epic:** Harmonia V3 Transition (Speculative)

## 1. Overview

The Daemon Kernel Boundary Specification defines the architectural boundary between the Anigma daemon kernel and user-space components. This specification ensures strict isolation, security, and performance guarantees while enabling seamless integration with the broader Anigma platform.

This document aligns with the following foundational documents:

- `INTEGRATED_DESIGN_BLUEPRINT.md` — Three-Tier Architecture and Governed Write Loop
- `Governed_Persistence_Design.md` — PostgreSQL Schema and RLS Strategy
- `Observability_Spine_Design.md` — Identity, Provenance, and Evidence Spine

## 2. Kernel Boundary Principles

### 2.1 Isolation and Security

The daemon kernel operates in a privileged execution context with strict isolation from user-space components:

- **Privilege Separation**: Kernel-space code runs with elevated privileges, while user-space components operate in a sandboxed environment.
- **Memory Protection**: Kernel and user-space memory are strictly separated to prevent unauthorized access.
- **System Call Interface**: All interactions between user-space and kernel-space are mediated through a well-defined system call interface.

### 2.2 Minimal Surface Area

The kernel boundary exposes a minimal and stable interface to user-space components:

- **Stable ABI**: The system call interface is versioned and backward-compatible.
- **Least Privilege**: Each system call is granted the minimum necessary privileges.
- **Auditability**: All system calls are logged and auditable for security and compliance.

### 2.3 Performance and Efficiency

The kernel boundary is optimized for performance and efficiency:

- **Zero-Copy Data Transfer**: Data is passed between kernel and user-space without unnecessary copying.
- **Asynchronous Operations**: Non-blocking system calls are supported to maximize throughput.
- **Hardware Acceleration**: Kernel-space leverages hardware acceleration (e.g., GPU, ANE) for critical operations.

## 3. Kernel Boundary Architecture

### 3.1 System Call Interface

The system call interface is the primary mechanism for user-space components to interact with the kernel:

```swift
protocol KernelSystemCallInterface {
    // Governed Write Loop
    func proposeWrite(principal: PrincipalID, operation: WriteOperation, entity: EntityID, context: CorrelationIDContext) async throws -> WriteProposal
    func executeWrite(proposal: WriteProposal) async throws -> CoreReceipt
    
    // Evidence and Telemetry
    func submitEvidence(receipt: CoreReceipt) async throws -> EvidenceAcknowledgment
    func submitTelemetry(span: TelemetrySpan) async throws -> TelemetryAcknowledgment
    
    // Hardware Authority
    func requestHardwareLane(workload: HardwareWorkload) async throws -> HardwareLaneAssignment
    func releaseHardwareLane(assignment: HardwareLaneAssignment) async throws
    
    // Job Execution
    func submitJob(job: JobDefinition) async throws -> JobID
    func queryJobStatus(jobID: JobID) async throws -> JobStatus
}
```

### 3.2 Kernel-Space Components

The kernel-space components provide core functionality and enforce security policies:

| Component | Responsibility | Integration Target |
| :--- | :--- | :--- |
| **`KernelGovernanceController`** | Enforces governed write loop | `DatabaseAuthority` |
| **`KernelEvidenceAuthority`** | Manages evidence receipts | `audit_logs` table |
| **`KernelHardwareAuthority`** | Manages hardware lanes | Metal / CoreML |
| **`KernelExecutionAuthority`** | Orchestrates job execution | `JobStore` |

### 3.3 User-Space Components

User-space components interact with the kernel through the system call interface:

| Component | Responsibility | Integration Target |
| :--- | :--- | :--- |
| **`RuntimeServicesProxy`** | Mediates system calls | Kernel System Call Interface |
| **`UserSpaceGovernanceController`** | Submits write proposals | `KernelGovernanceController` |
| **`UserSpaceEvidenceClient`** | Submits evidence receipts | `KernelEvidenceAuthority` |
| **`UserSpaceHardwareClient`** | Requests hardware lanes | `KernelHardwareAuthority` |

## 4. Governed Write Loop Integration

The kernel boundary enforces the Governed Write Loop for all mutations:

1. **Proposal**: User-space submits a `WriteProposal` via `RuntimeServicesProxy`.
2. **Decision**: Kernel-space `KernelGovernanceController` evaluates the proposal and returns a `WriteGateDecision`.
3. **Execution**: Kernel-space executes the operation on the underlying resource (PostgreSQL, NVMe).
4. **Evidence**: Kernel-space generates a signed `CoreReceipt` and submits it to the `KernelEvidenceAuthority`.

### 4.1 Write Proposal Validation

The `KernelGovernanceController` validates write proposals based on:

- **Principal Authorization**: Ensures the principal has the necessary permissions.
- **Entity Ownership**: Verifies the principal owns or has access to the entity.
- **Context Integrity**: Validates the `CorrelationIDContext` (ProjectID, SessionID, RunID).

### 4.2 Evidence Generation

The `KernelEvidenceAuthority` generates cryptographically signed evidence receipts:

- **Hash-Chaining**: Each receipt includes the hash of the previous receipt for the project.
- **Cryptographic Signing**: Receipts are signed using the kernel's private key.
- **Immutability**: Receipts are stored in the `audit_logs` table and cannot be modified.

## 5. Hardware Lane Management

The kernel boundary manages hardware lanes to maximize Apple Silicon utilization:

### 5.1 Hardware Lane Types

| Lane Type | Responsibility | Hardware Target |
| :--- | :--- | :--- |
| **Control Lane** | Governance, Auth, State Management | CPU |
| **Inference Lane** | Tensor Operations, Chat, Image Gen | GPU |
| **Perception Lane** | Background OCR, Document Layout | ANE |
| **Native Lane** | Deterministic Fallback, Low-Latency Math | CPU/SIMD |

### 5.2 Lane Assignment Workflow

1. **Request**: User-space submits a `HardwareWorkload` request via `RuntimeServicesProxy`.
2. **Assignment**: Kernel-space `KernelHardwareAuthority` assigns the workload to an appropriate lane.
3. **Execution**: Kernel-space executes the workload on the assigned hardware lane.
4. **Release**: User-space releases the lane via `RuntimeServicesProxy`.

### 5.3 Zero-Copy Memory Management

The `KernelHardwareAuthority` provides page-aligned, shared memory buffers:

- **Zero-Copy**: Swift orchestration hands a memory pointer to Metal; no buffer copying occurs.
- **Backpressure**: `AsyncStream` based handshakes ensure the CPU never overwhelms the GPU queue.
- **Load Shedding**: When saturation exceeds 90%, low-priority telemetry is dropped to protect user-facing orchestration.

## 6. Job Execution and Persistence

The kernel boundary manages job execution and persistence:

### 6.1 Job Submission

User-space submits jobs via the `RuntimeServicesProxy`:

```swift
struct JobDefinition {
    let jobID: JobID
    let principalID: PrincipalID
    let projectID: ProjectID
    let workload: HardwareWorkload
    let context: CorrelationIDContext
}
```

### 6.2 Job Persistence

Jobs are persisted in the `JobStore` to handle daemon restarts:

- **State Machine**: `pending -> running -> (completed | failed)`.
- **Lease Mechanism**: Daemons lease jobs by setting `locked_at` and `locked_by` (DaemonID).
- **Concurrency Pattern**: Uses PostgreSQL's `SKIP LOCKED` clause for efficient job queue processing.

### 6.3 Job Status Query

User-space queries job status via the `RuntimeServicesProxy`:

```swift
enum JobStatus {
    case pending
    case running(daemonID: DaemonID)
    case completed(result: JobResult)
    case failed(error: JobError)
}
```

## 7. Security and Compliance

### 7.1 Identity and Provenance

The kernel boundary enforces the canonical identity and provenance hierarchy:

- **ProjectID**: Top-level institutional boundary (RLS isolation unit).
- **PrincipalID**: Originator of the request (human or agent).
- **SessionID**: Continuous interaction window.
- **RunID**: Specific execution of a workflow or job.
- **EpisodeID**: Logical provenance segment within a long-running session.

### 7.2 Audit and Telemetry

The kernel boundary distinguishes between hash-chained governed evidence and redacted telemetry:

| Attribute | **Audit Receipts (Governance)** | **Telemetry Spans (Observability)** |
| :--- | :--- | :--- |
| **Fidelity** | 1:1 complete record | Sampled (1-100%) |
| **Privacy** | High (high-fidelity, encrypted) | Redacted (hashed, no user strings) |
| **Storage** | PostgreSQL (`audit_logs`) | OSLog / File / Memory |
| **Verification** | Cryptographically signed and hash-chained | Aggregate statistics |
| **Path** | Governed write loop | `TelemetryClient` pipeline |

### 7.3 Zero-Trust Identity

- **SPIFFE/SPIRE**: Workload identity for service-to-service auth (mTLS).
- **Baggage Propagation**: W3C Trace Context and Baggage flow through every async hop.

## 8. Performance Optimization

### 8.1 Query Coalescing

The kernel boundary implements request coalescing to prevent the "Thundering Herd" problem:

```swift
actor KernelDatabaseAuthority {
    private var activeQueries: [QueryHash: Task<QueryResult, Error>] = [:]

    func execute<T: Query>(_ query: T) async throws -> T.Result {
        let hash = query.hashValue
        
        if let existingTask = activeQueries[hash] {
            return try await existingTask.value as! T.Result
        }
        
        let task = Task {
            defer { activeQueries[hash] = nil }
            return try await self.performQuery(query)
        }
        
        activeQueries[hash] = task
        return try await task.value as! T.Result
    }
}
```

### 8.2 Connection Pooling

- **PgBouncer**: Manages PostgreSQL connections efficiently.
- **Application-Level Pooling**: Optimizes connection usage based on workload.

### 8.3 Backup and Recovery

- **Point-in-Time Recovery**: Regular backups with PITR capability.
- **Disaster Recovery**: Tested restore procedures for critical data.

## 9. Monitoring and Maintenance

### 9.1 Key Metrics

- **Query Performance**: Execution times and cache hit ratios.
- **Lock Contention**: Deadlocks and lock wait times.
- **Connection Pool**: Utilization and queue lengths.
- **Hardware Utilization**: CPU, GPU, and ANE load.

### 9.2 Regular Maintenance

- **Vacuum and Analyze**: Maintains PostgreSQL performance.
- **Index Optimization**: Manages index bloat and statistics.
- **Log Rotation**: Ensures audit and telemetry logs are managed efficiently.

## 10. Cross-References

- `INTEGRATED_DESIGN_BLUEPRINT.md` — Three-Tier Architecture and Governed Write Loop
- `Governed_Persistence_Design.md` — PostgreSQL Schema and RLS Strategy
- `Observability_Spine_Design.md` — Identity, Provenance, and Evidence Spine
- `Hardware_Authority_Design.md` — Hardware Lanes and Buffer Management
- `Sidecar_Protocol_Design.md` — Transport and Auth Handshakes

## 11. Next Steps

1. **Implementation**: Develop kernel-space components and system call interface.
2. **Integration**: Connect user-space components to the kernel boundary.
3. **Testing**: Validate security, performance, and compliance requirements.
4. **Documentation**: Update related design documents with kernel boundary specifics.

**Status**: Ready for Implementation Phase
**Last Updated**: 2026-04-16