// swift-tools-version: 6.0
// Package manifest for HTTPServerCapsule
// Tier 1 capsule providing HTTP server capabilities with WebSocket and SSE support

import PackageDescription

let package = Package(
    name: "HTTPServerCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "HTTPServerCapsule",
            targets: ["HTTPServerCapsule"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/CapsuleCore"),
        .package(path: "../../Packages/TelemetryCore")
    ],
    targets: [
        // MARK: - Swift Implementation
        .target(
            name: "HTTPServerCapsule",
            dependencies: [
                "CapsuleCore",
                "TelemetryCore"
            ],
            path: "Sources/HTTPServerCapsule",
            swiftSettings: [
                // Swift 6 strict concurrency compliance
                .swiftLanguageMode(.v6)
            ]
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "HTTPServerCapsuleTests",
            dependencies: ["HTTPServerCapsule"],
            path: "Tests/HTTPServerCapsuleTests",
            resources: [
                .process("Golden")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)