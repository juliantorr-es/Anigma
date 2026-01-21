// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnigmaTUI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AnigmaTUI", targets: ["AnigmaTUI"]),
        .executable(name: "anigma-tui-demo", targets: ["AnigmaTUIDemo"])
    ],
    targets: [
        .target(name: "AnigmaTUI"),
        .executableTarget(
            name: "AnigmaTUIDemo",
            dependencies: ["AnigmaTUI"],
            path: "Sources/AnigmaTUIDemo"
        )
    ]
)
