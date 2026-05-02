// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VectorOpsKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "VectorOpsKit", targets: ["VectorOpsKit"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "VectorOpsKit",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "VectorOpsKitTests",
            dependencies: ["VectorOpsKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
