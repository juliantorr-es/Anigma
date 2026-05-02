// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VideoRenderCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "VideoRenderCapsule",
            targets: ["VideoRenderCapsule"]
        )
    ],
    dependencies: [
        .package(path: "../CapsuleCore"),
        .package(path: "../TelemetryCore")
    ],
    targets: [
        .target(
            name: "VideoRenderCapsule",
            dependencies: ["CapsuleCore", "TelemetryCore"],
            path: "Sources/VideoRenderCapsule",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "VideoRenderCapsuleTests",
            dependencies: ["VideoRenderCapsule"],
            path: "Tests/VideoRenderCapsuleTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)