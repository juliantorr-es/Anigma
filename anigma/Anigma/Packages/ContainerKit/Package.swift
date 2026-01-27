// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ContainerKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ContainerKit",
            targets: ["ContainerKit"]
        )
    ],
    dependencies: [
        .package(path: "../CapsuleCore"),
        .package(path: "../TelemetryCore")
    ],
    targets: [
        .target(
            name: "ContainerKit",
            dependencies: [
                "CapsuleCore",
                "TelemetryCore"
            ],
            path: "Sources/ContainerKit",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "ContainerKitTests",
            dependencies: [
                "ContainerKit",
                "TelemetryCore"
            ],
            path: "Tests/ContainerKitTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)