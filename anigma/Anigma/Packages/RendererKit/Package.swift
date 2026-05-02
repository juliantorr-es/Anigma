// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RendererKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "RendererKit",
            targets: ["RendererKit"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CapsuleCoreStub",
            dependencies: [],
            path: "Sources/CapsuleCoreStub",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "RendererKit",
            dependencies: ["CapsuleCoreStub"],
            path: "Sources/RendererKit",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("QuartzCore")
            ]
        ),
        .testTarget(
            name: "RendererKitTests",
            dependencies: ["RendererKit"],
            path: "Tests/RendererKitTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
