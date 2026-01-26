# Build Hygiene Guidelines

## Overview

Build hygiene ensures that our Swift packages remain **reproducible**, **portable**, and **maintainable**. This guide establishes best practices for configuring native dependencies, linker settings, and C++ integration without hardcoding paths.

## Core Principles

1. **No Hardcoded Paths** – Never use `/opt/homebrew`, `/usr/local`, or other absolute paths
2. **Self-Documenting Dependencies** – All external dependencies must have DEPS.toml
3. **Justified Build Flags** – Every unsafe flag must have a reason comment
4. **Environment Awareness** – Build configuration must specify supported platforms/environments
5. **Reproducible Builds** – Same source code + same environment = identical binaries

---

## DEPS.toml Format

Each package using native libraries, C++ integration, or system frameworks **must** have a `DEPS.toml` file in its root directory (same level as `Package.swift`).

### Template Structure

```toml
# DEPS.toml - External Dependencies Declaration
# This file documents all external, non-Swift dependencies
# Used to ensure reproducible builds and clarity on system requirements

[zstd]
# Where the dependency comes from:
# - "system" = provided by OS (e.g., /usr/lib, /opt/homebrew, system frameworks)
# - "swiftpm" = fetched via Swift Package Manager
# - "system_or_swiftpm" = will use system version if available, fallback to SwiftPM
source = "system_or_swiftpm"

# Version constraint (semver style)
version = "1.5.2+"

# Human-readable reason for inclusion
reason = "Compression: 2-5x faster than Swift Gzip for media processing"

# Build environments where this dependency is available
# Use: macos_X, ios_X, linux, windows, etc.
build_env = ["macos_13+", "linux_x86_64"]

# (Optional) How to acquire on different systems:
# install_linux = "sudo apt-get install zstd libzstd-dev"
# install_macos = "brew install zstd"

[icu]
source = "system"
version = "72.0+"
reason = "Unicode normalization (NFKC) for text canonicalization in AccessumModule"
build_env = ["macos_13+", "linux_x86_64"]

[accelerate]
source = "system"
version = "native"
reason = "Apple framework for SIMD operations in MediaFingerprintCapsule"
build_env = ["macos_13+", "ios_17+"]
```

### Field Definitions

| Field | Required | Description |
|-------|----------|-------------|
| `source` | Yes | `"system"`, `"swiftpm"`, or `"system_or_swiftpm"` |
| `version` | Yes | Semantic version with constraint (e.g., `"1.5.2+"`, `"2.0.0"`) |
| `reason` | Yes | Why this dependency is critical (business/technical justification) |
| `build_env` | Yes | List of platforms/configurations where available |
| `install_*` | No | Installation instructions per OS |

---

## Package.swift Linker Configuration

### Correct Pattern with Comments

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TextPipelineCapsule",
    products: [
        .library(name: "TextPipelineCapsule", targets: ["TextPipelineCapsule"])
    ],
    targets: [
        // C++ text processing with ICU support
        .target(
            name: "TextPipelineNative",
            path: "Sources/TextPipelineNative",
            sources: ["text_pipeline.cpp"],
            publicHeadersPath: "include",
            cxxSettings: [
                // EXTERNAL_DEP: ICU (Unicode library)
                // REASON: Text normalization (NFKC) for consistent hashing
                // BUILD_ENV: macOS 13+, Linux x86_64
                .headerSearchPath("$(ICU_PATH)/include"),
                .define("U_STATIC_IMPLEMENTATION", to: "1"),
                .unsafeFlags(["-std=c++17", "-fno-exceptions"])
            ],
            linkerSettings: [
                // EXTERNAL_DEP: ICU
                // REASON: Link against libicu for Unicode operations
                // BUILD_ENV: macOS (native), Linux (system package)
                .linkedLibrary("icui18n"),
                .linkedLibrary("icuuc"),
                
                // Apple framework: always available on macOS/iOS
                .linkedFramework("Accelerate", .when(platforms: [.macOS, .iOS]))
            ]
        ),
        
        // Swift wrapper
        .target(
            name: "TextPipelineCapsule",
            dependencies: ["TextPipelineNative"],
            path: "Sources/TextPipelineCapsule",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        
        .testTarget(
            name: "TextPipelineCapsuleTests",
            dependencies: ["TextPipelineCapsule"],
            path: "Tests"
        )
    ],
    cxxLanguageStandard: .cxx17
)
```

### Comment Template for External Dependencies

Place comments **immediately above** the setting they justify:

```swift
// EXTERNAL_DEP: <library-name>
// REASON: <business or technical justification>
// BUILD_ENV: [<comma-separated platforms>]
.linkedLibrary("mylib")
```

Example patterns:

```swift
// EXTERNAL_DEP: zstd
// REASON: Compression library (2-5x faster than deflate for media)
// BUILD_ENV: macOS 13+, Linux x86_64
.linkedLibrary("zstd")

// EXTERNAL_DEP: pdfix (PDFium wrapper)
// REASON: PDF text extraction with layout preservation
// BUILD_ENV: macOS 13+
.linkedLibrary("pdfium")

// No comment needed for Apple frameworks:
.linkedFramework("AppKit")  // System frameworks don't require justification
```

### C++ Unsafe Flags Pattern

```swift
cxxSettings: [
    // REASON: C++17 required for std::optional, constexpr operations
    // EXTERNAL_DEP: none (Swift/Clang standard)
    // BUILD_ENV: all (clang feature)
    .unsafeFlags(["-std=c++17"]),
    
    // REASON: Disable exceptions to reduce code size & overhead
    // BUILD_ENV: all (compiler flag)
    .unsafeFlags(["-fno-exceptions"])
]
```

---

## Anti-Patterns to Avoid

### ❌ BAD: Hardcoded Homebrew Paths

```swift
// WRONG - Never do this!
linkerSettings: [
    .unsafeFlags(["-L/opt/homebrew/opt/zstd/lib"]),
    .unsafeFlags(["-I/opt/homebrew/opt/zstd/include"]),
]
```

**Why?** Fails on other machines, CI/CD, different architectures

### ❌ BAD: Mystery Libraries

```swift
// WRONG - No justification!
linkerSettings: [
    .linkedLibrary("libX"),
    .linkedLibrary("libY")
]
```

**Why?** Maintainers don't know why it's needed; hard to audit security

### ❌ BAD: Undocumented Flags

```swift
// WRONG - Why these flags?
cxxSettings: [
    .unsafeFlags(["-fvisibility=hidden", "-Wl,--gc-sections"])
]
```

**Why?** Future developers won't understand the tradeoffs

### ❌ BAD: Missing DEPS.toml

```
MediaFingerprintCapsule/
├── Package.swift          ← Uses C++17, links Accelerate
├── Sources/
└── Tests/
# MISSING: DEPS.toml
```

**Why?** No documentation of requirements; fails for new team members

---

## Correct Pattern Checklist

Use this checklist for every Package.swift with native code:

- [ ] Package has `DEPS.toml` in same directory as `Package.swift`
- [ ] Every `linkedLibrary()` has comment with EXTERNAL_DEP, REASON, BUILD_ENV
- [ ] Every `unsafeFlags()` has comment with REASON and BUILD_ENV
- [ ] No absolute paths like `/opt/homebrew`, `/usr/local`
- [ ] All `cxxSettings` use proper search path configuration
- [ ] System frameworks (AppKit, Accelerate, etc.) don't need comment
- [ ] `build_env` lists specific OS versions and architectures

---

## Build Environment Variables

Use environment variables for flexibility. Example in build script:

```bash
#!/bin/bash

# Detect system
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS with Homebrew
    export ICU_PATH=$(brew --prefix icu4c)
    export ZSTD_PATH=$(brew --prefix zstd)
else
    # Linux
    export ICU_PATH="/usr"
    export ZSTD_PATH="/usr"
fi

swift build \
    -Xswiftc -I$(${ICU_PATH}/include) \
    -Xlinker -L$(${ZSTD_PATH}/lib)
```

Then in Package.swift:

```swift
.headerSearchPath("\(ProcessInfo.processInfo.environment["ICU_PATH"] ?? "/usr")/include")
```

---

## Validation

Run the build hygiene validator before committing:

```bash
./scripts/validate_build_hygiene.sh
```

This checks:
- ✓ No `/opt/homebrew` hardcoded paths
- ✓ All unsafe flags documented
- ✓ All linked libraries documented
- ✓ C++ targets have DEPS.toml
- ✓ Generates dependency report

Exit code:
- `0` = Clean (passes)
- `1` = Violations (fails)

---

## Examples by Use Case

### Example 1: Media Processing (C++)

**Package**: `MediaFingerprintCapsule`

```toml
# DEPS.toml
[accelerate]
source = "system"
version = "native"
reason = "SIMD-accelerated image convolution for fingerprinting"
build_env = ["macos_13+", "ios_17+"]
```

```swift
// Package.swift target
.target(
    name: "MediaFingerprintNative",
    cxxSettings: [
        // REASON: C++17 for std::array, constexpr algorithms
        .unsafeFlags(["-std=c++17", "-fno-exceptions"])
    ],
    linkerSettings: [
        // Apple framework for SIMD operations
        .linkedFramework("Accelerate", .when(platforms: [.macOS, .iOS]))
    ]
)
```

### Example 2: Text Processing with ICU

**Package**: `TextPipelineCapsule`

```toml
# DEPS.toml
[icu]
source = "system_or_swiftpm"
version = "72.0+"
reason = "Unicode text normalization (NFKC) for consistent hashing"
build_env = ["macos_13+", "linux_x86_64"]
install_macos = "brew install icu4c"
install_linux = "sudo apt-get install libicu-dev"
```

```swift
linkerSettings: [
    // EXTERNAL_DEP: ICU
    // REASON: Unicode normalization and case folding
    // BUILD_ENV: macOS 13+, Linux x86_64
    .linkedLibrary("icui18n"),
    .linkedLibrary("icuuc")
]
```

### Example 3: Compression Library

**Package**: `CompressionCapsule`

```toml
# DEPS.toml
[zstd]
source = "system_or_swiftpm"
version = "1.5.2+"
reason = "Compression: 2-5x faster than Gzip for large datasets"
build_env = ["macos_13+", "linux_x86_64", "ios_17+"]
install_macos = "brew install zstd"
install_linux = "sudo apt-get install zstandard libzstd-dev"
```

---

## CI/CD Integration

In your CI pipeline, always run:

```yaml
- name: Validate Build Hygiene
  run: ./scripts/validate_build_hygiene.sh
```

This prevents shipping packages with hardcoded paths or mystery dependencies.

---

## References

- [Swift Package Manager Documentation](https://swift.org/package-manager/)
- [Build Settings Reference](https://developer.apple.com/documentation/xcode/build-settings-reference)
- [Homebrew Portable Builds](https://docs.brew.sh/Portable-Builds)
- [TOML Format Spec](https://toml.io/)

---

## Questions?

For questions about build hygiene, consult:
1. This guide
2. Existing DEPS.toml files in the repo
3. Validation script output: `./scripts/validate_build_hygiene.sh`
