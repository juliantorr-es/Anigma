// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnigmaClientKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AnigmaClientKit", targets: ["AnigmaClientKit"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AnigmaClientKit",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "AnigmaClientKitTests",
            dependencies: ["AnigmaClientKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
