# Xcode Indexing Performance Optimization Guide

## Changes Made to Package.swift

1. **Added explicit Swift language version** - Helps Xcode understand what to index
2. **Enhanced exclude lists** - Added more comprehensive exclusions for test/example directories in native targets
3. **Created .gitignore** - Excludes build artifacts and vendor libraries

## Additional Manual Steps Required

### 1. Exclude Vendor Directory from Indexing

Your `Vendor/` directory with precompiled libraries should NOT be indexed:

```bash
# Add to .gitignore if not already there
echo "Vendor/" >> .gitignore
```

**In Xcode:**
- Right-click on `Vendor/` folder in Project Navigator
- Select "Show File Inspector"
- Uncheck "Target Membership" for all targets
- Or better: don't add it to Xcode at all, keep it as a file system reference only

### 2. Create/Update .xcode-excluded-paths

Create a file at the root of your project:

```bash
cat > .xcode-excluded-paths << 'EOF'
.build
.swiftpm
Vendor
DerivedData
*.profraw
*.profdata
.build/stats
Packages/CClipper2/Clipper2/CPP/Examples
Packages/CClipper2/Clipper2/CPP/Tests
Packages/CClipper2/Clipper2/Delphi
Packages/CClipper2/Clipper2/CSharp
Packages/*/Tests
Packages/*/Examples
Packages/*/Documentation
EOF
```

### 3. Reduce Debug Performance Settings Impact

Your `debugPerformanceSettings` generate stats files that Xcode will try to index:

```swift
// Consider making this conditional on a flag
let debugPerformanceSettings: [SwiftSetting] = 
#if DEBUG_PERFORMANCE
[
    .unsafeFlags(["-Xfrontend", "-stats-output-dir", "-Xfrontend", ".build/stats"]),
    .unsafeFlags(["-Xfrontend", "-warn-long-function-bodies=100"]),
    .unsafeFlags(["-Xfrontend", "-warn-long-expression-type-checking=100"])
]
#else
[]
#endif
```

### 4. Scheme Optimization

In Xcode:
1. **Product → Scheme → Manage Schemes**
2. **Uncheck "Show" for schemes you don't actively develop**
   - Keep only: `anigma-app`, `anigma-cli`, and maybe 2-3 modules you actively work on
   - You have ~20+ executable schemes - hide most of them!

### 5. Workspace Settings

**Xcode → Settings → Locations:**
- Set "Derived Data" to a custom location outside your project
- Consider using `/tmp/XcodeDerivedData` for faster indexing on systems with fast temp storage

**Xcode → Settings → General:**
- Uncheck "Continue building after errors" - prevents cascade indexing failures
- Disable "Show live issues" temporarily during heavy refactors

### 6. Index-While-Building Settings

Add this to each target's build settings (or create an `.xcconfig` file):

```
INDEX_ENABLE_BUILD_ARENA = YES
COMPILER_INDEX_STORE_ENABLE = YES
```

### 7. Split Package Recommendation

Your package has **150+ targets**. Consider splitting into multiple packages:

```
Anigma/
├── AnigmaCore/          (Core + Database + Contracts)
├── AnigmaModules/       (All capability modules)
├── AnigmaNative/        (All native C/C++ targets)
├── AnigmaApps/          (Executables)
└── AnigmaTests/         (Test targets)
```

Each as a separate Swift Package, with the main app depending on them.

### 8. Disable Test Target Auto-Discovery

For test targets you don't run often, you can prevent Xcode from indexing them:

Add to top of test files:
```swift
// Only build when explicitly testing
#if DEBUG && canImport(Testing)
@testable import YourModule
#endif
```

### 9. Native Module Optimization

Your FFmpeg-linked targets (`MediaFingerprintNative`, `VizAggregationNative`, etc.) all have the same linker settings. Consider:

1. Creating a shared base module
2. Using a macro to generate these targets
3. Or pre-building them as XCFrameworks

### 10. File Watcher Exclusion

Create `.swift-index-exclude`:

```bash
cat > .swift-index-exclude << 'EOF'
# Vendor libraries
Vendor/**/*

# Build artifacts
.build/**/*
.swiftpm/**/*

# Large generated files
**/*.generated.swift
**/*.pb.swift
**/*.grpc.swift

# Stats output
.build/stats/**/*

# Test resources
**/TestFiles/**/*
**/TestData/**/*
EOF
```

## Immediate Impact Actions (Priority Order)

1. **Hide unused schemes** (1 minute, huge impact)
2. **Create .xcode-excluded-paths** (2 minutes, big impact)
3. **Exclude Vendor/ from targets** (1 minute, medium impact)
4. **Move DerivedData to /tmp** (1 minute, medium impact)
5. **Disable debugPerformanceSettings by default** (5 minutes, medium impact)

## Measuring Success

Before optimizations, check:
```bash
find . -name "*.swift" | wc -l    # Count Swift files
du -sh .build/                     # Build artifact size
```

After optimizations, Xcode should:
- Index in < 5 minutes for the first time
- Re-index changes in < 30 seconds
- Show fewer "Indexing..." notifications

## Nuclear Option: Pre-build Native Modules

For native targets that rarely change:

```bash
# Build as XCFramework
cd Packages/PDFNative
xcodebuild archive -scheme PDFNative ...
xcodebuild -create-xcframework ...
```

Then replace target definition with binary target:
```swift
.binaryTarget(
    name: "PDFNative",
    path: "Vendor/PDFNative.xcframework"
)
```

## Current Target Count Analysis

- **Native C/C++ targets:** 25
- **Core Swift targets:** 60
- **Module targets:** 20
- **Executable targets:** 15
- **Test targets:** 80+

**Total: ~200 targets** - This is extremely high for a single package!

Recommended target count: < 50 per package for good Xcode performance.
