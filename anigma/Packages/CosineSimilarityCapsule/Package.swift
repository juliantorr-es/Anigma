// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CosineSimilarityCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "CosineSimilarityCapsule",
            targets: ["CosineSimilarityCapsule"]),
    ],
    dependencies: [
        .package(name: "AnigmaNativeShims", path: "../../Native/Shims"),
        .package(name: "CapsuleCore", path: "../CapsuleCore"),
        .package(name: "AnigmaPrimitives", path: "../AnigmaPrimitives"),
    ],
    targets: [
        .target(
            name: "CosineSimilarityCapsule",
            dependencies: [
                "AnigmaNativeShims",
                "CapsuleCore",
                "AnigmaPrimitives"
            ]
        ),
        .testTarget(
            name: "CosineSimilarityCapsuleTests",
            dependencies: ["CosineSimilarityCapsule"]
        ),
    ]
)
