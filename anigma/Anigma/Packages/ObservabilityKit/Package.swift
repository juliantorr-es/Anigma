// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ObservabilityKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ObservabilityKit", targets: ["ObservabilityKit"])
    ],
    dependencies: [
        .package(path: "../TelemetryCore")
    ],
    targets: [
        .target(
            name: "ObservabilityKit",
            dependencies: ["TelemetryCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "ObservabilityKitTests",
            dependencies: ["ObservabilityKit", "TelemetryCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
