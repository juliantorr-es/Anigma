// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AnimationEvalCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "AnimationEvalCapsule",
            targets: ["AnimationEvalCapsule"]),
    ],
    dependencies: [
        .package(name: "AnigmaNativeShims", path: "../../Native/Shims"),
        .package(name: "CapsuleCore", path: "../CapsuleCore"),
        .package(name: "AnigmaPrimitives", path: "../AnigmaPrimitives"),
        .package(name: "SceneGraphCapsule", path: "../SceneGraphCapsule")
    ],
    targets: [
        .target(
            name: "AnimationEvalCapsule",
            dependencies: [
                "AnigmaNativeShims",
                "CapsuleCore",
                "AnigmaPrimitives",
                "SceneGraphCapsule"
            ]
        ),
        .testTarget(
            name: "AnimationEvalCapsuleTests",
            dependencies: ["AnimationEvalCapsule"]
        ),
    ]
)
