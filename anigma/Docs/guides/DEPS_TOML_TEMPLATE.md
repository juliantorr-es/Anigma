# DEPS.toml Template & Reference

This document provides templates and examples for creating `DEPS.toml` files for Anigma capsules.

## When to Use DEPS.toml

Create a `DEPS.toml` file in your package root (same directory as `Package.swift`) if your package:

- [ ] Uses C++ or other compiled languages
- [ ] Links against system libraries
- [ ] Uses non-Swift package manager dependencies
- [ ] Requires specific platform versions
- [ ] Has external build requirements

## Minimal Template

```toml
# DEPS.toml
# External dependencies for [YourCapsule]
# Validated with: ./scripts/validate_build_hygiene.sh

# Example: system framework dependency
[accelerate]
source = "system"
version = "native"
reason = "SIMD acceleration for image processing"
build_env = ["macos_13+", "ios_17+"]
```

## Complete Template

```toml
# DEPS.toml - [PackageName] External Dependencies
# Last updated: 2025-01-26
# Maintainer: [Team Name]
#
# This file documents all non-Swift dependencies required for reproducible builds.
# Validated by: ./scripts/validate_build_hygiene.sh
#
# source: "system" | "swiftpm" | "system_or_swiftpm"
# version: semver with constraints (e.g., "1.5.2+", "2.0.0", "1.0.*")
# reason: business/technical justification
# build_env: platforms where available (e.g., "macos_13+", "linux_x86_64", "ios_17+")

[accelerate]
source = "system"
version = "native"
reason = "Apple framework for SIMD operations (required for image hashing)"
build_env = ["macos_13+", "ios_17+"]

[icui18n]
source = "system_or_swiftpm"
version = "72.0+"
reason = "Unicode text normalization (NFKC) for consistent hashing across platforms"
build_env = ["macos_13+", "linux_x86_64"]
install_macos = "brew install icu4c"
install_linux = "sudo apt-get install libicu-dev"

[zstd]
source = "system_or_swiftpm"
version = "1.5.2+"
reason = "Compression library providing 2-5x better ratio than deflate for bulk data"
build_env = ["macos_13+", "linux_x86_64"]
install_macos = "brew install zstd"
install_linux = "sudo apt-get install zstandard libzstd-dev"
```

---

## Real-World Examples

### Example 1: MediaFingerprintCapsule (Image Processing)

**File**: `Packages/MediaFingerprintCapsule/DEPS.toml`

```toml
# DEPS.toml - MediaFingerprintCapsule
# Dependencies for perceptual image hashing

[accelerate]
source = "system"
version = "native"
reason = "SIMD-accelerated convolution operations for image feature extraction"
build_env = ["macos_13+", "ios_17+"]
```

**Corresponding Package.swift:**

```swift
.target(
    name: "MediaFingerprintNative",
    linkerSettings: [
        .linkedFramework("Accelerate", .when(platforms: [.macOS, .iOS]))
    ]
)
```

---

### Example 2: TextPipelineCapsule (Unicode Text Processing)

**File**: `Packages/TextPipelineCapsule/DEPS.toml`

```toml
# DEPS.toml - TextPipelineCapsule
# Dependencies for text normalization and language processing

[icui18n]
source = "system_or_swiftpm"
version = "72.0+"
reason = "Unicode 15.0 text normalization (NFKC) for consistent string canonicalization"
build_env = ["macos_13+", "linux_x86_64"]
install_macos = "brew install icu4c"
install_linux = "sudo apt-get install libicu-dev"

[icuuc]
source = "system_or_swiftpm"
version = "72.0+"
reason = "ICU Unicode Common library (required for icui18n)"
build_env = ["macos_13+", "linux_x86_64"]
```

**Corresponding Package.swift:**

```swift
.target(
    name: "TextPipelineNative",
    linkerSettings: [
        // EXTERNAL_DEP: ICU
        // REASON: Unicode normalization for text pipelines
        // BUILD_ENV: macOS 13+, Linux x86_64
        .linkedLibrary("icui18n"),
        .linkedLibrary("icuuc")
    ]
)
```

---

### Example 3: CompressionCapsule (Data Compression)

**File**: `Packages/CompressionCapsule/DEPS.toml`

```toml
# DEPS.toml - CompressionCapsule
# Dependencies for high-performance data compression

[zstd]
source = "system_or_swiftpm"
version = "1.5.2+"
reason = "Zstandard compression: 2-5x better ratio than Gzip, faster decompression for bulk data"
build_env = ["macos_13+", "linux_x86_64", "windows_10+"]
install_macos = "brew install zstd"
install_linux = "sudo apt-get install zstandard libzstd-dev"
install_windows = "choco install zstandard"

[brotli]
source = "system_or_swiftpm"
version = "1.0.0+"
reason = "Brotli compression: optimal for HTTP/text content (11-level compression)"
build_env = ["macos_13+", "linux_x86_64"]
install_macos = "brew install brotli"
install_linux = "sudo apt-get install brotli libbrotli-dev"
```

---

### Example 4: PDFProcessingCapsule (PDF Extraction)

**File**: `Packages/PDFProcessingCapsule/DEPS.toml`

```toml
# DEPS.toml - PDFProcessingCapsule
# Dependencies for PDF text extraction and analysis

[pdfium]
source = "system_or_swiftpm"
version = "6.0.0+"
reason = "PDFium library for robust PDF parsing and text extraction with layout preservation"
build_env = ["macos_13+", "linux_x86_64"]
install_macos = "brew install pdfium-core"
install_linux = "sudo apt-get install libpdfium-dev"

[poppler]
source = "system_or_swiftpm"
version = "23.0+"
reason = "Poppler for PDF rendering to images (fallback for unsupported PDFs)"
build_env = ["linux_x86_64"]
install_linux = "sudo apt-get install libpoppler-dev"
```

---

## Source Options

### `source = "system"`

Dependency is provided by the operating system or system package manager.

**When to use:**
- Apple frameworks (AppKit, Foundation, Accelerate, etc.)
- System libraries on Linux (/usr/lib, /usr/local/lib)
- Packages in Homebrew on macOS

**Example:**
```toml
[accelerate]
source = "system"
version = "native"
reason = "Apple system framework"
build_env = ["macos_13+", "ios_17+"]
```

### `source = "swiftpm"`

Dependency is only available through Swift Package Manager.

**When to use:**
- No system package available
- Project manages exact version via SwiftPM

**Example:**
```toml
[some-pure-swift-lib]
source = "swiftpm"
version = "2.1.0"
reason = "Pure Swift library for JSON processing"
build_env = ["macos_13+", "linux_x86_64"]
```

### `source = "system_or_swiftpm"`

Try to use system version first; fall back to SwiftPM if not found.

**When to use:**
- Library available both ways (common for C libraries)
- Want to use system version for performance/size
- Ensures compatibility if system version unavailable

**Example:**
```toml
[zstd]
source = "system_or_swiftpm"
version = "1.5.2+"
reason = "Prefer system zstd; SwiftPM fallback if unavailable"
build_env = ["macos_13+", "linux_x86_64"]
```

---

## Version Specifiers

| Specifier | Meaning | Example |
|-----------|---------|---------|
| `"native"` | System version (no choice) | Apple frameworks |
| `"X.Y.Z"` | Exact version | `"1.5.2"` |
| `"X.Y.Z+"` | At least this version | `"1.5.2+"` |
| `"X.Y.*"` | Any patch version | `"1.5.*"` |
| `"X.*"` | Any minor/patch | `"1.*"` |
| `"^X.Y.Z"` | Caret (compatible) | `"^1.5.2"` ≈ `<2.0` |
| `"~X.Y.Z"` | Tilde (patch) | `"~1.5.2"` ≈ `<1.6` |

---

## Build Environment Values

Specify where dependencies are available:

```
macos_13+           macOS 13 Ventura and later
macos_13_to_14      macOS 13 through 14 only
macos_14+           macOS 14 Sonoma and later
macos_15+           macOS 15 Sequoia and later

ios_16+             iOS 16 and later
ios_17+             iOS 17 and later

linux_x86_64        Linux on x86_64 architecture
linux_arm64         Linux on ARM64 architecture

windows_10+         Windows 10 and later
windows_11+         Windows 11 and later
```

**Example:**
```toml
[mylib]
build_env = ["macos_13+", "ios_17+", "linux_x86_64"]
```

---

## Reason Field (Best Practices)

The `reason` field should answer: **Why do we need this? What problem does it solve?**

### ❌ Bad Reasons

```toml
reason = "required"
reason = "needed for build"
reason = "performance"
```

### ✓ Good Reasons

```toml
reason = "SIMD-accelerated image convolution for real-time fingerprinting"
reason = "Unicode text normalization (NFKC) for consistent hashing across platforms"
reason = "Compression: 2-5x better ratio than Gzip for bulk media data"
```

---

## Installation Instructions

Optional: Provide installation commands for developer setup.

```toml
[icu]
source = "system_or_swiftpm"
version = "72.0+"
reason = "Unicode normalization"
build_env = ["macos_13+", "linux_x86_64"]

# Installation instructions
install_macos = "brew install icu4c"
install_linux = "sudo apt-get install libicu-dev"
install_fedora = "sudo dnf install libicu-devel"
install_windows = "choco install icu"
```

---

## Validation

After creating DEPS.toml, validate it:

```bash
./scripts/validate_build_hygiene.sh
```

Expected output:
```
✓ Build hygiene check passed!
✓ No hardcoded paths
✓ No undocumented flags
```

---

## Check List

Before committing a new DEPS.toml:

- [ ] File named exactly `DEPS.toml` in package root
- [ ] All external dependencies listed (no mystery libraries)
- [ ] `source` is one of: `system`, `swiftpm`, `system_or_swiftpm`
- [ ] `version` is valid semver or `"native"`
- [ ] `reason` explains *why* (not just *what*)
- [ ] `build_env` is specific (not vague)
- [ ] Corresponding Package.swift has `// EXTERNAL_DEP` comments
- [ ] `./scripts/validate_build_hygiene.sh` passes
- [ ] Installation instructions helpful for new developers

---

## FAQ

**Q: Do I need DEPS.toml if I only use Swift Package Manager?**

A: No, unless it's a system dependency wrapper. Pure Swift dependencies are in Package.swift.

**Q: Can I have multiple versions of the same library?**

A: No. If you need v1.5 and v2.0, use different library names or document why.

**Q: What about transitive dependencies?**

A: Only list *direct* system dependencies you actually link against. SwiftPM handles transitives.

**Q: Should I version control system frameworks?**

A: No. Mark as `source = "system"` with `version = "native"`.

---

## See Also

- [BUILD_HYGIENE.md](./BUILD_HYGIENE.md) – Linker configuration guide
- [validate_build_hygiene.sh](../../scripts/validate_build_hygiene.sh) – Validation tool
- [Package.swift Documentation](https://swift.org/package-manager/)
