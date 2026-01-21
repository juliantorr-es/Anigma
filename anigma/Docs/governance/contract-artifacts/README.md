# Contract Artifact Registry

This folder is the registry of “contract artifacts” for cross-module surfaces.

Rule: Any change that crosses a module boundary or introduces/changes a public surface must include a contract artifact update in this folder.

A contract artifact must include:
- Authority boundary (Core vs Capability; ContractsCore vs others)
- Surface definition (protocol/facade API)
- Concurrency model (actor/MainActor/Sendable expectations)
- Stop conditions (what halts the pipeline)
- Acceptance tests (ordering/limits/denial behavior, plus error semantics)
- Migration plan (call-site swaps, adapters, hardening, logging/evidence hooks)

Naming:
- Use `SURFACE.<SurfaceName>.md` (example: `SURFACE.SessionListingProviding.md`)
