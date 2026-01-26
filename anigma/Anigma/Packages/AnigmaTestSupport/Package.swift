// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnigmaTestSupport",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "AnigmaTestSupport", targets: ["AnigmaTestSupport"])
    ],
    dependencies: [
        .package(path: "../TelemetryCore")
    ],
    targets: [
        .target(
            name: "AnigmaTestSupport",
            dependencies: ["TelemetryCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
