# Implementation Roadmap: Static Architecture Design Set

**Status:** Ready for implementation
**Date:** 2026-04-17

## Purpose

This roadmap turns the aligned design set into an execution order. It follows the dependency chain established by:

- `DAEMON_KERNEL_BOUNDARY_SPECIFICATION.md`
- `FIRST_FEATURE_STATIC_WIRING.md`
- `VERIFIER_LANE_FRAMEWORK_DESIGN.md`
- `EVALUATION_MATRIX_TEST_METHODOLOGY.md`
- `OPERATOR_REVIEW_SURFACE_DESIGN.md`
- `Observability_Spine_Design.md`
- `INTEGRATED_DESIGN_BLUEPRINT.md`
- `PRIVACY_COMPLIANCE_REGULATED_DECISIONING_SPINE.md`
- `STATIC_PLUGIN_REGISTRATION_RESEARCH.md`
- `PLUGIN_BOUNDARY_ENFORCEMENT_RESEARCH.md`
- `RELEASE_CODEBASE_TO_DESIGN_MAPPING.md`

## Execution Order

### 1. Static kernel boundary and wiring

Deliver:
- contract-only `DaemonFeatureContracts`
- slim `DaemonKernel`
- first working `*DaemonFeature` wiring target
- forbidden-import enforcement for kernel and contracts

Exit condition:
- the executable composes features explicitly through wiring targets
- the kernel imports only contracts
- forbidden feature imports fail at build time

### 2. Verifier lane and test harness

Deliver:
- verifier lane coordinator
- evidence-backed verification strategies
- reusable test harness
- verifier output that maps cleanly into the matrix vocabulary

Exit condition:
- verification runs produce traceable findings and evidence artifacts
- verification is tied to the statically composed runtime, not a plugin loader

### 3. Evaluation matrix and test methodology

Deliver:
- normalized performance, safety, compliance, and reliability dimensions
- matrix reporting tied to verifier findings
- repeatable test methodology for composed runtimes

Exit condition:
- evaluation reports reference concrete runs, wiring targets, kernel identity, and evidence records

### 4. Observability spine and operator review surface

Deliver:
- canonical identity/provenance/evidence spine
- ECS-backed read models and evidence artifacts
- operator review surface with run summary, change summary, risk, rollback, and permissions

Exit condition:
- operators review governed evidence and projections instead of bespoke logs
- redaction and access behavior are explicit and enforced

### 5. Privacy, compliance, and regulated decisioning spine

Deliver:
- mission data classification and purpose limitation contract
- privacy-preserving evidence protocol with payload references instead of raw sensitive payloads
- data subject rights workflows for access, deletion, retention expiry, legal hold, and deletion proof
- regulated-decision gate for consequential decisions, human review, explanation, and appeal metadata
- privacy verifier lane checks for missions, memory, embeddings, connectors, and external providers

Exit condition:
- missions that touch personal, sensitive, or regulated data cannot be signed without privacy class, purpose, retention, training/eval permission, jurisdiction, and regulated-decision metadata
- immutable evidence excludes raw sensitive payloads by construction
- regulated-decision missions fail closed without impact assessment and human oversight references

### 6. Integration hardening

Deliver:
- cross-reference consistency across all design docs
- CI guardrails for forbidden imports and dependency drift
- rollout-ready documentation for implementation tasks
- codebase-to-design mapping for release planning

Exit condition:
- the design set can be handed to implementation without vocabulary drift, missing dependency links, or release-status ambiguity

## Notes

- Keep static plugin wiring explicit; do not reintroduce runtime discovery.
- Treat `Package.swift` target dependencies as the hard boundary.
- Use the observability spine as the shared identity/provenance layer for verification and operator review.
- Use the privacy/compliance spine as the shared constraint layer for mission admission, payload handling, memory promotion, and regulated decisions.
- Prefer evidence-backed findings over log scraping or ad hoc runtime inspection.
