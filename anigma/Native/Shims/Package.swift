// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnigmaNativeShims",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17), .watchOS(.v10)],
    products: [
        .library(
            name: "AnigmaNativeShims",
            type: .static,
            targets: ["AnigmaNativeShims"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AnigmaNativeShims",
            dependencies: [],
            path: ".",
            sources: [
                "src/capsule_core",
                "src/vector_capsule",
                "src/observability",
                "src/animation",
                "src/container",
                "src/xml",
                "src/typography",
                "src/render",
                "src/color",
                "src/compression",
                "src/common"
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("ANIGMA_CAPSULE_IMPLEMENTATION"),
                .unsafeFlags(["-strict-prototypes"])
            ],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("CoreFoundation")
            ]
        )
    ],
    cLanguageStandard: .c11
)