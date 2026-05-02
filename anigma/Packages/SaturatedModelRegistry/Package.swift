// swift-tools-version: 5.10
// Package.swift for SaturatedModelRegistry

import PackageDescription

let package = Package(
    name: "SaturatedModelRegistry",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "SaturatedModelRegistry",
            targets: ["SaturatedModelRegistry"]
        ),
    ],
    dependencies: [
        .package(path: "../InferenceContracts"),
        .package(path: "../SaturationInferenceCore"),
    ],
    targets: [
        .target(
            name: "SaturatedModelRegistry",
            dependencies: [
                "InferenceContracts",
                "SaturationInferenceCore",
            ],
            path: "Sources/SaturatedModelRegistry",
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
            name: "SaturatedModelRegistryTests",
            dependencies: ["SaturatedModelRegistry"],
            path: "Tests/SaturatedModelRegistryTests",
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
