# Native Dependencies & Architecture

## Principles

1.  **App Isolation**: The main application (`Anigma proper`) only links **permissive-only** native dependencies. No AGPL, LGPL, or GPL libraries are allowed in the main process address space.
2.  **Sidecar Containment**: Copyleft (GPL/LGPL/AGPL) and heavy dependencies (Office engines, ML runtimes) must live in the `AnigmaSidecar` process. They are accessed via IPC with strict resource budgeting.
3.  **ABI Stability**: Swift code never touches C++ headers directly. All C++ libraries are wrapped in strict C ABI shims with opaque handles.

## Directory Structure

- `Sources/CapabilityModules/<ModuleName>/`: Swift-facing APIs.
- `Native/ThirdParty/<libname>/`: Vendored source or build recipes (submodules/tarballs).
- `Native/Shims/<libname>_shim/`: C ABI wrappers around C++ libraries.
- `Tools/NativeBuild/`: Reproducible build scripts (CMake, XCFramework generation).

## Dependency Manifest

All native dependencies are tracked in `Native/native-deps.lock.json`. This file contains the authoritative version, source URL, license, and content hash for every vendored library.

## Module Map

### App Context (Permissive)

| Module | Purpose | Native Dep |
| :--- | :--- | :--- |
| **DocumentIRKit** | Canonical IR for docs | None (Swift) |
| **ContainerKit** | Safe Zip/Container IO | `libzip` / `minizip-ng`, `zlib` |
| **OOXMLKit** | Format-level edit | `pugixml` |
| **RenderKit** | Vector/PDF render | `Skia`, `PDFium` |
| **TypographyKit** | Text shaping/metrics | `ICU`, `HarfBuzz`, `FreeType` |
| **ColorKit** | Color pipeline | `lcms2`, `OpenColorIO` (opt) |
| **VectorOpsKit** | Boolean/Path ops | `Clipper2`, `libtess2` |
| **CompressionKit** | Storage compression | `zstd`, `brotli`, `lz4` |
| **AnimationKit** | UI Motion | `Rive`, `Skottie` |
| **ObservabilityKit** | Telemetry/Logs | `spdlog`, `fmt`, `OpenTelemetry`, `sentry-native` |

### Sidecar Context (Heavy/Copyleft)

| Service | Purpose | Native Dep |
| :--- | :--- | :--- |
| **SidecarOfficeService** | High-fidelity Office | `LibreOfficeKit`, `ONLYOFFICE` |
| **SidecarPDFService** | Heavy PDF mutation | `MuPDF` |
| **SidecarTranslateService** | ML Translation | `Marian NMT` |
