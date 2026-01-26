// swift-tools-version: 6.0
// Deprecated wrapper package: use the repository root Package.swift.
// This manifest points to the root Sources/Packages to keep builds aligned.
import PackageDescription

let package = Package(
    name: "Anigma",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "anigmad", targets: ["anigmad"]),
        .executable(name: "AnigmaAppMac", targets: ["AnigmaAppMac"]),
        .library(name: "PlatformAdapters", targets: ["PlatformAdapters"]),
        .library(name: "RuntimeOrchestrator", targets: ["RuntimeOrchestrator"]),
        .library(name: "AnigmaUI", targets: ["AnigmaUI"])
    ],
    dependencies: [
        .package(path: "../Packages/ObservatoriumModule"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "anigmad",
            dependencies: [],
            path: "../Sources/anigmad",
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "AnigmaAppMac",
            dependencies: ["ObservatoriumModule", "PlatformAdapters", "AnigmaUI"],
            path: "../Sources/AnigmaAppMac",
            exclude: ["*.backup"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "PlatformAdapters",
            path: "../Sources/PlatformAdapters",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "RuntimeOrchestrator",
            dependencies: [], // We'll mock the capsules if needed or rely on binary/missing for now
            path: "../Sources/RuntimeOrchestrator",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "AnigmaUI",
            dependencies: ["PlatformAdapters", "RuntimeOrchestrator"],
            path: "../Sources/AnigmaUI",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
