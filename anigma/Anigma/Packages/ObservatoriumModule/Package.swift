// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ObservatoriumModule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "ObservatoriumModule", targets: ["ObservatoriumModule"])
    ],
    dependencies: [
        .package(path: "../AnigmaDaemonCore")
    ],
    targets: [
        .target(
            name: "ObservatoriumModule",
            dependencies: [
                "AnigmaDaemonCore"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "ObservatoriumModuleTests",
            dependencies: ["ObservatoriumModule"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
