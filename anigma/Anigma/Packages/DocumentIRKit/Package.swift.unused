// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DocumentIRKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "DocumentIRKit",
            targets: ["DocumentIRKit"]
        )
    ],
    dependencies: [
        .package(path: "../CapsuleCore"),
        .package(path: "../TelemetryCore")
    ],
    targets: [
        .target(
            name: "DocumentIRKit",
            dependencies: ["CapsuleCore", "TelemetryCore"],
            path: "Sources/DocumentIRKit",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "DocumentIRKitTests",
            dependencies: ["DocumentIRKit", "TelemetryCore"],
            path: "Tests/DocumentIRKitTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
