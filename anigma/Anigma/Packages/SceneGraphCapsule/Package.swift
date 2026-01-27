// swift-tools-version: 6.0
// Package manifest for SceneGraphCapsule
// Tier 1: 3D scene graph operations with spatial indexing and lighting

import PackageDescription

let package = Package(
    name: "SceneGraphCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SceneGraphCapsule",
            targets: ["SceneGraphCapsule"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/CapsuleCore"),
        .package(path: "../../Packages/TelemetryCore")
    ],
    targets: [
        // MARK: - Swift Implementation
        .target(
            name: "SceneGraphCapsule",
            dependencies: [
                "CapsuleCore",
                "TelemetryCore"
            ],
            path: "Sources/SceneGraphCapsule",
            swiftSettings: [
                // Phase 0 Gate: Strict concurrency compliance
                .swiftLanguageMode(.v6)
            ]
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "SceneGraphCapsuleTests",
            dependencies: ["SceneGraphCapsule"],
            path: "Tests/SceneGraphCapsuleTests",
            resources: [
                .process("Golden")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)