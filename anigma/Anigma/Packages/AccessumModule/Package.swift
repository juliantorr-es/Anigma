// swift-tools-version: 6.0
// Package.swift for AccessumModule

import PackageDescription

let package = Package(
    name: "AccessumModule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "AccessumModule",
            targets: ["AccessumModule"]
        )
    ],
    dependencies: [
        // Add dependencies here as needed
        // .package(url: "https://github.com/example/diaplasion-module.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "AccessumModule",
            path: "Sources/AccessumModule",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "AccessumModuleTests",
            dependencies: ["AccessumModule"],
            path: "Tests/AccessumModuleTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
