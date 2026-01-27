// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnigmaHostKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AnigmaHostKit", targets: ["AnigmaHostKit"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AnigmaHostKit",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Foundation")
            ]
        ),
        .testTarget(
            name: "AnigmaHostKitTests",
            dependencies: ["AnigmaHostKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
