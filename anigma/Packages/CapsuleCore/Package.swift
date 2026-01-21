// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CapsuleCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "CapsuleCore",
            targets: ["CapsuleCore"]
        )
    ],
    dependencies: [
        .package(path: "../AnigmaPrimitives"),
        .package(path: "../AnigmaNativeShims")
    ],
    targets: [
        .target(
            name: "CapsuleCore",
            dependencies: [
                "AnigmaPrimitives",
                "AnigmaNativeShims"
            ],
            path: "Sources/CapsuleCore",
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"])
            ]
        ),
        .testTarget(
            name: "CapsuleCoreTests",
            dependencies: ["CapsuleCore"],
            path: "Tests/CapsuleCoreTests"
        )
    ]
)