// swift-tools-version: 6.0
// Package manifest for VectorStoreCapsule

import PackageDescription

let package = Package(
    name: "VectorStoreCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "VectorStoreCapsule",
            targets: ["VectorStoreCapsule"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/CapsuleCore"),
        .package(path: "../../Packages/TelemetryCore")
    ],
    targets: [
        // MARK: - Swift Implementation
        .target(
            name: "VectorStoreCapsule",
            dependencies: [
                "CapsuleCore",
                "TelemetryCore"
            ],
            path: "Sources/VectorStoreCapsule",
            swiftSettings: [
                // Phase 0 Gate: Strict concurrency compliance
                .swiftLanguageMode(.v6)
            ]
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "VectorStoreCapsuleTests",
            dependencies: ["VectorStoreCapsule"],
            path: "Tests/VectorStoreCapsuleTests",
            resources: [
                .process("Golden")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
