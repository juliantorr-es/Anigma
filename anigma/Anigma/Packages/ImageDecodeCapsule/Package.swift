// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ImageDecodeCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ImageDecodeCapsule",
            targets: ["ImageDecodeCapsule"]
        ),
        .library(
            name: "ImageDecodeNative",
            targets: ["ImageDecodeNative"]
        )
    ],
    dependencies: [
        .package(path: "../CapsuleCore"),
        .package(path: "../TelemetryCore")
    ],
    targets: [
        // C++ native library for image decoding
        .target(
            name: "ImageDecodeNative",
            path: "Sources/ImageDecodeNative",
            sources: ["image_decode.cpp"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("."),
                // REASON: C++17 standard required for image processing; exceptions disabled for performance
                // EXTERNAL_DEP: libjpeg, libpng, libwebp
                // BUILD_ENV: macOS 14+, iOS 17+
                .unsafeFlags(["-std=c++17", "-fno-exceptions"])
            ],
            linkerSettings: [
                // EXTERNAL_DEP: ImageIO for native image codecs
                // REASON: Hardware-accelerated JPEG/PNG decoding
                // BUILD_ENV: macOS 14+, iOS 17+
                .linkedFramework("ImageIO", .when(platforms: [.macOS, .iOS]))
            ]
        ),
        
        // Swift actor wrapper
        .target(
            name: "ImageDecodeCapsule",
            dependencies: ["ImageDecodeNative", "CapsuleCore", "TelemetryCore"],
            path: "Sources/ImageDecodeCapsule",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        
        // Tests
        .testTarget(
            name: "ImageDecodeCapsuleTests",
            dependencies: ["ImageDecodeCapsule"],
            path: "Tests/ImageDecodeCapsuleTests"
        )
    ],
    cxxLanguageStandard: .cxx17
)
