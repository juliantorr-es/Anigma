# Proof: Dependency Inventory Sweep and Licensing Audit

## Status
- **Implementation**: Completed
- **Changes**: Conducted a thorough scan of `Package.swift`, python scripts, and package manifests to capture dependencies, sidecar candidates, and system frameworks. Upgraded `THIRD_PARTY_INVENTORY.yaml` to a comprehensive audit artifact.
- **Goal**: Inventory dependencies and external tools, classify them by use and distribution risk, and update the legal/public-readiness artifacts accordingly.

## Files Inspected
- `anigma/Package.swift`
- `anigma/Docs/package.json`
- Various `.py` script files in `Scripts/` and `Tests/`

## Inventory Entries Added
- Python Tooling: `python-requests`, `python-pyyaml`, `python-jsonschema` (All dev-only)
- JS Tooling: `mermaid`, `vitepress` (All dev-only)
- Swift Packages:
  - `swift-argument-parser`
  - `swift-syntax`
  - `SwiftUICharts`
  - `mlx-swift`
  - `mlx-swift-lm`
  - `swift-numerics`
  - `swift-toml`
  - `swift-crypto`
  - `swift-cmark`
  - `hummingbird`
  - `async-http-client`
  - `swift-sdk` (MCP)
  - `postgres-nio`
- External Services: `Notion API`

## Entries Marked `needs_review`
- Versions of Python tooling (`python-requests`, `python-pyyaml`, `python-jsonschema`).
- Versions of JS tooling (`mermaid`, `vitepress`).
- Version of `SwiftUICharts`.
- Version/Origin URLs for vendored binaries like `PDFium` and conditionally linked `FFmpeg`.

## Sidecar Candidates Identified
- **PDFium**: Vendored binary used via `PDFSidecarExecutable`. App Store risk is pending review.
- **FFmpeg**: Conditionally linked via `ENABLE_FFMPEG_LINKING`. Extreme App Store risk (copyleft) if bundled directly.

## Apple/System Frameworks Identified
- `Metal`, `MetalKit`, `MetalPerformanceShaders`, `Accelerate`, `CoreVideo`, `AVFoundation`, `ImageIO`, `CoreGraphics`, `CoreText`, `CoreAudio`. (Classified as `runtime_system_framework`).

## Artifact Updates
- **`Docs/legal/THIRD_PARTY_INVENTORY.yaml`**: Fully rewritten to capture all known dependencies grouped by category.
- **`THIRD_PARTY_NOTICES.md`**: Updated to officially list the bundled Swift packages with known versions and licenses (MIT/Apache 2.0).
- **`Docs/dashboard/PROJECT_DASHBOARD.md`**: Updated to reflect the completed P1 pass and the newly discovered App Store risk regarding `FFmpeg`.

## Validation Results
- `python3 Scripts/validate_public_project_readiness.py` :: Passed successfully.
- `python3 Scripts/validate_notion_publisher.py` :: Passed successfully.
- Direct YAML parse validation implicit via readiness script (which uses PyYAML).

## Artifact Integrity
- Runtime Code: Unchanged.
- Publisher Behavior: Unchanged.

## Remaining Gaps
- Resolving the `needs_review` status for the exact versions of the development tools (Python and JS).
- A deep dive into `PDFium` usage to confirm exactly how it affects App Store compliance when distributed in a sidecar.
- Formal legal review of the dependency policy.

## Recommended Next Task
- Conduct a focused evaluation of `FFmpeg` and `PDFium` sidecar isolation architectures to confirm whether they strictly satisfy App Store guidelines for external or out-of-process binaries.
