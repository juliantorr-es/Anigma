// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CapsuleCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "CapsuleCore",
            targets: ["CapsuleCore"]
        )
    ],
    targets: [
        .target(
            name: "CapsuleCore",
            path: "Sources/CapsuleCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "CapsuleCoreTests",
            dependencies: ["CapsuleCore"],
            path: "Tests/CapsuleCoreTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
