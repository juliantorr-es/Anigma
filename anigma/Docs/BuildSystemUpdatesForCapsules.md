# Build System Updates for Subsequent Capsules

## Overview

To support the new capsules, the Swift Package Manager manifest (`Package.swift`) must be extended with system‑library targets for ICU, compression libraries, and FFmpeg. This document outlines the required changes and conditional compilation strategies.

## 1. New System‑Library Targets

Add the following system‑library targets to `Package.swift` (in the `coreTargets` array), following the pattern of existing targets like `CPDFium` and `CHarfBuzz`.

### 1.1 ICU (International Components for Unicode)

```swift
.systemLibrary(
    name: "CICU",
    path: "Packages/CICU",
    pkgConfig: "icu-i18n",
    providers: [
        .apt(["libicu-dev"]),
        .brew(["icu4c"])
    ]
)
```

**Notes**:
- The `CICU` package directory will contain a minimal `module.modulemap` and header wrapper.
- ICU version must be locked to a specific major version (e.g., 70.x) for determinism.

### 1.2 zstd (Zstandard Compression)

```swift
.systemLibrary(
    name: "Czstd",
    path: "Packages/Czstd",
    pkgConfig: "libzstd",
    providers: [
        .apt(["libzstd-dev"]),
        .brew(["zstd"])
    ]
)
```

### 1.3 brotli

```swift
.systemLibrary(
    name: "CBrotli",
    path: "Packages/CBrotli",
    pkgConfig: "libbrotlienc",
    providers: [
        .apt(["libbrotli-dev"]),
        .brew(["brotli"])
    ]
)
```

### 1.4 lz4

```swift
.systemLibrary(
    name: "CLz4",
    path: "Packages/CLz4",
    pkgConfig: "liblz4",
    providers: [
        .apt(["liblz4-dev"]),
        .brew(["lz4"])
    ]
)
```

### 1.5 FFmpeg (Optional)

```swift
.systemLibrary(
    name: "CFFmpeg",
    path: "Packages/CFFmpeg",
    pkgConfig: "libavcodec libavformat libavutil libswscale",
    providers: [
        .apt(["libavcodec-dev", "libavformat-dev", "libavutil-dev", "libswscale-dev"]),
        .brew(["ffmpeg"])
    ]
)
```

**Notes**:
- FFmpeg is only required for `MediaFingerprintCapsule`. It can be marked optional.

## 2. Conditional Compilation Flags

Define Swift and C preprocessor flags to conditionally compile capsules when their dependencies are available.

### 2.1 Swift Compiler Settings

Add the following to the `strictConcurrencySettings` array (or create a separate `capsuleSettings` array):

```swift
let capsuleSettings: [SwiftSetting] = [
    .define("ANIGMA_HAVE_ICU", .when(platforms: [.linux, .macOS])),
    .define("ANIGMA_HAVE_ZSTD", .when(platforms: [.linux, .macOS])),
    .define("ANIGMA_HAVE_BROTLI", .when(platforms: [.linux, .macOS])),
    .define("ANIGMA_HAVE_LZ4", .when(platforms: [.linux, .macOS])),
    .define("ANIGMA_HAVE_FFMPEG", .when(platforms: [.linux, .macOS])),
]
```

These flags will be set only when the corresponding system‑library target is successfully resolved.

### 2.2 C/C++ Settings

In the `AnigmaNativeShims` target, add `cSettings` and `cxxSettings` to propagate the flags to native code:

```swift
.target(
    name: "AnigmaNativeShims",
    dependencies: ["CClipper2", "CICU", "Czstd", "CBrotli", "CLz4", "CFFmpeg"], // optional dependencies
    path: "Native/Shims",
    sources: [...],
    publicHeadersPath: "include",
    cSettings: [
        .define("ANIGMA_BUILDING_SHIMS"),
        .define("ANIGMA_HAVE_ICU", .when(condition: .exists("CICU"))),
        .define("ANIGMA_HAVE_ZSTD", .when(condition: .exists("Czstd"))),
        // ... similarly for others
    ],
    cxxSettings: [...]
)
```

## 3. Fallback Mechanisms

Capsules should gracefully degrade when a dependency is missing.

### 3.1 Runtime Detection

Each capsule’s Swift wrapper should check for the presence of the native library at runtime (e.g., via `dlopen` or a weak‑linked symbol). If the library is unavailable, the wrapper should:

1. Log a warning.
2. Fall back to the existing Swift implementation (if any).
3. Throw a `CapsuleError.dependencyUnavailable` error if no fallback exists.

### 3.2 Compile‑Time Exclusion

For capsules that have no fallback (e.g., `TextPipelineCapsule` depends entirely on ICU), the entire capsule can be excluded from compilation when the dependency is missing, using conditional compilation blocks:

```swift
#if ANIGMA_HAVE_ICU
public actor TextPipelineCapsule: CapsuleProtocol {
    // ...
}
#endif
```

## 4. Package.swift Integration Example

Below is a diff‑style example of how the `Package.swift` changes might look.

```diff
 let coreTargets: [Target] = [
+    // New system libraries for capsule dependencies
+    .systemLibrary(
+        name: "CICU",
+        path: "Packages/CICU",
+        pkgConfig: "icu-i18n",
+        providers: [
+            .apt(["libicu-dev"]),
+            .brew(["icu4c"])
+        ]
+    ),
+    .systemLibrary(
+        name: "Czstd",
+        path: "Packages/Czstd",
+        pkgConfig: "libzstd",
+        providers: [
+            .apt(["libzstd-dev"]),
+            .brew(["zstd"])
+        ]
+    ),
+    .systemLibrary(
+        name: "CBrotli",
+        path: "Packages/CBrotli",
+        pkgConfig: "libbrotlienc",
+        providers: [
+            .apt(["libbrotli-dev"]),
+            .brew(["brotli"])
+        ]
+    ),
+    .systemLibrary(
+        name: "CLz4",
+        path: "Packages/CLz4",
+        pkgConfig: "liblz4",
+        providers: [
+            .apt(["liblz4-dev"]),
+            .brew(["lz4"])
+        ]
+    ),
+    .systemLibrary(
+        name: "CFFmpeg",
+        path: "Packages/CFFmpeg",
+        pkgConfig: "libavcodec libavformat libavutil libswscale",
+        providers: [
+            .apt(["libavcodec-dev", "libavformat-dev", "libavutil-dev", "libswscale-dev"]),
+            .brew(["ffmpeg"])
+        ]
+    ),
     .systemLibrary(
         name: "CHarfBuzz", path: "Packages/CHarfBuzz",
         pkgConfig: "harfbuzz",
```

## 5. Dependency Version Locking

To ensure deterministic builds, the exact versions of system libraries should be documented and, where possible, pinned.

- **ICU**: Lock to major version 70.x (e.g., `libicu-dev=70.1` on Ubuntu).
- **zstd**, **brotli**, **lz4**: Use the latest stable release from the distribution’s repository.
- **FFmpeg**: Use the system’s default version (usually ≥ 4.x).

Add a `Docs/Dependencies.md` file listing the required versions and installation instructions for each supported platform (Ubuntu, macOS).

## 6. Next Steps

1. **Create package directories** (`Packages/CICU`, `Packages/Czstd`, etc.) with minimal `module.modulemap` files.
2. **Update `Package.swift`** with the new system‑library targets.
3. **Add conditional compilation flags** to `AnigmaNativeShims` and Swift targets.
4. **Test the build** on clean Ubuntu and macOS environments to verify dependency resolution.
5. **Implement fallback logic** in capsule Swift wrappers.

---

*Last updated: 2026‑01‑12*  
*Author: opencode*  
*Status: Draft for implementation*