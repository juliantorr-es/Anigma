// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "RankFusionCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "RankFusionCapsule",
            targets: ["RankFusionCapsule"]),
    ],
    dependencies: [
        .package(name: "AnigmaNativeShims", path: "../../Native/Shims"),
        .package(name: "CapsuleCore", path: "../CapsuleCore"),
        .package(name: "AnigmaPrimitives", path: "../AnigmaPrimitives"),
    ],
    targets: [
        .target(
            name: "RankFusionCapsule",
            dependencies: [
                "AnigmaNativeShims",
                "CapsuleCore",
                "AnigmaPrimitives"
            ]
        ),
        .testTarget(
            name: "RankFusionCapsuleTests",
            dependencies: ["RankFusionCapsule"]
        ),
    ]
)
