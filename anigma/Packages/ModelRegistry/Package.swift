// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ModelRegistry",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ModelRegistry",
            targets: ["ModelRegistry"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ModelRegistry",
            dependencies: [],
            path: "Sources"
        )
    ]
)
