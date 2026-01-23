// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SceneGraphCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SceneGraphCapsule",
            targets: ["SceneGraphCapsule"]),
    ],
    dependencies: [
        .package(name: "AnigmaNativeShims", path: "../../Native/Shims"),
        .package(name: "CapsuleCore", path: "../CapsuleCore"),
        .package(name: "AnigmaPrimitives", path: "../AnigmaPrimitives"),
    ],
    targets: [
        .target(
            name: "SceneGraphCapsule",
            dependencies: [
                "AnigmaNativeShims",
                "CapsuleCore",
                "AnigmaPrimitives"
            ]
        ),
        .testTarget(
            name: "SceneGraphCapsuleTests",
            dependencies: ["SceneGraphCapsule"]
        ),
    ]
)
