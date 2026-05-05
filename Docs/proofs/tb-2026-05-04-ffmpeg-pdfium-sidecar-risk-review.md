# Proof: FFmpeg and PDFium Sidecar App Store Risk Review

## Status
- **Implementation**: Completed
- **Changes**: Conducted a focused review of `FFmpeg` and `PDFium` sidecar boundaries to determine App Store distribution viability. Added an explicit `APP_STORE_SIDECAR_RISK_REVIEW.md` policy, updated the inventory to reflect native replacements, and introduced a boundary validation script.
- **Goal**: Formally evaluate if `FFmpeg` and `PDFium` represent App Store release blockers, regardless of sidecar isolation.

## Files Inspected
- `anigma/Package.swift`
- `Scripts/test_pdf_sidecar_readiness.sh`
- `anigma/Packages/AnigmaSystemSpine/SystemUXSupport.swift`
- Various headers in `anigma/Vendor/include/` (`libavutil`, `fpdfview.h`, etc.)
- Existing `THIRD_PARTY_INVENTORY.yaml`, `THIRD_PARTY_NOTICES.md`, `PROJECT_DASHBOARD.md`

## Findings: FFmpeg (`libav*`)
- **Classification**: `optional_external_tool`
- **Usage**: Conditionally linked via `ENABLE_FFMPEG_LINKING=1` (found in `Package.swift`).
- **Bundled Status**: Not bundled by default App Store targets.
- **App Store Risk**: **HIGH / BLOCKER**. Even if compiled strictly as LGPL (without `--enable-gpl`), distributing it in an App Store `.app` violates LGPL dynamic linking rights.
- **Native Replacement**: `AVFoundation`, `VideoToolbox`, `Metal`, `CoreVideo`, `CoreMedia` (already heavily used).
- **Resolution**: FFmpeg must be strictly excluded from all official App Store release builds. The `ENABLE_FFMPEG_LINKING` environment variable acts as the boundary.

## Findings: PDFium (`libpdfium.dylib`)
- **Classification**: `bundled_sidecar`
- **Usage**: Used by `PDFSidecarExecutable` for advanced PDF operations. Vendored at `External/Vendor/PDFium/macos-arm64`.
- **Bundled Status**: `PDFSidecarExecutable` is built as an executable target and validated by `test_pdf_sidecar_readiness.sh`.
- **App Store Risk**: **MODERATE / MANAGEABLE**. PDFium operates under permissive licenses (Apache 2.0 / BSD). It does not block App Store distribution, *provided* all transitive notices are bundled.
- **Native Replacement**: `PDFKit` (Apple native - already imported in `SystemUXSupport.swift`).
- **Resolution**: Safe to bundle as a sidecar IF full binary provenance and all transitive notices are provided. `PDFKit` should be the preferred default path to reduce binary size and legal surface area.

## App Store Build Profile Recommendation
- **Excluded Flags**: `ENABLE_FFMPEG_LINKING=0` (or unset).
- **Excluded Sidecars**: Any FFmpeg sidecar. `PDFSidecarExecutable` is optional but requires strict notice validation.
- **Required Backends**: `AVFoundation`, `PDFKit`.
- **Validation**: Execute `Scripts/validate_app_store_dependency_boundaries.py` before any release signing.

## Inventory Changes
- Updated `THIRD_PARTY_INVENTORY.yaml`:
  - `FFmpeg`: Reclassified as `optional_external_tool`. App Store Status: `high_risk`. Added native replacement path (`AVFoundation`, etc.) and validation gate.
  - `PDFium`: Reclassified as `bundled_sidecar`. App Store Status: `needs_review` (pending transitive notices). Added replacement path (`PDFKit`) and validation gate.
- Updated `THIRD_PARTY_NOTICES.md` to officially list `PDFium` with a warning that transitive notices are pending.

## Validation Results
- `rg` command successfully revealed PDFium paths, FFmpeg headers, and conditional linking flags.
- `python3 Scripts/validate_app_store_dependency_boundaries.py` :: Passed successfully (enforces `ENABLE_FFMPEG_LINKING` is not hardcoded, checks YAML policy).
- `python3 Scripts/validate_public_project_readiness.py` :: Passed successfully.
- `python3 Scripts/validate_notion_publisher.py` :: Passed successfully.

## Remaining Release Blockers
- **None for the build itself**, but `PDFium` transitive notices MUST be aggregated before any sidecar App Store submission.

## Recommended Next Task
- After this review, implement an explicit App Store build profile/gate (e.g., a Fastlane or CI script) that proves FFmpeg is excluded via `ENABLE_FFMPEG_LINKING=0` and PDFium is either excluded or fully noticed before any signed release build.
