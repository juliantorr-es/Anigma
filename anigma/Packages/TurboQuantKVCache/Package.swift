// swift-tools-version: 5.10
// Package.swift for TurboQuantKVCache

import PackageDescription

let package = Package(
    name: "TurboQuantKVCache",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "TurboQuantKVCache",
            targets: ["TurboQuantKVCache"]
        ),
    ],
    dependencies: [
        .package(path: "../KVCacheContracts"),
        .package(path: "../InferenceContracts"),
        .package(path: "../SaturationInferenceCore"),
        .package(path: "../SaturatedModelRegistry"),
    ],
    targets: [
        .target(
            name: "TurboQuantKVCache",
            dependencies: [
                "KVCacheContracts",
                "InferenceContracts",
                "SaturationInferenceCore",
                "SaturatedModelRegistry",
            ],
            path: "Sources/TurboQuantKVCache",
            exclude: [],
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=targeted"])
            ],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("Accelerate"),
            ]
        ),
        .testTarget(
            name: "TurboQuantKVCacheTests",
            dependencies: ["TurboQuantKVCache"],
            path: "Tests/TurboQuantKVCacheTests",
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=targeted"])
            ],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("Accelerate"),
            ]
        ),
    ]
)
