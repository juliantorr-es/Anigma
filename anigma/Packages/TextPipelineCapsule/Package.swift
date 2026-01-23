// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TextPipelineCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "TextPipelineCapsule",
            targets: ["TextPipelineCapsule"]
        )
    ],
    dependencies: [
        .package(path: "../AnigmaPrimitives"),
        .package(path: "../AnigmaNativeShims"),
        .package(path: "../CapsuleCore")
    ],
    targets: [
        .target(
            name: "TextPipelineCapsule",
            dependencies: [
                "AnigmaPrimitives",
                "AnigmaNativeShims",
                "CapsuleCore"
            ],
            path: "Sources/TextPipelineCapsule",
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"])
            ]
        ),
        .testTarget(
            name: "TextPipelineCapsuleTests",
            dependencies: ["TextPipelineCapsule"],
            path: "Tests/TextPipelineCapsuleTests"
        )
    ]
)