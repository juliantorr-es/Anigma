# Package.swift Best Practices & Templates

This guide provides templates and patterns for writing clean, documented Package.swift manifests that integrate with the build hygiene system.

## Core Rules

1. **Every target with C++ MUST have a `DEPS.toml`**
2. **Every linked library MUST have a justification comment**
3. **Every unsafe flag MUST have a reason comment**
4. **No hardcoded paths** (not even `$(HOME)`)
5. **Comments include: EXTERNAL_DEP, REASON, BUILD_ENV**

---

## Minimal Template (Pure Swift)

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyModule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "MyModule", targets: ["MyModule"])
    ],
    dependencies: [
        // External Swift packages go here
    ],
    targets: [
        .target(
            name: "MyModule",
            dependencies: [],
            path: "Sources/MyModule",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "MyModuleTests",
            dependencies: ["MyModule"],
            path: "Tests"
        )
    ]
)
```

---

## C++ Integration Template

Use this template for any package with C++ code.

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TextPipelineCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "TextPipelineCapsule",
            targets: ["TextPipelineCapsule"]
        ),
        .library(
            name: "TextPipelineNative",
            targets: ["TextPipelineNative"]
        )
    ],
    targets: [
        // ===================================
        // C++ native target
        // ===================================
        // REQUIREMENT: Must have DEPS.toml in package root
        .target(
            name: "TextPipelineNative",
            path: "Sources/TextPipelineNative",
            sources: ["text_pipeline.cpp"],
            publicHeadersPath: "include",
            cxxSettings: [
                // EXTERNAL_DEP: ICU (Unicode library)
                // REASON: Text normalization (NFKC) for consistent hashing
                // BUILD_ENV: macOS 13+, Linux x86_64
                .headerSearchPath("."),
                .define("UNICODE_ENABLED", to: "1"),
                
                // REASON: C++17 required for std::optional and constexpr
                // BUILD_ENV: all (clang standard feature)
                .unsafeFlags(["-std=c++17"]),
                
                // REASON: Disable exceptions to reduce code size (no exception handling in Swift)
                // BUILD_ENV: all (compiler flag)
                .unsafeFlags(["-fno-exceptions"])
            ],
            linkerSettings: [
                // EXTERNAL_DEP: ICU
                // REASON: Unicode text normalization and case folding
                // BUILD_ENV: macOS 13+, Linux x86_64
                .linkedLibrary("icui18n"),
                .linkedLibrary("icuuc"),
                
                // EXTERNAL_DEP: Accelerate (Apple framework)
                // REASON: SIMD optimization for text processing
                // BUILD_ENV: macOS 13+, iOS 17+
                .linkedFramework("Accelerate", .when(platforms: [.macOS, .iOS]))
            ]
        ),
        
        // ===================================
        // Swift wrapper target
        // ===================================
        .target(
            name: "TextPipelineCapsule",
            dependencies: ["TextPipelineNative"],
            path: "Sources/TextPipelineCapsule",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        
        // ===================================
        // Tests
        // ===================================
        .testTarget(
            name: "TextPipelineNativeTests",
            dependencies: ["TextPipelineNative"],
            path: "Tests/Native",
            cxxSettings: [
                .unsafeFlags(["-std=c++17"])
            ]
        ),
        .testTarget(
            name: "TextPipelineCapsuleTests",
            dependencies: ["TextPipelineCapsule"],
            path: "Tests/Swift",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ],
    cxxLanguageStandard: .cxx17
)
```

---

## Real Examples from Anigma

### Example 1: MediaFingerprintCapsule

**File**: `Packages/MediaFingerprintCapsule/Package.swift`

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MediaFingerprintCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MediaFingerprintCapsule",
            targets: ["MediaFingerprintCapsule"]
        ),
        .library(
            name: "MediaFingerprintNative",
            targets: ["MediaFingerprintNative"]
        )
    ],
    targets: [
        // C++ native library for perceptual image hashing
        // DEPS.toml required: see Packages/MediaFingerprintCapsule/DEPS.toml
        .target(
            name: "MediaFingerprintNative",
            path: "Sources/MediaFingerprintNative",
            sources: ["media_fingerprint.cpp"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("."),
                .define("STBI_NO_STDIO", to: "1"),
                
                // REASON: C++17 for structured bindings and constexpr
                .unsafeFlags(["-std=c++17"]),
                
                // REASON: Disable exceptions to reduce binary size (no exception handling in Swift)
                .unsafeFlags(["-fno-exceptions"])
            ],
            linkerSettings: [
                // EXTERNAL_DEP: Accelerate
                // REASON: SIMD-accelerated convolution for image feature extraction
                // BUILD_ENV: macOS 13+, iOS 17+
                .linkedFramework("Accelerate", .when(platforms: [.macOS, .iOS]))
            ]
        ),
        
        // Swift actor wrapper with MainActor isolation
        .target(
            name: "MediaFingerprintCapsule",
            dependencies: ["MediaFingerprintNative"],
            path: "Sources/MediaFingerprintCapsule",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        
        .testTarget(
            name: "MediaFingerprintCapsuleTests",
            dependencies: ["MediaFingerprintCapsule"],
            path: "Tests/MediaFingerprintCapsuleTests"
        )
    ],
    cxxLanguageStandard: .cxx17
)
```

**Corresponding DEPS.toml:**

```toml
# Packages/MediaFingerprintCapsule/DEPS.toml
[accelerate]
source = "system"
version = "native"
reason = "SIMD acceleration for image processing (convolution, FFT)"
build_env = ["macos_13+", "ios_17+"]
```

---

### Example 2: CompressionCapsule (Multiple Dependencies)

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CompressionCapsule",
    platforms: [.macOS(.v14), .linux],
    products: [
        .library(name: "CompressionCapsule", targets: ["CompressionCapsule"]),
        .library(name: "CompressionNative", targets: ["CompressionNative"])
    ],
    targets: [
        // C++ compression utilities
        // DEPS.toml required: see Packages/CompressionCapsule/DEPS.toml
        .target(
            name: "CompressionNative",
            path: "Sources/CompressionNative",
            sources: ["compression.cpp"],
            cxxSettings: [
                // EXTERNAL_DEP: zstd
                // REASON: Zstandard provides 2-5x better compression ratio than Gzip
                // BUILD_ENV: macOS 13+, Linux x86_64
                .headerSearchPath("."),
                
                .unsafeFlags(["-std=c++17"])
            ],
            linkerSettings: [
                // EXTERNAL_DEP: zstd
                // REASON: Link against Zstandard library for compression operations
                // BUILD_ENV: macOS 13+, Linux x86_64 (via Homebrew or system package)
                .linkedLibrary("zstd"),
                
                // EXTERNAL_DEP: brotli
                // REASON: Brotli compression for HTTP/text content (11-level optimization)
                // BUILD_ENV: macOS 13+, Linux x86_64
                .linkedLibrary("brotli")
            ]
        ),
        
        .target(
            name: "CompressionCapsule",
            dependencies: ["CompressionNative"],
            path: "Sources/CompressionCapsule",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        
        .testTarget(
            name: "CompressionCapsuleTests",
            dependencies: ["CompressionCapsule"],
            path: "Tests"
        )
    ],
    cxxLanguageStandard: .cxx17
)
```

**Corresponding DEPS.toml:**

```toml
# Packages/CompressionCapsule/DEPS.toml
[zstd]
source = "system_or_swiftpm"
version = "1.5.2+"
reason = "Compression library: 2-5x better ratio than Gzip"
build_env = ["macos_13+", "linux_x86_64"]
install_macos = "brew install zstd"
install_linux = "sudo apt-get install zstandard libzstd-dev"

[brotli]
source = "system_or_swiftpm"
version = "1.0.0+"
reason = "Brotli compression for optimal text encoding"
build_env = ["macos_13+", "linux_x86_64"]
install_macos = "brew install brotli"
install_linux = "sudo apt-get install brotli libbrotli-dev"
```

---

## Comment Format Reference

### For Linked Libraries

```swift
// EXTERNAL_DEP: <library-name>
// REASON: <why this library is needed>
// BUILD_ENV: <where it's available>
.linkedLibrary("libname")
```

**Example:**

```swift
// EXTERNAL_DEP: zstd
// REASON: High-ratio compression (2-5x better than Gzip)
// BUILD_ENV: macOS 13+, Linux x86_64
.linkedLibrary("zstd")
```

### For Unsafe Compiler Flags

```swift
// REASON: <why this flag is necessary>
// BUILD_ENV: <where applicable>
.unsafeFlags(["-std=c++17"])
```

**Example:**

```swift
// REASON: C++17 required for std::optional and structured bindings
// BUILD_ENV: all (clang compiler feature)
.unsafeFlags(["-std=c++17"])
```

### For System Frameworks (No Comment Needed)

```swift
// System frameworks are automatically available and don't need justification
.linkedFramework("AppKit")
.linkedFramework("Accelerate", .when(platforms: [.macOS, .iOS]))
```

---

## Anti-Patterns

### ❌ BAD: Hardcoded Homebrew Paths

```swift
// WRONG!
linkerSettings: [
    .unsafeFlags(["-L/opt/homebrew/opt/zstd/lib"]),
    .unsafeFlags(["-I/opt/homebrew/opt/zstd/include"]),
    .linkedLibrary("z")  // What is this? No comment!
]
```

**Problems:**
- Fails on Linux, non-Homebrew Macs, different architectures
- Mystery library with no explanation
- Not reproducible

### ❌ BAD: No Justification

```swift
// WRONG!
cxxSettings: [
    .unsafeFlags(["-fvisibility=hidden", "-Wl,--gc-sections"])
]
```

**Problems:**
- Future maintainers don't understand the tradeoffs
- Can't evaluate if flags are still needed
- Impossible to audit for security

### ❌ BAD: Missing DEPS.toml

```
MediaFingerprintCapsule/
├── Package.swift        ← Has C++17, links Accelerate
├── Sources/
└── Tests/
# MISSING: DEPS.toml
```

**Problems:**
- No documentation of requirements
- New developers don't know what to install
- Can't validate build hygiene

---

## Validation Checklist

Before committing Package.swift:

- [ ] Package has `DEPS.toml` (if using native code)
- [ ] Every `linkedLibrary()` has comment above with EXTERNAL_DEP, REASON, BUILD_ENV
- [ ] Every `unsafeFlags()` has comment above with REASON, BUILD_ENV
- [ ] No hardcoded paths (no `/opt/homebrew`, `/usr/local`, etc.)
- [ ] System frameworks don't need comments
- [ ] Comments placed directly above the setting they describe
- [ ] `./scripts/validate_build_hygiene.sh` passes

---

## Common Flags & Their Justification

### C++ Standard

```swift
// REASON: C++17 enables std::optional, constexpr, structured bindings
.unsafeFlags(["-std=c++17"])
```

### Exception Handling

```swift
// REASON: Disable exceptions to reduce binary size (no Swift exception interop)
.unsafeFlags(["-fno-exceptions"])
```

### Visibility

```swift
// REASON: Hide internal symbols to reduce binary size and prevent symbol conflicts
.unsafeFlags(["-fvisibility=hidden"])
```

### Optimizations

```swift
// REASON: Optimize for size when space is critical (mobile deployments)
.unsafeFlags(["-Os"])
```

---

## Platform-Specific Linking

```swift
linkerSettings: [
    // Available on macOS and iOS
    .linkedFramework("Accelerate", .when(platforms: [.macOS, .iOS])),
    
    // Available on macOS only
    .linkedFramework("AppKit", .when(platforms: [.macOS])),
    
    // Available on Linux only
    .linkedLibrary("pthread", .when(platforms: [.linux]))
]
```

---

## See Also

- [BUILD_HYGIENE.md](./BUILD_HYGIENE.md) – Detailed hygiene guidelines
- [DEPS_TOML_TEMPLATE.md](./DEPS_TOML_TEMPLATE.md) – DEPS.toml format
- [validate_build_hygiene.sh](../../scripts/validate_build_hygiene.sh) – Validation tool
- [Swift Package Manager Docs](https://swift.org/package-manager/)
