// swift-tools-version: 6.0
// Package manifest for VizAggregationCapsule template
// Copy this template and use the generator script to replace `VizAggregationCapsule` with your capsule name

import PackageDescription

let package = Package(
    name: "VizAggregationCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "VizAggregationCapsule",
            targets: ["VizAggregationCapsule"]
        )
        // Uncomment if you need a native library:
        // .library(
        //     name: "VizAggregationCapsuleNative",
        //     targets: ["VizAggregationCapsuleNative"]
        // )
    ],
    dependencies: [
        .package(path: "../../Packages/CapsuleCore"),
        .package(path: "../../Packages/TelemetryCore")
    ],
    targets: [
        // MARK: - C++ Native Library (optional - delete if not needed)
        // Uncomment and customize if your capsule requires C++ integration:
        //
        // .target(
        //     name: "VizAggregationCapsuleNative",
        //     path: "Sources/VizAggregationCapsuleNative",
        //     sources: ["vizaggregationcapsule.cpp"],
        //     publicHeadersPath: "include",
        //     cxxSettings: [
        //         .headerSearchPath("."),
        //         .define("NDEBUG", to: "1", .when(configuration: .release))
        //     ],
        //     linkerSettings: [
        //         // EXTERNAL_DEP: Any C++ libraries required (e.g., boost, zstd)
        //         // REASON: Brief explanation of why this dependency is needed
        //         // BUILD_ENV: Platforms and architectures tested (e.g., macOS 14+, ARM64)
        //         // .linkedLibrary("foo"),  // Uncomment if needed
        //     ]
        // ),
        
        // MARK: - Swift Implementation
        .target(
            name: "VizAggregationCapsule",
            dependencies: [
                "CapsuleCore",
                "TelemetryCore"
                // "VizAggregationCapsuleNative"  // Uncomment if using native library
            ],
            path: "Sources/VizAggregationCapsule",
            swiftSettings: [
                // Phase 0 Gate: Strict concurrency compliance
                .swiftLanguageMode(.v6)
            ]
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "VizAggregationCapsuleTests",
            dependencies: ["VizAggregationCapsule"],
            path: "Tests/VizAggregationCapsuleTests",
            resources: [
                .process("Golden")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ],
    // Uncomment if using C++:
    // cxxLanguageStandard: .cxx17
)
