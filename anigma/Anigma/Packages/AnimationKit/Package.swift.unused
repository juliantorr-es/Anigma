// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnimationKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "AnimationKit",
            targets: ["AnimationKit"]
        )
    ],
    dependencies: [
        .package(path: "../CapsuleCore"),
        .package(path: "../VectorOpsKit")
    ],
    targets: [
        .target(
            name: "AnimationKit",
            dependencies: ["CapsuleCore", "VectorOpsKit"],
            path: "Sources/AnimationKit",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "AnimationKitTests",
            dependencies: ["AnimationKit"],
            path: "Tests/AnimationKitTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)