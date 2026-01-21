# Anigma

**A governed, local-first Swift stack for institutional AI.**

## Product
This repository ships the **Anigma** macOS application.
It includes:
- **Anigma.app**: The main macOS application (SwiftUI/AppKit).
- **LaunchAgent**: A background agent for monitoring.
- **XPC Service**: A helper service for privileged operations.

## Build
The repository is designed to build on a fresh machine with minimal dependencies.

### Prerequisites
- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

### Building
To build the application and all dependencies:

```bash
Scripts/build.sh
```

### Testing
To run the full test suite:

```bash
Scripts/test.sh
```

## Architecture
The repository is structured as a modular monolith:
- **App/**: Application entry points and platform-specific glue code.
- **Packages/**: Feature modules and shared libraries (SwiftPM).
- **Native/**: Native (C/C++) dependencies.
- **ThirdParty/**: Vendored third-party dependencies.
- **Tests/**: Tests for owned modules.

For a detailed breakdown of the repository structure, see [Docs/RepoShape.md](Docs/RepoShape.md).

## Third-Party Dependencies

All third-party code is vendored or managed via SwiftPM.
See [Docs/ThirdParty.md](Docs/ThirdParty.md) for a complete list.

## PDFium Dependency

The build system expects `pdfium` library to be available for certain features:
- `harmonia-surface` target (PDF processing capabilities)
- Other PDF-related components

**Installation Status**: ✅ The `pdfium` library binaries are already present at `Vendor/lib/libpdfium.dylib`.

**Note**: If encountering pdfium linking errors, ensure the library is accessible via the relative path `../../Vendor/lib` from the build directory, or set the `LIBRARY_PATH` environment variable to include the full path to `Vendor/lib`.
