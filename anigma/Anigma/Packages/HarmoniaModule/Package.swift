// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HarmoniaModule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "HarmoniaModule",
            targets: ["HarmoniaModule"]
        ),
        .library(
            name: "HarmoniaModule.API",
            targets: ["HarmoniaAPI"]
        )
    ],
    dependencies: [
        .package(path: "../AccessumModule"),
        .package(path: "../ObservatoriumModule"),
        .package(path: "../CapsuleCore"),
        .package(path: "../AnigmaDaemonCore")
    ],
    targets: [
        .target(
            name: "HarmoniaModule",
            dependencies: [
                "AccessumModule",
                "ObservatoriumModule",
                "CapsuleCore",
                "AnigmaDaemonCore"
            ],
            path: "Sources/HarmoniaModule"
        ),
        .target(
            name: "HarmoniaAPI",
            dependencies: ["HarmoniaModule"],
            path: "Sources/HarmoniaAPI"
        ),
        .testTarget(
            name: "HarmoniaModuleTests",
            dependencies: ["HarmoniaModule"],
            path: "Tests"
        )
    ]
)
