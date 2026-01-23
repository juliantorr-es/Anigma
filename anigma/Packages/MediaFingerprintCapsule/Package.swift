// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MediaFingerprintCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MediaFingerprintCapsule",
            targets: ["MediaFingerprintCapsule"]
        )
    ],
    dependencies: [
        .package(path: "../AnigmaPrimitives"),
        .package(path: "../AnigmaNativeShims"),
        .package(path: "../CapsuleCore")
    ],
    targets: [
        .target(
            name: "MediaFingerprintCapsule",
            dependencies: [
                "AnigmaPrimitives",
                "AnigmaNativeShims",
                "CapsuleCore"
            ],
            path: "Sources/MediaFingerprintCapsule",
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"])
            ]
        ),
        .testTarget(
            name: "MediaFingerprintCapsuleTests",
            dependencies: ["MediaFingerprintCapsule"],
            path: "Tests/MediaFingerprintCapsuleTests"
        )
    ]
)