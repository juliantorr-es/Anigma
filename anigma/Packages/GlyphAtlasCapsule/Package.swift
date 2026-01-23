// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "GlyphAtlasCapsule",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "GlyphAtlasCapsule",
            targets: ["GlyphAtlasCapsule"]),
    ],
    dependencies: [
        .package(name: "AnigmaNativeShims", path: "../../Native/Shims"),
        .package(name: "CapsuleCore", path: "../CapsuleCore"),
        .package(name: "AnigmaPrimitives", path: "../AnigmaPrimitives"),
    ],
    targets: [
        .target(
            name: "GlyphAtlasCapsule",
            dependencies: [
                "AnigmaNativeShims",
                "CapsuleCore",
                "AnigmaPrimitives"
            ]
        ),
    ]
)
