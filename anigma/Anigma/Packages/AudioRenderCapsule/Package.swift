// swift-tools-version: 6.0
// Package manifest for AudioRenderCapsule
// Audio processing and rendering capsule with FFmpeg integration

import PackageDescription

let package = Package(
    name: "AudioRenderCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "AudioRenderCapsule",
            targets: ["AudioRenderCapsule"]
        ),
        .library(
            name: "AudioRenderCapsuleNative",
            targets: ["AudioRenderCapsuleNative"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/CapsuleCore"),
        .package(path: "../../Packages/TelemetryCore")
    ],
    targets: [
        // MARK: - C++ Native Library
        .target(
            name: "AudioRenderCapsuleNative",
            path: "Sources/AudioRenderCapsuleNative",
            sources: ["audiorendercapsule.cpp"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("."),
                .define("NDEBUG", to: "1", .when(configuration: .release)),
                // Enable FFmpeg integration
                .define("USE_FFMPEG", to: "1")
            ],
            linkerSettings: [
                // FFmpeg libraries for audio decoding and processing
                // EXTERNAL_DEP: FFmpeg (libavformat, libavcodec, libswresample)
                // REASON: Audio decoding, format conversion, and resampling
                // BUILD_ENV: macOS 14+, ARM64/Intel64
                .linkedLibrary("avformat"),
                .linkedLibrary("avcodec"),
                .linkedLibrary("swresample"),
                .linkedLibrary("avutil"),
                .linkedLibrary("m"),
                .linkedFramework("Accelerate")
            ]
        ),
        
        // MARK: - Swift Implementation
        .target(
            name: "AudioRenderCapsule",
            dependencies: [
                "CapsuleCore",
                "TelemetryCore",
                "AudioRenderCapsuleNative"
            ],
            path: "Sources/AudioRenderCapsule",
            swiftSettings: [
                // Phase 0 Gate: Strict concurrency compliance
                .swiftLanguageMode(.v6)
            ]
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "AudioRenderCapsuleTests",
            dependencies: ["AudioRenderCapsule"],
            path: "Tests/AudioRenderCapsuleTests",
            resources: [
                .process("Golden")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ],
    cxxLanguageStandard: .cxx17
)