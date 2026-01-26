// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnigmaDaemonCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AnigmaDaemonCore", targets: ["AnigmaDaemonCore"])
    ],
    targets: [
        .target(
            name: "AnigmaDaemonCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)