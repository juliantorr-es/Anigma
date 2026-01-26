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
                .unsafeFlags(["-std=c++17", "-fno-exceptions"])
            ],
            linkerSettings: [
                .linkedFramework("Accelerate", .when(platforms: [.macOS, .iOS]))
            ]
        ),
        
        // Swift actor wrapper
        .target(
            name: "MediaFingerprintCapsule",
            dependencies: ["MediaFingerprintNative"],
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
