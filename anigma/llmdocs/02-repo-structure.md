# Repository Structure

## Top-Level Layout
- `App/` holds the macOS application UI plus the Safari extension bundle.
- `Packages/` contains the SwiftPM packages for core runtime, domain modules, and shared libraries.
- `Sources/` hosts non-package targets such as `RuntimeOrchestrator` and `AnigmaUI` declared in `Package.swift`.
- `Docs/` includes governance, architecture guides, API references, and sprint notes.
- `Scripts/` captures build, test, and release automation.
- `Tests/` contains unit and integration tests for owned modules.
- `Native/` and `Vendor/` provide C/C++ shims and vendored native libraries.

## App Shells
- The macOS app lives under `App/MacApp` with SwiftUI views, services, and role-based shells.
- The Safari web extension is under `App/SafariExtension` with manifest and script assets.

## Package Organization
- Core libraries are grouped under `Packages/` (for example `Packages/AnigmaCore`, `Packages/ContractsCore`, `Packages/StorageCore`).
- Domain modules such as `Packages/HarmoniaModule` and `Packages/DiaplasionModule` live alongside capsule and toolkit packages.
- Executable targets live in packages such as `Packages/AnigmaCLI`, `Packages/AnigmaDaemon`, and `Packages/MLWorkerExecutable`.

## Supporting Assets
- Build artifacts and scripts appear at the repository root, including `build-app.sh`, `build_installer.sh`, and `Distribution.xml`.
- Configuration and tooling output (swiftlint reports, build logs) are also stored at the root.

## Key References
- `README.md`
- `Package.swift`
- `App/MacApp/AnigmaApp.swift`
