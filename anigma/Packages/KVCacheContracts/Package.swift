// swift-tools-version: 5.10
// Package.swift for KVCacheContracts

import PackageDescription

let package = Package(
    name: "KVCacheContracts",
    products: [
        .library(
            name: "KVCacheContracts",
            targets: ["KVCacheContracts"]
        ),
    ],
    dependencies: [
        .package(path: "../InferenceContracts"),
    ],
    targets: [
        .target(
            name: "KVCacheContracts",
            dependencies: ["InferenceContracts"],
            path: "Sources/KVCacheContracts",
            exclude: [],
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=targeted"])
            ]
        ),
        .testTarget(
            name: "KVCacheContractsTests",
            dependencies: ["KVCacheContracts"],
            path: "Tests/KVCacheContractsTests",
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=targeted"])
            ]
        ),
    ]
)
