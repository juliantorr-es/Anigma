# Build and Release Pipeline

## Build Scripts
- Primary build entry is `Scripts/build.sh` as documented in `README.md`.
- Application packaging helpers include `build-app.sh` and `build_installer.sh` at the repo root.
- Installer metadata is stored in `Distribution.xml` and `installer/` assets.

## SwiftPM Configuration
- Package graph and targets are declared in `Package.swift`.
- Dependencies are pinned in `Package.resolved`.

## Native Dependencies
- Native libraries live under `Vendor/lib` (for example `Vendor/lib/libpdfium.dylib`).
- Native shim targets are defined in `Package.swift` under the `nativeTargets` list.

## Key References
- `README.md`
- `Scripts/build.sh`
- `Package.swift`
