// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnigmaGeminiBridge",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "anigma-gemini-bridge",
            targets: ["AnigmaGeminiBridge"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(path: "../AnigmaCore"),
        .package(path: "../AnigmaPrimitives")
    ],
    targets: [
        .executableTarget(
            name: "AnigmaGeminiBridge",
            dependencies: [
                "AnigmaCore",
                "AnigmaPrimitives",
                .product(name: "Hummingbird", package: "hummingbird")
            ],
            path: "Sources/AnigmaGeminiBridge"
        )
    ]
)
