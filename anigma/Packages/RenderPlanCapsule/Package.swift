// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "RenderPlanCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "RenderPlanCapsule",
            targets: ["RenderPlanCapsule"]),
    ],
    dependencies: [
        .package(name: "AnigmaNativeShims", path: "../../Native/Shims"),
        .package(name: "CapsuleCore", path: "../CapsuleCore"),
        .package(name: "AnigmaPrimitives", path: "../AnigmaPrimitives"),
        .package(name: "SceneGraphCapsule", path: "../SceneGraphCapsule")
    ],
    targets: [
        .target(
            name: "RenderPlanCapsule",
            dependencies: [
                "AnigmaNativeShims",
                "CapsuleCore",
                "AnigmaPrimitives",
                "SceneGraphCapsule"
            ]
        ),
        .testTarget(
            name: "RenderPlanCapsuleTests",
            dependencies: ["RenderPlanCapsule"]
        ),
    ]
)
