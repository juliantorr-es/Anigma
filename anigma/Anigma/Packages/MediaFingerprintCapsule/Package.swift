// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
    dependencies: [
        .package(path: "../CapsuleCore")
    ],
    targets: [
        // C++ native library with perceptual hashing algorithms
        .target(
            name: "MediaFingerprintNative",
            path: "Sources/MediaFingerprintNative",
            sources: ["media_fingerprint.cpp"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("."),
                .define("STBI_NO_STDIO", to: "1"),
                // REASON: C++17 standard required for perceptual hashing; exceptions disabled for performance
                // EXTERNAL_DEP: none
                // BUILD_ENV: all
                .unsafeFlags(["-std=c++17", "-fno-exceptions"])
            ],
            linkerSettings: [
                // EXTERNAL_DEP: Accelerate
                // REASON: SIMD-accelerated convolution for image processing
                // BUILD_ENV: macOS 14+, iOS 17+
                .linkedFramework("Accelerate", .when(platforms: [.macOS, .iOS]))
            ]
        ),
        
        // Swift actor wrapper
        .target(
            name: "MediaFingerprintCapsule",
            dependencies: ["MediaFingerprintNative", "CapsuleCore"],
            path: "Sources/MediaFingerprintCapsule",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        
        // Tests
        .testTarget(
            name: "MediaFingerprintCapsuleTests",
            dependencies: ["MediaFingerprintCapsule"],
            path: "Tests/MediaFingerprintCapsuleTests"
        )
    ],
    cxxLanguageStandard: .cxx17
)
