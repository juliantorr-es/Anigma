// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MarkdownCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MarkdownCapsule",
            targets: ["MarkdownCapsule"]
        ),
        .library(
            name: "MarkdownNative",
            targets: ["MarkdownNative"]
        )
    ],
    dependencies: [
        .package(path: "../CapsuleCore"),
        .package(path: "../TelemetryCore")
    ],
    targets: [
        // C native library for CommonMark parsing
        .target(
            name: "MarkdownNative",
            path: "Sources/MarkdownNative",
            sources: ["cmark.c"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("."),
                // REASON: C99 standard required for cmark; no exceptions needed
                // EXTERNAL_DEP: cmark library for CommonMark parsing
                // BUILD_ENV: macOS 14+, iOS 17+
                .unsafeFlags(["-std=c99", "-fno-exceptions"])
            ],
            linkerSettings: [
                // EXTERNAL_DEP: System C standard library
                // REASON: Standard C library functions
                // BUILD_ENV: macOS 14+, iOS 17+
                .linkedLibrary("c")
            ]
        ),
        
        // Swift wrapper for Markdown parsing
        .target(
            name: "MarkdownCapsule",
            dependencies: ["MarkdownNative", "CapsuleCore", "TelemetryCore"],
            path: "Sources/MarkdownCapsule",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        
        // Tests
        .testTarget(
            name: "MarkdownCapsuleTests",
            dependencies: ["MarkdownCapsule"],
            path: "Tests/MarkdownCapsuleTests"
        )
    ],
    cLanguageStandard: .c99
)