> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Research Report: Governance and Authority Patterns (Anigma)

**Author:** Gemini CLI (ses_f7e637)
**Status:** Completed
**Date:** 2026-01-11
**Issue:** td-77c170 "Research governance and authority patterns"

## Executive Summary

The Anigma platform implements a robust, three-tier architecture for governance and authority. The system is designed to provide "radical transparency" through a governed write loop that ensures all mutations are proposed, evaluated, executed, and recorded with cryptographic evidence. This report maps the core components and patterns discovered during the research phase to inform future architectural decisions for institutional AI environments.

## Core Architectural Patterns

### 1. The Governed Write Loop (Tier 2)
All platform-level mutations (Database, Artifacts, Execution, Inference) follow a strict four-stage loop:
- **Proposal**: Create a `WriteProposal` (Principal, Module, Operation, Entity, Context).
- **Decision**: Evaluate the proposal via `GovernanceController.canWrite(proposal)`, which delegates to the `WriteGate`.
- **Execution**: If allowed, the underlying resource (e.g., `DatabaseActor`) performs the mutation.
- **Evidence**: The mutation outcome is recorded by the `EvidenceAuthority`, generating a signed `CoreReceipt`.

### 2. Authority-Based Abstraction
Resources are accessed through "Authority" protocols that encapsulate governance enforcement:
- **`DatabaseAuthority`**: Governed SQL execution and schema management.
- **`EvidenceAuthority`**: Unified sink for operation evidence and verification.
- **`ArtifactAuthority`**: Governed storage for files and binary artifacts (consolidating `VaultAuthority`).
- **`InferenceAuthority`**: Governed access to AI models (Chat, Rerank, Background tasks).
- **`ExecutionAuthority`**: The entry point for multi-authority workflows and background jobs.

### 3. Pluggable Write Gate
The `WriteGate` acts as a central evaluation engine for proposals. It supports pluggable `WriteCheck` implementations:
- **`KillSwitchCheck`**: Emergency halt for all non-governance writes.
- **`OperatingModeCheck`**: Enforces system-wide or project-specific posture (`readOnly`, `assistive`, `autopilot`).
- **`GovernanceAdminCheck`**: Allows administrators to bypass certain restrictions (e.g., to deactivate a Kill Switch).

### 4. Operating Modes (Tier 1 Postures)
Governance is driven by the `OperatingMode` enum, which defines the system's "posture":
- **`.readOnly`**: All mutations are blocked by default.
- **`.assistive`**: Mutations are allowed if they pass specific quality or safety gates.
- **`.autopilot`**: High-autonomy mode for automated background agents.

## Component Mapping

| Component | Tier | Responsibility |
| :--- | :--- | :--- |
| `GovernanceController` | 2 | Central orchestrator for policy and state (KillSwitch, WriteGate). |
| `ExecutionAuthority` | 2 | Orchestrates governed workflows and manages background jobs. |
| `EvidenceAuthority` | 2 | Consolidates evidence recording into signed receipts. |
| `DatabaseAuthority` | 2 | Wraps `DatabaseActor` with governance and schema management. |
| `ArtifactAuthority` | 2 | Manages content-addressed artifact storage with evidence. |
| `AccessController` | 2 | Handles attribute-based access control (ABAC) policies. |
| `OperatingMode` | 1 | Defines the behavioral constraints of the platform. |
| `CoreReceipt` | 1 | Cryptographic proof of a governed operation. |

## Strategic Observations

- **Circular Dependency Resolution**: `DatabaseAuthorityImpl` and `EvidenceAuthorityImpl` have a circular dependency (DB needs Evidence for records, Evidence needs DB for storage). This is currently resolved via a `setEvidenceAuthority` post-initialization step.
- **In-Memory Job Tracking**: The current `ExecutionAuthorityImpl` tracks background jobs in-memory. For institutional environments, these may need to be persisted to a "Job Store" to survive restarts.
- **Unified Proxy Pattern**: The `RuntimeServicesProxy` provides a consolidated view of all authorities to workflows, ensuring they don't have to manage multiple actor references directly.
- **Access Control Isolation**: The `AccessController` is kept separate from the `WriteGate`, allowing for a distinction between "who can do what" (ABAC) and "what is safe to do right now" (Governance).

## Design Phase Considerations (Post-Research Cross-Reference)

Based on a cross-reference with Telemetry, Database, and Memory research, the following gaps must be addressed in the design:

1.  **Identity Standardization**: Standardize on **`ProjectId`** as the top-level institutional tenant, mapping a hierarchy: `Project` > `Principal` > `Session` > `Run` (and `Episode`).
2.  **Audit vs. Telemetry Separation**: Explicitly separate **`Audit Logs`** (High-fidelity, encrypted, verifiable receipts stored in SQL) from **`Telemetry Spans`** (Aggregated, redacted, hashed performance metrics). Governance enforcement requires the former, while observability uses the latter.
3.  **Context Propagation**: Decide between explicit **`ExecutionContext`** passing (current pattern) and implicit **`@TaskLocal`** propagation (proposed in Telemetry research). Maintaining both creates a risk of context drift.
4.  **Persistent Job Tracking**: Replace the current in-memory job tracking in `ExecutionAuthorityImpl` with a persistent **`JobStore`** schema in PostgreSQL to ensure agentic runs survive restarts and link to Audit Logs.
5.  **Memory Governance**: Define sensitivity thresholds for memory writes. Transient working notes in Redis may bypass the WriteGate, but high-sensitivity "resolved facts" must go through the standard governed write loop.

## Conclusion

The existing governance and authority patterns are well-aligned with the goal of high-assurance, institutional AI. The modular nature of `WriteGate` and the protocol-first design of `Authorities` provide a solid foundation for future extensions. Future work should focus on hardening the persistence of job records and refining the evidence verification workflows for end-to-user transparency.