// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GlyphAtlasCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "GlyphAtlasCapsule",
            targets: ["GlyphAtlasCapsule"]
        ),
        .library(
            name: "GlyphAtlasNative",
            targets: ["GlyphAtlasNative"]
        )
    ],
    dependencies: [
        .package(path: "../CapsuleCore"),
        .package(path: "../TelemetryCore")
    ],
    targets: [
        // C++ native library for glyph atlas generation
        .target(
            name: "GlyphAtlasNative",
            path: "Sources/GlyphAtlasNative",
            sources: ["glyph_atlas.cpp"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("."),
                // REASON: C++17 standard required for font processing; exceptions disabled for performance
                // EXTERNAL_DEP: FreeType2
                // BUILD_ENV: macOS 14+, iOS 17+
                .unsafeFlags(["-std=c++17", "-fno-exceptions"])
            ],
            linkerSettings: [
                // EXTERNAL_DEP: CoreText for font access
                // REASON: System font APIs for glyph metrics
                // BUILD_ENV: macOS 14+, iOS 17+
                .linkedFramework("CoreText", .when(platforms: [.macOS, .iOS])),
                .linkedFramework("CoreGraphics", .when(platforms: [.macOS, .iOS]))
            ]
        ),
        
        // Swift actor wrapper
        .target(
            name: "GlyphAtlasCapsule",
            dependencies: ["GlyphAtlasNative", "CapsuleCore", "TelemetryCore"],
            path: "Sources/GlyphAtlasCapsule",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        
        // Tests
        .testTarget(
            name: "GlyphAtlasCapsuleTests",
            dependencies: ["GlyphAtlasCapsule"],
            path: "Tests/GlyphAtlasCapsuleTests"
        )
    ],
    cxxLanguageStandard: .cxx17
)
