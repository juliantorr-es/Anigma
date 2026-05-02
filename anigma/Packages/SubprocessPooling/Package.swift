// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SubprocessPooling",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SubprocessPooling",
            targets: ["SubprocessPooling"]
        )
    ],
    targets: [
        .target(
            name: "SubprocessPooling",
            dependencies: [],
            swiftSettings: [
                .unsafeFlags([
                    "-strict-concurrency=targeted",
                    "-Xfrontend", "-warn-long-function-bodies=100",
                    "-Xfrontend", "-warn-long-expression-type-checking=100"
                ])
            ]
        ),
        .testTarget(
            name: "SubprocessPoolingTests",
            dependencies: ["SubprocessPooling"],
            swiftSettings: [
                .unsafeFlags([
                    "-strict-concurrency=targeted"
                ])
            ]
        )
    ]
)
