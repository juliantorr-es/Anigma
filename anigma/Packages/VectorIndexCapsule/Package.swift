// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VectorIndexCapsule",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "VectorIndexCapsule",
            targets: ["VectorIndexCapsule"]),
    ],
    dependencies: [
        .package(path: "../CapsuleCore"),
        .package(path: "../AnigmaPrimitives")
    ],
    targets: [
        .target(
            name: "VectorIndexCapsule",
            dependencies: [
                .product(name: "CapsuleCore", package: "CapsuleCore"),
                .product(name: "AnigmaPrimitives", package: "AnigmaPrimitives")
            ],
            path: "Sources/VectorIndexCapsule",
            cSettings: [
                .headerSearchPath("C/include")
            ],
            cxxSettings: [
                .headerSearchPath("C/include"),
                .headerSearchPath("C/src"),
                .define("NDEBUG", .when(configuration: .release)),
                .unsafeFlags(["-O3", "-ffast-math", "-march=native"], .when(configuration: .release))
            ]
        ),
        .testTarget(
            name: "VectorIndexCapsuleTests",
            dependencies: ["VectorIndexCapsule"]),
    ],
    cxxLanguageStandard: .cxx17
)
