// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DocumentRenderKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "DocumentRenderKit",
            targets: ["DocumentRenderKit"]
        )
    ],
    dependencies: [
        .package(path: "../CapsuleCore"),
        .package(path: "../TelemetryCore"),
        .package(path: "../DocumentIRKit")
    ],
    targets: [
        .target(
            name: "DocumentRenderKit",
            dependencies: [
                "CapsuleCore",
                "TelemetryCore",
                "DocumentIRKit"
            ],
            path: "Sources/DocumentRenderKit",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "DocumentRenderKitTests",
            dependencies: [
                "DocumentRenderKit",
                "TelemetryCore"
            ],
            path: "Tests/DocumentRenderKitTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)