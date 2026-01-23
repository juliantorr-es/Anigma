// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TypographyCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "TypographyCapsule",
            targets: ["TypographyCapsule"]),
    ],
    dependencies: [
        .package(name: "AnigmaNativeShims", path: "../../Native/Shims"),
        .package(name: "CapsuleCore", path: "../CapsuleCore"),
        .package(name: "AnigmaPrimitives", path: "../AnigmaPrimitives"),
    ],
    targets: [
        .target(
            name: "TypographyCapsule",
            dependencies: [
                "AnigmaNativeShims",
                "CapsuleCore",
                "AnigmaPrimitives"
            ]
        ),
        .testTarget(
            name: "TypographyCapsuleTests",
            dependencies: ["TypographyCapsule"]
        ),
    ]
)
