// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TessellationCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "TessellationCapsule",
            targets: ["TessellationCapsule"]),
    ],
    dependencies: [
        .package(name: "AnigmaNativeShims", path: "../../Native/Shims"),
        .package(name: "CapsuleCore", path: "../CapsuleCore"),
        .package(name: "AnigmaPrimitives", path: "../AnigmaPrimitives"),
        .package(name: "VectorCapsule", path: "../VectorCapsule")
    ],
    targets: [
        .target(
            name: "TessellationCapsule",
            dependencies: [
                "AnigmaNativeShims",
                "CapsuleCore",
                "AnigmaPrimitives",
                "VectorCapsule"
            ]
        ),
    ]
)
