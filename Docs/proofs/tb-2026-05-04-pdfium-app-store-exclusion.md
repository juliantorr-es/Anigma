# Proof: PDFium App Store Exclusion

## Status
- **Implementation**: Completed
- **Changes**: Officially excluded PDFium from the App Store alpha profile. Reclassified PDFium in the dependency inventory, updated the `app-store-profile.yaml` marker, and clarified its optional/non-App-Store status in the third-party notices.
- **Goal**: Make the `validate_release_readiness.py` script pass honestly by adopting the conservative path (excluding PDFium and utilizing PDFKit for App Store distributions) rather than feigning complete legal compliance.

## Original Blocker
The App Store Build Profile Gate was failing because PDFium was marked as `distributed_in_app_store_build: true`, but its binary provenance (version, source URL) and transitive notices were still marked as `needs_review` or "pending".

## Decision
**PDFium is excluded from the App Store alpha profile.** `PDFKit` serves as the supported App Store PDF backend. PDFium remains an optional sidecar component for advanced, proprietary, or internal non-App-Store builds, pending a complete audit of its transitive dependency notices.

## Artifact Updates
- **`Docs/legal/THIRD_PARTY_INVENTORY.yaml`**: 
  - PDFium `used_as` updated to `bundled_sidecar_non_app_store`.
  - PDFium `distributed_in_app_store_build` updated to `false`.
  - PDFium `app_store_status` updated to `excluded_from_app_store_profile`.
  - Added clarifying notes declaring PDFKit as the default App Store fallback.
- **`Docs/release/app-store-profile.yaml`**: Explicitly marked `pdfium_allowed: false`, set `pdf_backend: "PDFKit"`, and added `libpdfium` and `PDFSidecarExecutable` to `forbidden_runtime_binaries`.
- **`Docs/release/APP_STORE_BUILD_PROFILE.md`**: Stated explicitly that PDFium is excluded from the App Store alpha profile and that PDFKit is the supported default.
- **`THIRD_PARTY_NOTICES.md`**: Appended a clear disclaimer to the PDFium notice indicating it is expressly excluded from the App Store alpha profile and that its transitive notices remain pending for non-App-Store usage.

## Validator Behavior
- **`Scripts/validate_app_store_build_profile.py`**: Behavior remains structurally the same, but it now natively passes because PDFium's `distributed_in_app_store_build` flag is now `false`. The validator correctly bypasses the "strict provenance and notice" checks when the dependency is not bundled for the App Store.

## Validation Results
- `python3 Scripts/validate_app_store_dependency_boundaries.py` -> Passed.
- `python3 Scripts/validate_app_store_build_profile.py` -> Passed.
- `python3 Scripts/validate_public_project_readiness.py` -> Passed.
- `python3 Scripts/validate_notion_publisher.py` -> Passed.
- `python3 Scripts/validate_release_readiness.py` -> **Passed successfully**.

## Remaining Future Work
- For non-App-Store, proprietary, or future advanced builds that *do* require PDFium, a full audit must be completed to:
  1. Pin the exact PDFium version and source URL.
  2. Discover, extract, and bundle all transitive C/C++ dependency notices into `THIRD_PARTY_NOTICES.md`.

## Recommended Next Task
After release readiness passes with PDFium excluded, create the Alpha Release Readiness checklist and one pre-release command that aggregates architecture, publisher, dependency/license, and App Store profile gates.
