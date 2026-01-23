// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TileCacheCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "TileCacheCapsule",
            targets: ["TileCacheCapsule"]),
    ],
    dependencies: [
        .package(name: "AnigmaNativeShims", path: "../../Native/Shims"),
        .package(name: "CapsuleCore", path: "../CapsuleCore"),
        .package(name: "AnigmaPrimitives", path: "../AnigmaPrimitives"),
    ],
    targets: [
        .target(
            name: "TileCacheCapsule",
            dependencies: [
                "AnigmaNativeShims",
                "CapsuleCore",
                "AnigmaPrimitives"
            ]
        ),
    ]
)
