// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OOXMLKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "OOXMLKit", targets: ["OOXMLKit"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "OOXMLKit",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "OOXMLKitTests",
            dependencies: ["OOXMLKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
