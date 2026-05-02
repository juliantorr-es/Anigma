# Manifest-Stranded Package Trees Disposition (td-d09399)

Last updated: 2026-04-09

This records explicit disposition for package trees that exist on disk under `Packages/` but are not bound as active SwiftPM target paths in `Package.swift`.

| Tree | Disposition | Evidence | Rationale |
|---|---|---|---|
| `Packages/AccessumFlow` | **integrated** (via consolidation into `HarmoniaCLI`) | `Package.swift` builds executable target at `path: "Packages/HarmoniaCLI"`; `Packages/HarmoniaCLI/Main.swift` registers `AccessumFlow.self`; no `path: "Packages/AccessumFlow"` target exists. | Command implementation is now hosted in the canonical CLI surface; standalone tree remains as legacy residue and is inactive for build graph purposes. |
| `Packages/OutlineumZine` | **integrated** (via consolidation into `HarmoniaCLI`) | `Packages/HarmoniaCLI/Main.swift` registers `OutlineumZine.self`; no `path: "Packages/OutlineumZine"` target exists. | Zine command is consumed from canonical CLI target; standalone tree is not part of active manifest graph. |
| `Packages/AnigmaUI` | **inactive-with-rationale** | `Package.swift` target `AnigmaUI` uses `path: "Sources/AnigmaUI"` and has no `path: "Packages/AnigmaUI"` binding. | Canonical app UI module has moved under `Sources/`; package-tree copy is intentionally inactive until archival cleanup task is scheduled. |
| `Packages/AnigmaWebServer` | **inactive-with-rationale** | `Sources/AnigmaWebServer/AnigmaWebServer.swift` is present and used as canonical web-server implementation; no `Package.swift` target path references `Packages/AnigmaWebServer`. | Preserve historical implementation for reference while canonical source-of-truth remains under `Sources/`. |
| `Packages/HarmoniaSurface` | **inactive-with-rationale** | `Package.swift` defines `HarmoniaV2Surface` with `path: "Packages/HarmoniaV2/HarmoniaSurface/Sources"`; no target path references `Packages/HarmoniaSurface`. | V2 surface replaced legacy standalone surface; keeping old tree unbound prevents accidental linkage drift. |

## Guardrail

If any tree above is reactivated, update both `Package.swift` and this disposition ledger in the same change to preserve package/manifest truthfulness.
