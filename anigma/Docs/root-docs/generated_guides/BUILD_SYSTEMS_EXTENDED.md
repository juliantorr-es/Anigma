# Build Systems: Extended Reference

**Date**: February 2026
**Focus**: Swift Package Manager Plugins & Advanced Xcode Workflows

## 1. Swift Package Manager (SPM) Deep Dive

### A. Build Tool Plugins (Code Generation)
Build Tool Plugins run *during* the build. They are sandboxed and used for generating source code (ProtoBuf, GraphQL, Asset constants) before compilation.

**Directory Structure:**
```
MyPackage/
├── Package.swift
├── Plugins/
│   └── MyGenPlugin/
│       └── Plugin.swift
├── Sources/
│   └── MyTool/ (The executable code generator)
│       └── main.swift
```

**`Plugin.swift` Implementation:**
```swift
import PackagePlugin

@main
struct MyGenPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        // 1. Locate the tool executable
        let tool = try context.tool(named: "MyTool")
        
        // 2. Define input/output
        let inputPath = target.directory.appending("config.json")
        let outputPath = context.pluginWorkDirectory.appending("Generated.swift")
        
        // 3. Return the command
        return [.buildCommand(
            displayName: "Running MyTool",
            executable: tool.path,
            arguments: [inputPath, outputPath],
            inputFiles: [inputPath],
            outputFiles: [outputPath]
        )]
    }
}
```

### B. Command Plugins (Utility)
Command plugins are triggered manually (CLI or Xcode Menu). They can access the network, write to the package directory, and run arbitrary scripts (Linters, Formatters, Release scripts).

**`Plugin.swift` Implementation:**
```swift
import PackagePlugin

@main
struct FormatPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift-format")
        process.arguments = ["--in-place", "--recursive", context.package.directory.string]
        try process.run()
    }
}
```

**Usage:**
```bash
swift package plugin format-source
# or
swift package --allow-writing-to-package-directory format-source
```

### C. Advanced `Package.swift` Features
- **Conditional Dependencies**:
  ```swift
  .target(
      name: "MyCore",
      dependencies: [
          .product(name: "LogModule", package: "LogLib", condition: .when(platforms: [.linux]))
      ]
  )
  ```
- **Binary Targets (XCFrameworks)**:
  Distribute closed-source SDKs.
  ```swift
  .binaryTarget(
      name: "MySDK",
      url: "https://example.com/MySDK.xcframework.zip",
      checksum: "sha256_hash_here"
  )
  ```

## 2. Xcode Build System Advanced

### A. The `xcconfig` Architecture
Stop putting settings in the `.xcodeproj` UI. Use plain text `.xcconfig` files for version control and environment switching.

**Base.xcconfig:**
```ini
SWIFT_VERSION = 5.0
IPHONEOS_DEPLOYMENT_TARGET = 17.0
```

**Release.xcconfig:**
```ini
#include "Base.xcconfig"
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
ENABLE_NS_ASSERTIONS = NO
```

### B. Headless CI Builds with `xcodebuild`

**Clean Build with Logs:**
```bash
xcodebuild clean build 
  -scheme "MyApp" 
  -destination 'platform=macOS,arch=arm64' 
  -configuration Release 
  -derivedDataPath ./build/ 
  | xcbeautify
```

**Testing with Coverage:**
```bash
xcodebuild test 
  -scheme "MyApp" 
  -destination 'platform=iOS Simulator,name=iPhone 15' 
  -enableCodeCoverage YES 
  -resultBundlePath ./TestResults.xcresult
```
*Note: `.xcresult` bundles can be inspected later with `xcrun xcresulttool`.*

### C. Build Phases & Script Sandboxing
Since Xcode 14, run scripts are sandboxed by default (`ENABLE_USER_SCRIPT_SANDBOXING = YES`).
- **Impact**: Scripts cannot read/write arbitrary files outside input/output lists.
- **Fix**: Explicitly declare `Input Files` and `Output Files` in the Build Phase UI. This is required for incremental build optimizations (Xcode won't rerun the script if inputs haven't changed).
