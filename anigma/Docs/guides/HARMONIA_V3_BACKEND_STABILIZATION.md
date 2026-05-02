# Harmonia V3 Backend Stabilization Track

> Dated planning snapshot: 2026-04-12.
>
> Source of truth for live status: `td`, then `anigma/current_build_status.txt`, then `anigma/build_phase3_logs/`.

## Purpose

Harmonia V3 is the compile-first backend stabilization track for the `harmonia` executable. Its concrete executable-facing Swift target/module should be named `HarmoniaRuntime`.

V3 is not a broad rewrite and it is not a commitment to finish legacy `HarmoniaModule` or `HarmoniaV2` as separate product generations. `HarmoniaRuntime` is the stable executable-facing facade that absorbs the usable pieces of both lines behind one narrow backend API. Anything useful but unfinished from legacy or V2 must become explicit V3 roadmap work instead of remaining hidden behind stale completion claims.

Naming follows `Docs/guides/BACKEND_CANONICAL_NAMING_POLICY.md`: `HarmoniaConductor` is the canonical V3 orchestration name, while Phase9 remains historical context only. Document-analysis work should use the canonical route `HarmoniaRuntime -> HarmoniaConductor -> DocumentIngest -> EvidenceLedger/RuntimeTelemetry`.

## Canonical TD Track

- Epic: `td-79a05d` - Harmonia V3 backend stabilization track
- Runtime boundary: `td-13947f` - Define HarmoniaRuntime boundary and executable compile gate
- Inventory: `td-14bb05` - Inventory usable legacy and V2 Harmonia pieces for V3 absorption
- Compile path: `td-0f7a25` - Implement minimal HarmoniaRuntime executable path for harmonia
- Full specification implementation: `td-ac0117` - Complete deferred legacy/V2 behavior in the Harmonia V3 specification

## Stabilization Rule

The `harmonia` executable should import one Harmonia backend surface: `HarmoniaRuntime`.

Direct executable dependencies on legacy `HarmoniaModule`, partially migrated V2 internals, or stub-only migration targets are blockers unless they are explicitly justified as temporary compile gates in TD.

## HarmoniaRuntime Scope

`HarmoniaRuntime` should expose only the executable-facing surface needed to make backend stabilization measurable:

- command routing entrypoint
- health/status response
- session/query entrypoint
- memory/context access seam
- execution receipt and observability hook seam
- controlled error responses for unavailable capabilities

The facade should return truthful controlled failures for unavailable behavior. It should not expose `.notImplemented()` stubs as if they were production paths.

## Absorption Policy

Classify each legacy/V2 candidate as one of:

- `absorb-now`: compiles, has clear behavior, and is needed for the executable path
- `adapt-behind-facade`: useful but requires a wrapper, protocol adapter, or type cleanup
- `defer-to-v3-roadmap`: important for full Harmonia capability but not needed for the compile gate
- `archive-or-quarantine`: stale, duplicated, or too broken to remain on the active executable path

The inventory should cover:

- CLI-facing commands
- workflow/session types
- health/status
- memory and retrieval
- inference adapters
- Harmonia Conductor orchestration behavior (historically Phase9)
- tool execution
- governance authorities
- receipts and audit events
- telemetry/observability integration

## Initial Absorption Map

| Area | Evidence | Disposition |
| --- | --- | --- |
| CLI boundary | `Packages/HarmoniaCLI/HarmoniaCommands.swift` now imports `HarmoniaRuntime`, and `Package.swift` routes `HarmoniaCLI` through that facade. | absorb-now |
| Runtime facade | `Packages/HarmoniaRuntime/Sources/HarmoniaRuntime/HarmoniaRuntime.swift` is the new executable-facing surface and reexports the V2 API surface. | absorb-now |
| Runtime health/status | `Packages/HarmoniaRuntime/Sources/HarmoniaRuntime/HarmoniaRuntime.swift` and `Packages/HarmoniaCLI/HarmoniaStatusCommand.swift` expose a truthful degraded status response. | absorb-now |
| Backing V2 surface | `Packages/HarmoniaV2/HarmoniaSurface/Sources/HarmoniaSurface.swift` exposes `HarmoniaService`, but `query()` still throws `HarmoniaError.notImplemented(...)`. | adapt-behind-facade |
| Query/session control | `HarmoniaRuntime.query()` converts V2 `notImplemented` into a controlled `notConfigured` runtime error; `HarmoniaCommands.swift` reports it. | absorb-now |
| Contracts and errors | `Packages/HarmoniaV2/HarmoniaContracts/Sources/HarmoniaContracts.swift` defines the shared `HarmoniaError`/DTO layer used by the facade. | absorb-now |
| Core context/types | `Packages/HarmoniaV2/HarmoniaCore/Sources/HarmoniaCore.swift` provides `ExecutionContext`, `ModuleRegistry`, and shared capabilities. | adapt-behind-facade |
| Inference and memory | `Packages/HarmoniaV2/HarmoniaInference/Sources/HarmoniaInference.swift` and `Packages/HarmoniaV2/HarmoniaMemory/Sources/HarmoniaMemory.swift` compile, but still rely on stub/no-backend paths. | adapt-behind-facade |
| Harmonia Conductor/tool loop | `Packages/HarmoniaV2/HarmoniaOrchestration/Sources/HarmoniaOrchestration.swift` now provides the canonical `HarmoniaConductor` boundary; the document-analysis lane and tool gateway are still deferred, but the runtime tool route now emits controlled placeholder results through the conductor. | adapt-behind-facade |
| Receipts / observability | `Packages/HarmoniaRuntime/Sources/HarmoniaRuntime/ReceiptSpine.swift` implements deterministic receipt spine with actionable error codes and durable journal routing; `Packages/HarmoniaCLI/CommandCommands/ReceiptTestCommand.swift` provides CLI verification; see `DOCUMENT_ANALYSIS_CANONICAL_FACADES.md` for canonical facade definitions. | absorb-now |
| Legacy HarmoniaModule | `Packages/HarmoniaModule/` remains the broken legacy surface called out as ~5,700 errors in prior build analysis. | archive-or-quarantine |
| Legacy CLI command files | `Packages/HarmoniaCLI/{Refactor,Scout,SelfHost,Swift6Step,Tool,Vault,RealHarnessRunner,PrincipalityProjectControllerPreviewCompat}.swift` stay excluded from the executable target while they still reference legacy surfaces. | archive-or-quarantine |

## Deferred V3 Implementation Backlog (TD-linked)

The deferred backlog from `td-14bb05` is now explicitly expanded under `td-ac0117` as implementation tasks:

| Deferred capability | TD task | Actionable acceptance gate |
| --- | --- | --- |
| Phase9/orchestration path | `td-0cb66d` | `HarmoniaRuntime` routes the historical Phase9 command through `HarmoniaConductor`; the canonical document-analysis lane still returns controlled deferred or not-configured outcomes until the lane is implemented. |
| Tool execution wiring | `td-e3b75e` | Tool calls run through a single governed dispatch contract with deterministic error/denial receipts and no direct legacy wiring on the executable path; the current runtime route returns a controlled placeholder result through the conductor. |
| Memory/retrieval backend seam | `td-1edbaa` | Runtime memory/query seams are backed by non-stub adapters or controlled `notConfigured` gates with reason codes and provenance fields. |
| Governance authorities | `td-8d067f` | Runtime evaluate→submit→receipt authority boundaries and fail-closed policy behavior are documented and enforced at the HarmoniaRuntime seam. |
| Receipts/audit events | `td-ab2972` | Runtime actions emit deterministic receipts and auditable actor/action/policy/evidence events routed to a durable journal. |
| Telemetry/observability integration | `td-a1ff61` | Runtime command/query/tool paths emit canonical trace context and project into trace/event/artifact queries with replay-gap handling. |

Cross-track links are explicit in TD dependencies (`td-16ca40`, `td-8661e6`, `td-38fe0e`, `td-ab16d6`, `td-cd1576`, `td-01c59f`, `td-003af2`, `td-d55939`, `td-e07fd5`, `td-76ac32`) so V3 deferred work can be executed without relying on broad prose.

## Milestones

1. `harmonia` compile gate: `swift build --package-path anigma --product harmonia` succeeds or reaches only unrelated non-Harmonia blockers.
2. Startup gate: `harmonia --help` starts without loading legacy broken surfaces.
3. Status gate: health/status command returns a non-stub, truthful response.
4. Query/session gate: query/session commands either execute through migrated V3 behavior or return a controlled not-configured response with an actionable reason.
5. Specification gate: all deferred legacy/V2 behavior needed for full V3 is represented in TD and the roadmap with acceptance criteria.

## Current Review Evidence

### Verified Acceptance Criteria (2026-04-12)

✅ **harmonia compile gate**: `swift build --package-path anigma --product harmonia` completes successfully (verified 2026-04-12, build time 58.28s).

✅ **Startup gate**: `harmonia --help` starts successfully and displays the consolidated CLI surface without loading legacy broken surfaces.

✅ **Status gate**: `harmonia status` returns a non-stub, truthful degraded runtime state with clear capability boundaries:
```
🩺 HarmoniaRuntime status
   Health: degraded
   Summary: HarmoniaRuntime is compile-stable with durable receipt/audit journaling...
   Query/session: deferred
   Memory/context: partial
   Receipts/observability: partial
   Orchestration: partial
```

✅ **Query/session gate**: `harmonia v2 infer "test query"` returns a controlled not-configured response with actionable reason:
```
Error: query/session not configured: query() - full pipeline pending migration [Action: harmonia.query, Reason: NOT_CONFIGURED]
```

✅ **Canonical TD tasks and documentation**: Epic `td-79a05d` with child tasks `td-13947f`, `td-14bb05`, `td-0f7a25`, `td-ac0117` provide explicit tracking.

✅ **HarmoniaRuntime as single executable-facing facade**: `Packages/HarmoniaCLI/HarmoniaCommands.swift` imports `HarmoniaRuntime`, and `Package.swift` routes CLI through that facade.

✅ **Usable legacy and V2 pieces inventoried**: Absorption map in this document classifies all major areas with explicit dispositions.

✅ **Pending legacy/V2 behavior as V3 specification backlog**: Deferred backlog table links to explicit TD tasks with acceptance gates.

✅ **Roadmap handoff**: `Docs/governance/Roadmap.md` updated to treat V2 as source material and V3 as the stabilization track.

### Build Verification Output

```bash
$ swift build --package-path anigma --product harmonia
[299/301] Linking harmonia
[300/301] Applying harmonia
Build of product 'harmonia' complete! (58.28s)

$ ./anigma/.build/arm64-apple-macosx/release/harmonia --help
OVERVIEW: A command-line interface for the Anigma ecosystem.
USAGE: harmonia <subcommand>
... (full help output verified)

$ ./anigma/.build/arm64-apple-macosx/release/harmonia status
🩺 HarmoniaRuntime status
   Health: degraded
   ... (truthful status verified)

$ ./anigma/.build/arm64-apple-macosx/release/harmonia v2 infer "test query"
🧠 Running HarmoniaRuntime inference...
Error: query/session not configured: query() - full pipeline pending migration [Action: harmonia.query, Reason: NOT_CONFIGURED]
```

This evidence satisfies all acceptance criteria for the Harmonia V3 backend stabilization track epic.
