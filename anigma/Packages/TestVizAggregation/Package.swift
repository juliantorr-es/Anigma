// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TestVizAggregation",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17), .watchOS(.v10)],
    products: [
        .executable(
            name: "TestVizAggregation",
            targets: ["TestVizAggregation"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .target(name: "AnigmaCore", condition: .when(platforms: [.macOS])),
        .target(name: "AnigmaPrimitives", condition: .when(platforms: [.macOS])),
        .target(name: "ContractsCore", condition: .when(platforms: [.macOS])),
        .target(name: "DatabaseCore", condition: .when(platforms: [.macOS])),
        .target(name: "PolytroposModule", condition: .when(platforms: [.macOS]))
    ],
    targets: [
        .target(
            name: "TestVizAggregation",
            dependencies: [
                "ArgumentParser",
                "AnigmaCore",
                "AnigmaPrimitives",
                "ContractsCore",
                "DatabaseCore",
                "PolytroposModule"
            ],
            path: "Sources",
            linkerSettings: [
                .linkedLibrary("pdfium", .when(platforms: [.linux]))
            ]
        )
    ],
    cLanguageStandard: .c11
)