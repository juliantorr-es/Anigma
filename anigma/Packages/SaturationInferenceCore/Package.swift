// swift-tools-version: 5.10
// Package.swift for SaturationInferenceCore

import PackageDescription

let package = Package(
    name: "SaturationInferenceCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "SaturationInferenceCore",
            targets: ["SaturationInferenceCore"]
        ),
    ],
    dependencies: [
        .package(path: "../InferenceContracts"),
    ],
    targets: [
        .target(
            name: "SaturationInferenceCore",
            dependencies: [
                "InferenceContracts",
            ],
            path: "Sources/SaturationInferenceCore",
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
            name: "SaturationInferenceCoreTests",
            dependencies: ["SaturationInferenceCore"],
            path: "Tests/SaturationInferenceCoreTests",
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
