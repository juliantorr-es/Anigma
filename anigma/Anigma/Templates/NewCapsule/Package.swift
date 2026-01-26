// swift-tools-version: 6.0
// Package manifest for NewCapsule template
// Copy this template and use the generator script to replace `NewCapsule` with your capsule name

import PackageDescription

let package = Package(
    name: "NewCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "NewCapsule",
            targets: ["NewCapsule"]
        )
        // Uncomment if you need a native library:
        // .library(
        //     name: "NewCapsuleNative",
        //     targets: ["NewCapsuleNative"]
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
        //     name: "NewCapsuleNative",
        //     path: "Sources/NewCapsuleNative",
        //     sources: ["newcapsule.cpp"],
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
            name: "NewCapsule",
            dependencies: [
                "CapsuleCore",
                "TelemetryCore"
                // "NewCapsuleNative"  // Uncomment if using native library
            ],
            path: "Sources/NewCapsule",
            swiftSettings: [
                // Phase 0 Gate: Strict concurrency compliance
                .swiftLanguageMode(.v6)
            ]
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "NewCapsuleTests",
            dependencies: ["NewCapsule"],
            path: "Tests/NewCapsuleTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ],
    // Uncomment if using C++:
    // cxxLanguageStandard: .cxx17
)
