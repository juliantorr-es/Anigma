// swift-tools-version: 5.9
import PackageDescription

// Isolated test harness for governance tests
// This package depends ONLY on core modules, NOT on HarmoniaModule
// This makes it structurally impossible for Harmonia compile errors to block tests

let package = Package(
    name: "GovernanceHarness",
    platforms: [
        .macOS(.v14)
    ],
    products: [],
    dependencies: [
        // Depend on the main package, but only pull specific products
        .package(name: "Anigma", path: "../../anigma"),
    ],
    targets: [
        .target(
            name: "TestSupport",
            dependencies: [
                .product(name: "AnigmaCore", package: "Anigma"),
                .product(name: "AnigmaGovernance", package: "Anigma"),
                .product(name: "GovernanceCore", package: "Anigma"),
                .product(name: "DatabaseCore", package: "Anigma"),
                .product(name: "AnigmaPrimitives", package: "Anigma"),
            ],
            path: "Sources/TestSupport",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .interoperabilityMode(.Cxx)
            ]
        ),
        .testTarget(
            name: "GovernanceTests",
            dependencies: [
                "TestSupport",
                .product(name: "AnigmaCore", package: "Anigma"),
                .product(name: "AnigmaGovernance", package: "Anigma"),
                .product(name: "GovernanceCore", package: "Anigma"),
                .product(name: "DatabaseCore", package: "Anigma"),
                .product(name: "ContractsCore", package: "Anigma"),
                .product(name: "AnigmaPrimitives", package: "Anigma"),
                .product(name: "SecurityEventsManager", package: "Anigma"),
                .product(name: "CapsuleCore", package: "Anigma"),
                .product(name: "VectorStoreCapsule", package: "Anigma"),
                .product(name: "HarmoniaV2Core", package: "Anigma"),
                .product(name: "HarmoniaV2Memory", package: "Anigma"),
                .product(name: "HarmoniaV2Inference", package: "Anigma"),
                .product(name: "HarmoniaV2CLIKernel", package: "Anigma"),
                .product(name: "HarmoniaV2Surface", package: "Anigma"),
                .product(name: "HarmoniaV2Contracts", package: "Anigma"),
            ],
            path: "Tests/GovernanceTests",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .interoperabilityMode(.Cxx)
            ]
        )
    ]
)
