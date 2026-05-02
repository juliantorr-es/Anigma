// swift-tools-version: 6.0
// Package manifest for GeometryCapsule

import PackageDescription

let package = Package(
    name: "GeometryCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "GeometryCapsule",
            targets: ["GeometryCapsule"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/CapsuleCore"),
        .package(path: "../../Packages/TelemetryCore")
    ],
    targets: [
        // MARK: - Swift Implementation
        .target(
            name: "GeometryCapsule",
            dependencies: [
                "CapsuleCore",
                "TelemetryCore"
            ],
            path: "Sources/GeometryCapsule",
            swiftSettings: [
                // Phase 0 Gate: Strict concurrency compliance
                .swiftLanguageMode(.v6)
            ]
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "GeometryCapsuleTests",
            dependencies: ["GeometryCapsule"],
            path: "Tests/GeometryCapsuleTests",
            resources: [
                .process("Golden")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
