// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BenchmarkHarness",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "BenchmarkHarness", targets: ["BenchmarkHarness"]),
        .executable(name: "anigma-bench", targets: ["anigma-bench"])
    ],
    targets: [
        .target(
            name: "BenchmarkHarness",
            path: "Sources/BenchmarkHarness",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "BenchmarkSamples",
            dependencies: ["BenchmarkHarness"],
            path: "Sources/BenchmarkSamples",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "anigma-bench",
            dependencies: ["BenchmarkHarness", "BenchmarkSamples"],
            path: "Sources/anigma-bench",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
