// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SyntaxCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SyntaxCapsule",
            targets: ["SyntaxCapsule"]
        ),
        .library(
            name: "SyntaxNative",
            targets: ["SyntaxNative"]
        )
    ],
    dependencies: [
        .package(path: "../CapsuleCore"),
        .package(path: "../TelemetryCore")
    ],
    targets: [
        // C++ native library for syntax highlighting
        .target(
            name: "SyntaxNative",
            path: "Sources/SyntaxNative",
            sources: ["syntax_highlighter.cpp"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("."),
                // REASON: C++17 standard required for syntax processing; exceptions disabled for performance
                // EXTERNAL_DEP: tree-sitter for multi-language parsing
                // BUILD_ENV: macOS 14+, iOS 17+
                .unsafeFlags(["-std=c++17", "-fno-exceptions"])
            ],
            linkerSettings: [
                // EXTERNAL_DEP: System C++ standard library
                // REASON: Standard C++ library functions
                // BUILD_ENV: macOS 14+, iOS 17+
                .linkedLibrary("c++")
            ]
        ),
        
        // Swift wrapper for syntax highlighting
        .target(
            name: "SyntaxCapsule",
            dependencies: ["SyntaxNative", "CapsuleCore", "TelemetryCore"],
            path: "Sources/SyntaxCapsule",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        
        // Tests
        .testTarget(
            name: "SyntaxCapsuleTests",
            dependencies: ["SyntaxCapsule"],
            path: "Tests/SyntaxCapsuleTests"
        )
    ],
    cxxLanguageStandard: .cxx17
)