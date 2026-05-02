// swift-tools-version: 5.10
// Package.swift for InferenceContracts

import PackageDescription

let package = Package(
    name: "InferenceContracts",
    products: [
        .library(
            name: "InferenceContracts",
            targets: ["InferenceContracts"]
        ),
    ],
    targets: [
        .target(
            name: "InferenceContracts",
            dependencies: [],
            path: "Sources/InferenceContracts",
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=targeted"])
            ]
        ),
        .testTarget(
            name: "InferenceContractsTests",
            dependencies: ["InferenceContracts"],
            path: "Tests/InferenceContractsTests",
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=targeted"])
            ]
        ),
    ]
)
