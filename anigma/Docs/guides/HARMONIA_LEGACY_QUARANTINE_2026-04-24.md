# Harmonia Legacy Quarantine Snapshot - 2026-04-24

TD source of truth: `td-810db3`

This is a dated snapshot. Current task state, blockers, and completion status defer to `td`.

## Active Harmonia V3 Surfaces

- Shipped executable product: `harmonia`
- Active executable target: `HarmoniaV2CLI`
- Runtime facade: `HarmoniaRuntime`
- Active surface/backend: `HarmoniaV2Surface`, `HarmoniaV2Core`, `HarmoniaV2Memory`, `HarmoniaV2Inference`, `HarmoniaV2Orchestration`
- Active acceptance evidence: focused `HarmoniaRuntimeTests` plus CLI smokes for `status`, `infer`, `remember`, `tool`, `document`, and `policy`

## Quarantined Legacy Surfaces

These surfaces are archive-only unless a TD task explicitly ports specific product intent into the V3 runtime lane.

| Surface | Current package status | Disposition |
| --- | --- | --- |
| `Packages/HarmoniaCLI` target | Commented out in `Package.swift` | Archive-only legacy CLI. Do not re-enable wholesale. Port commands through `HarmoniaRuntime` or `HarmoniaV2CLI` with tests. |
| `Packages/HarmoniaCLI` excluded commands | Listed in the commented legacy target exclude block | Excluded legacy commands are not production routes and are not acceptance evidence. |
| `Packages/HarmoniaModule` | Legacy source tree present | Do not compile-patch into V3. Use as intent reference only. |
| `Sources/HarmoniaModule` | Legacy/duplicate source tree present | Archive/reference only. Avoid target membership expansion. |
| `Tests/HarmoniaModuleTests` | Commented out via `harmoniaModuleTestTargets` | Not a V3 test suite. Recreate valuable assertions under `HarmoniaRuntimeTests` before enabling. |
| Historical completion docs under `Docs/sprints/2026-01-Harmonia-Integration/` | Documentation only | Historical claims are superseded by TD and current build/test evidence. |

## Agent Rules

- Treat `HarmoniaRuntime` as the executable-facing contract.
- Treat `HarmoniaV2CLI` as the active `harmonia` command surface.
- Do not use old `HarmoniaModule` compile success, old sprint docs, or commented targets as proof of V3 completion.
- If legacy behavior still matters, create or use a TD task that rewrites that behavior into V3, with an end-to-end CLI or runtime test.
- If a future change touches `Package.swift`, keep archive-only comments near commented Harmonia legacy targets.

## Current Evidence

- `td-627386`: Harmonia V3 smoke gate is in review with active CLI/runtime smokes.
- `td-e94538`: inference intent rewrite is in review.
- `td-ecdf3a`: memory/retrieval intent rewrite is in review.
- `td-c86860`: governance/policy intent rewrite is in review.

Open full-suite blockers remain tracked separately in TD and are not Harmonia legacy migration proof.
