// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TileCacheCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "TileCacheCapsule",
            targets: ["TileCacheCapsule"]
        )
    ],
    dependencies: [
        .package(path: "../CapsuleCore"),
        .package(path: "../VectorOpsKit")
    ],
    targets: [
        .target(
            name: "TileCacheCapsule",
            dependencies: ["CapsuleCore", "VectorOpsKit"],
            path: "Sources/TileCacheCapsule",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "TileCacheCapsuleTests",
            dependencies: ["TileCacheCapsule"],
            path: "Tests/TileCacheCapsuleTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)