// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ImageDecodeCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ImageDecodeCapsule",
            targets: ["ImageDecodeCapsule"]),
    ],
    dependencies: [
        .package(name: "AnigmaNativeShims", path: "../../Native/Shims"),
        .package(name: "CapsuleCore", path: "../CapsuleCore"),
        .package(name: "AnigmaPrimitives", path: "../AnigmaPrimitives"),
        // May depend on MediaContainerCapsule or similar if shared codecs
    ],
    targets: [
        .target(
            name: "ImageDecodeCapsule",
            dependencies: [
                "AnigmaNativeShims",
                "CapsuleCore",
                "AnigmaPrimitives"
            ]
        ),
    ]
)
