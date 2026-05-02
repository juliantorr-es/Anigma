# Build Systems Guide: SwiftPM & Xcode

## 1. Swift Package Manager (SwiftPM)

SwiftPM is the official tool for managing the distribution of Swift code. It allows you to create tools, libraries, and executables.

### Core Concepts
- **Package**: A collection of Swift source files and a manifest (`Package.swift`).
- **Target**: A module of code (library or executable). Targets can depend on other targets or products.
- **Product**: An artifact that the package exports (library or executable).
- **Dependency**: External packages required by your package.

### The `Package.swift` Manifest
The manifest defines the package structure.

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyProject",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MyApp", targets: ["MyApp"]),
        .library(name: "MyLib", targets: ["MyLib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "MyApp",
            dependencies: [
                "MyLib",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(name: "MyLib"),
        .testTarget(name: "MyLibTests", dependencies: ["MyLib"]),
    ]
)
```

### Essential Commands
- `swift build`: Compiles the package in debug mode.
- `swift build -c release`: Compiles optimized release binaries.
- `swift test`: Runs XCTest suites.
- `swift run [ExecutableName]`: Builds and runs an executable.
- `swift package resolve`: Resolves dependencies and generates `Package.resolved`.
- `swift package update`: Updates dependencies to the latest allowed versions.

## 2. Xcode Build System

Xcode uses a complex build system designed for Apple platforms (iOS, macOS, etc.).

### Key Terminology
- **Project (`.xcodeproj`)**: A repository for all files, resources, and settings.
- **Workspace (`.xcworkspace`)**: A container that groups multiple projects and Swift packages (often used with CocoaPods or complex setups).
- **Target**: A blueprint for building a single product (App, Framework, Unit Test Bundle).
- **Scheme**: A configuration that defines *what* to build, *how* to build it (Debug/Release), and *what* tests to run.
- **Build Configuration**: Usually "Debug" (faster, symbols) and "Release" (optimized, stripped).

### Command Line: `xcodebuild`
You can drive Xcode from the CLI using `xcodebuild`.

**Common Examples:**
```bash
# Build a specific scheme
xcodebuild -scheme "MyApp" -configuration Release build

# Run tests
xcodebuild test -scheme "MyApp" -destination 'platform=macOS'

# Clean build folder
xcodebuild clean -scheme "MyApp"
```

### SwiftPM Integration in Xcode
Modern Xcode projects integrate SwiftPM directly. You can add dependencies via **File > Add Package Dependencies...**. The package graph is managed within the project file, replacing the old `Cartfile` or `Podfile` approaches for most use cases.
