# Harmonia Legacy Intent Audit

Date: 2026-04-24

Live TD issue: `td-a67e2c`

Parent acceptance gate: `td-12b13a`

## Position

Original Harmonia and Harmonia V2 should be treated as source material for Harmonia V3, not as code to revive wholesale.

The valuable work is the product intent: governed inference, memory, retrieval, document analysis, tool execution, receipts, transparency, policy boundaries, and app/CLI workflows. The risky work is the old compile surface: broad target fan-out, duplicate semantic types, excluded CLI commands, historical stubs, commented-out tests, and cascading-error-prone legacy modules.

## Current Evidence

- `Packages/HarmoniaModule/Sources` contains 119 Swift files across API, core coordination, inference, retrieval, security, governance, doctrine, services, and systems.
- `Packages/HarmoniaV2` contains 18 active Swift source files across contracts, core, inference, memory, orchestration, and surface.
- `Package.swift` binds the executable-facing path through `HarmoniaRuntime` and `HarmoniaV2Surface`.
- `Package.swift` explicitly notes `Packages/HarmoniaSurface` is intentionally unbound.
- The legacy `HarmoniaCLI` executable target is commented out, while `HarmoniaV2CLI` is the active executable named `harmonia`.
- The `HarmoniaModuleTests` target is commented out.
- `Packages/HarmoniaV2/COMPLETION_SUMMARY.md` is marked as a historical snapshot, not current production readiness evidence.
- Focused V3 runtime acceptance passed 14 tests covering memory/query, document analysis, governed tool execution, policy allow/deny, receipts, and tool gateway behavior.

## Preserve

These areas represent real design investment and should be preserved as intent, API behavior, tests, or examples:

| Legacy area | Evidence | V3 disposition |
| --- | --- | --- |
| Governed inference | `HarmoniaModule/Sources/HarmoniaInference/Inference`, `HarmoniaV2/HarmoniaInference` | Rewrite behind `HarmoniaRuntime` lanes with authority boundaries and E2E tests. |
| Reasoning and constraints | `ReasoningTypes.swift`, `InferenceTypes.swift`, V2 puzzle builders | Port stable value types and deterministic behavior only; avoid old dependency graph. |
| Memory and retrieval | `TriMemoryArchitecture.swift`, `RetrievalService.swift`, `HarmoniaV2/HarmoniaMemory` | Rewrite as V3 memory lane with durable store/search/provenance tests. |
| Governance and policy | `HarmoniaSecurity/Governance`, `HarmoniaSecurity/Doctrine`, V3 policy lane | Keep policy semantics; implement through V3 fail-closed lane and receipts. |
| Receipts and transparency | `ProcessingReceipt.swift`, evidence/security systems, V3 receipt journal tests | Preserve receipt intent; route through canonical runtime receipt spine. |
| Tool execution | V3 governed tool gateway, historical CLI tool commands | Keep workflow intent; only use registered governed dispatch paths. |
| Document analysis | V3 `FunctionalDocumentAnalysisLane`, Contextum references | Keep document-ingest behavior; separate deterministic local lane from live Contextum/Postgres integration gate. |
| App/CLI workflows | `HarmoniaRootView`, `HarmoniaCliView`, `HarmoniaV2CLI`, historical `HarmoniaCLI` commands | Preserve UX/command intent; bind only to `HarmoniaRuntime`. |

## Do Not Patch Directly

These surfaces should not be made production by incremental compile-error patching:

- `Packages/HarmoniaModule` as a monolithic target.
- Commented-out `HarmoniaModuleTests` target.
- Commented-out legacy `HarmoniaCLI` executable target.
- Excluded legacy CLI command files listed in `Package.swift`.
- Historical V2 `.notImplemented`, deferred, or stub paths unless converted to explicit V3 blockers.
- Duplicate semantic authority/database types created only to break compile cycles.
- Old docs claiming completion without TD plus fresh build/test evidence.

## V3 Rewrite Backlog

1. V3 governed inference lane
   - Rewrite legacy inference intent into a narrow `HarmoniaRuntime` lane.
   - Acceptance: deterministic symbolic path, neural/ML fallback contract, receipt/audit output, policy gate, tests.

2. V3 memory and retrieval lane
   - Replace historical tri-memory/retrieval code with a durable backend contract.
   - Acceptance: store, retrieve, search, provenance, fresh runtime/process boundary, failure receipts.

3. V3 doctrine/policy lane
   - Convert legacy doctrine/governance intent into a fail-closed runtime policy service.
   - Acceptance: allow/deny/escalate, reason codes, regulated-decision metadata, tests.

4. V3 tool execution gateway
   - Keep only registered governed tools with receipt journal and audit metadata.
   - Acceptance: known tool success, unknown tool denial, malformed request denial, deterministic receipt.

5. V3 document ingest lane
   - Keep deterministic local lane as default; make live Contextum/Postgres a separate integration gate.
   - Acceptance: fixture ingest, structured output, provenance, opt-in live backend smoke if required.

6. V3 Harmonia app/CLI contract
   - Make CLI/app call only `HarmoniaRuntime`, never legacy `HarmoniaModule` or unstable V2 internals.
   - Acceptance: `harmonia --help`, status, query, tool, document command smoke tests.

7. Legacy archive/quarantine pass
   - Move or explicitly mark unbound legacy sources so agents stop treating them as active production surfaces.
   - Acceptance: docs and Package.swift agree; TD blockers exist for any retained dead/deferred path.

## Next Gate

Run the full package test and executable smoke suite before marking migration complete:

```bash
swift test --package-path anigma
swift build --package-path anigma --product harmonia
./anigma/.build/arm64-apple-macosx/debug/harmonia --help
./anigma/.build/arm64-apple-macosx/debug/harmonia status
```

If these fail on unrelated backend surfaces, record blockers in TD instead of expanding Harmonia's active compile surface.
