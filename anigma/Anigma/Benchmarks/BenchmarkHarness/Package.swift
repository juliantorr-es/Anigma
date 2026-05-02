// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BenchmarkHarness",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "BenchmarkHarness", targets: ["BenchmarkHarness"]),
        .executable(name: "anigma-bench", targets: ["anigma-bench"]),
        .executable(name: "anigma-capsule-bench", targets: ["anigma-capsule-bench"])
    ],
    dependencies: [
        .package(path: "../../..")
    ],
    targets: [
        .target(
            name: "BenchmarkHarness",
            dependencies: [
                .product(name: "CapsuleCore", package: "Anigma")
            ],
            path: "Sources/BenchmarkHarness",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "BenchmarkSamples",
            dependencies: ["BenchmarkHarness"],
            path: "Sources/BenchmarkSamples",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "VectorIndexCapsuleBenchmarks",
            dependencies: [
                "BenchmarkHarness",
                .product(name: "VectorIndexCapsule", package: "Anigma")
            ],
            path: "../../../Packages/VectorIndexCapsule/Benchmarks",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "RankFusionCapsuleBenchmarks",
            dependencies: [
                "BenchmarkHarness",
                .product(name: "RankFusionCapsule", package: "Anigma")
            ],
            path: "../../../Packages/RankFusionCapsule/Benchmarks",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "TextChunkingCapsuleBenchmarks",
            dependencies: [
                "BenchmarkHarness",
                .product(name: "TextChunkingCapsule", package: "Anigma"),
                .product(name: "TextPipelineCapsule", package: "Anigma")
            ],
            path: "../../../Packages/TextChunkingCapsule/Benchmarks",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "PDFCapsuleBenchmarks",
            dependencies: [
                "BenchmarkHarness",
                .product(name: "PDFCapsule", package: "Anigma")
            ],
            path: "../../../Packages/PDFCapsule/Benchmarks",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "LayoutEngineCapsuleBenchmarks",
            dependencies: [
                "BenchmarkHarness",
                .product(name: "LayoutEngineCapsule", package: "Anigma")
            ],
            path: "../../../Packages/LayoutEngineCapsule/Benchmarks",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "anigma-bench",
            dependencies: ["BenchmarkHarness", "BenchmarkSamples"],
            path: "Sources/anigma-bench",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "anigma-capsule-bench",
            dependencies: [
                "BenchmarkHarness",
                "VectorIndexCapsuleBenchmarks",
                "RankFusionCapsuleBenchmarks",
                "TextChunkingCapsuleBenchmarks",
                "PDFCapsuleBenchmarks",
                "LayoutEngineCapsuleBenchmarks"
            ],
            path: "Sources/anigma-capsule-bench",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
