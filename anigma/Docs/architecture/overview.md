# Anigma Ecosystem: Two-Tier Architecture

Anigma follows a **layered governance model** with strict separation between production-hardened Core substrate and feature-rich Capability Modules.

## 1. Core Governance Layer: Production-Hardened Substrate

### AnigmaCore: The Foundational Framework
- **Role:** Single source of truth for ECS (`World`, `EntityId`, `Component`, `System`), jobs/workflows/scheduler, audit logging, kill switch, operating modes, write gates, access control, retention/lifecycle, telemetry, explainability, and model integrity utilities.
- **Design:** Actor-based world for concurrency safety; minimal external dependencies; Apple Silicon-first.
- **Guarantees:** Court-safe provenance, hardware attestation, offline verification, legal defensibility.

### Court-Safe ML Worker Integration
- **Hardware-backed signing**: All evidence heads signed with Secure Enclave/TPM keys
- **Trusted timestamping**: External RFC3161 TSA verification for legal timestamps
- **Canonical serialization**: Cross-platform deterministic byte signing
- **Key custody management**: Hardware-protected private keys with rotation/revocation
- **Offline verification**: Evidence bundles verifiable without trusting Anigma infrastructure

## 2. Capability Modules: Feature-Rich Ecosystem

### Module Descriptions

- **`HarmoniaModule`**: Governed inference, reasoning safety (Bonkers++), CI/CD gates, transparency bundles.
- **`DiaplasionModule`**: Alt-media transformation (OCR, chunking, EPUB/Braille/audio prep) with ready-to-run workflows.
- **`AccessumModule`**: Apertum Accesum slice: import → OCR → TTS → sync with telemetry and governance hooks.
- **`OutlineumModule`**: Outline/zine creation with CoreImage processing, QA, and export systems.
- **`PragmaModule`**: Work management domain (tasks/projects, workflows, transitions, permissions, automation checks).
- **`ConexusModule`**: CRM domain (contacts, orgs, pipelines, cases, activities, relationship graphs).
- **`CodexModule`**: Knowledge domain (spaces, pages, templates, versions, comments).
- **`TranscriptumModule`**: Academic records domain (programs, courses, enrollments, grades).
- **`ObservatoriumModule`**: Observability domain (metrics, alerts, error aggregation, feedback).
- **`PolytroposModule`**: Live-event video processing with native renderer and MLT/FFmpeg fallback strategy.

## 3. Cross-Cutting Services

- **Governance:** Kill switch, operating modes (read-only/assistive/autopilot), write gates, playbooks/policies.
- **Privacy & Lifecycle:** Data sensitivity classes, access control (RBAC/ABAC), retention/expiration, legal holds, audit trails.
- **Security:** Model integrity, drift/poisoning detection, policy enforcement engine, vulnerability lifecycle, crypto utilities.
- **Telemetry & Transparency:** Metrics, traces, receipts, data-flow graphs, structured reasoning traces, Observatorium alerts.

## 4. Architecture Benefits

This two-tier structure keeps the stack extensible while maintaining security:

- **One ECS/job core** prevents fragmentation and duplicate infrastructure
- **One governed inference entrypoint** ensures all ML operations are auditable
- **Capability modules** can evolve rapidly without compromising Core security posture
- **Clear contracts** between layers enable independent development and testing
