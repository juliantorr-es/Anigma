# HarmoniaArtifacts Module Boundary

Harmonia is the governance layer. It owns artifact truth, storage layout, lifecycle, scopes, privacy compartments, TTLs, and reuse decisions. The inference layer (MLX, Core ML adapters, llama.cpp, etc.) plugs into that contract and never touches governance directly.

## API surface

- **ArtifactEnvelope** – the metadata model defined in `Docs/architecture/inference/artifact_envelope.md`. Harmonia validates every envelope, canonicalizes hashes for inputs/params, and records the artifact in the store.
- **ArtifactStore** – interface that writes payload bytes (content addressable) and returns `artifact_hash`. Reads payloads by hash, respecting garbage collection rules tied to TTL, scope, and privacy boundary.
- **ArtifactReuseGate** – given an intent (requested type, `model_id`, `input_hash`, `params_hash`, scope, capability tier), it either returns a validated hit (with `artifact_hash`) or a reason-coded miss. Hits/ misses flow through the gate; backends never bypass it.
- **AuditLogSink** – every store attempt, reuse attempt, hit, miss, invalidation, or policy violation is emitted here. The audit record includes envelope identifiers, policy gate names, trust mode, renderer/backends IDs, and failure reasons.

These APIs are the only entry points for inference artifacts. Backends call `ArtifactStore.store(payload, envelope)` and `ArtifactReuseGate.tryReuse(request)`; they never open files or sketch metadata themselves. Harmonia enforces governance, TTL expiration, scope isolation, and privacy boundaries.

## Policy and dev escape

Harmonia enforces capability-grant rules on artifact reuse. If reuse is denied (scope too wide, TTL expired, privacy violation, etc.), the gate returns a reason and the backend falls back to recomputation. A compile-time development escape hatch may allow bypassing the gate, but such bypasses must log that the artifact is session-scoped and mark it as non-reusable outside the current execution; they must also set a conspicuous flag in the audit log so inspectors know the run went off the contract.

## Governance responsibilities

Harmonia manages:

- Storage lifecycle: TTL enforcement, GC sweeps, privacy/compartment isolation.
- Provenance: associating artifacts with jobs, renderer IDs, and policy evaluations.
- Observability: feeding audit logs to the governance dashboards so “why did this run reuse cache X?” is easy to answer.
- Interface contracts for inference backends, keeping them simple (“produce bytes + declare knobs”) while Harmonia handles reuse, policy, and logging.

This keeps Harmonia as the single source of truth for artefacts, while inference engines remain interchangeable renderers. Any renderer or backend must go through `HarmoniaArtifacts`; other code can only interact with inference artifacts by calling Harmonia APIs. That prevents ad-hoc temp-folder caches from creeping into runners.
