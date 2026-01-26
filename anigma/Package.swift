// swift-tools-version: 5.10
// Package.swift
import PackageDescription
import Foundation

let isCI = ProcessInfo.processInfo.environment["CI"] != nil

let strictConcurrencySettings: [SwiftSetting] = [
    .unsafeFlags(["-strict-concurrency=targeted"])
]

let debugPerformanceSettings: [SwiftSetting] = [
    .unsafeFlags(["-Xfrontend", "-stats-output-dir", "-Xfrontend", ".build/stats"]),
    .unsafeFlags(["-Xfrontend", "-warn-long-function-bodies=100"]),
    .unsafeFlags(["-Xfrontend", "-warn-long-expression-type-checking=100"])
]

let skipTestsOnCI: [Target] = isCI ? [] : [] // Logic placeholder

let coreProducts: [Product] = [
    .library(name: "AnigmaFoundation", targets: ["AnigmaFoundation"]),
    .library(name: "AnigmaCore", targets: ["AnigmaCore"]),
    .library(name: "AnigmaPrimitives", targets: ["AnigmaPrimitives"]),
    .library(name: "CapsuleCore", targets: ["CapsuleCore"]),
    .library(name: "DatabaseCore", targets: ["DatabaseCore"]),
    .library(name: "ContractsCore", targets: ["ContractsCore"]),
    .library(name: "StorageCore", targets: ["StorageCore"]),
    .library(name: "CapabilityCore", targets: ["CapabilityCore"]),
    .library(name: "DoctrineCore", targets: ["DoctrineCore"]),
    .library(name: "SecurityEventsManager", targets: ["SecurityEventsManager"]),
    .library(name: "TelemetryCore", targets: ["TelemetryCore"]),
    .library(name: "ExecutionCore", targets: ["ExecutionCore"]),
    .library(name: "InferenceCore", targets: ["InferenceCore"]),
    .library(name: "CanonicalTokenizer", targets: ["CanonicalTokenizer"]),
    .library(name: "AnigmaASTServicesCore", type: .dynamic, targets: ["AnigmaASTServicesCore"]),
    .library(name: "PlatformCore", targets: ["PlatformCore"]),
    .library(name: "AnigmaClientKit", targets: ["AnigmaClientKit"]),
    .library(name: "AnigmaHostKit", targets: ["AnigmaHostKit"]),
    .library(name: "AnigmaHostMac", targets: ["AnigmaHostMac"]),
    .library(name: "AnigmaSidecar", targets: ["AnigmaSidecar"]),
    .library(name: "AnigmaSystemSpine", targets: ["AnigmaSystemSpine"]),
    .library(name: "GoldenKit", targets: ["GoldenKit"]),
    .library(name: "DataCore", targets: ["DataCore"]),
    .library(name: "DataEngine", targets: ["DataEngine"]),
    .library(name: "RendererKit", targets: ["RendererKit"]),
    .library(name: "DataUI", targets: ["DataUI"]),
    .library(name: "AnigmaTUI", targets: ["AnigmaTUI"]),
    .library(name: "Workflows", targets: ["Workflows"]),
    .library(name: "ExportCore", targets: ["ExportCore"]),
    .library(name: "ExportUI", targets: ["ExportUI"]),
    .library(name: "AnigmaWork", targets: ["AnigmaWork"]),
    .library(name: "AnigmaCorporate", targets: ["AnigmaCorporate"]),
    .library(name: "AnigmaEducation", targets: ["AnigmaEducation"]),
    
    // Native Capability Modules
    .library(name: "DocumentIRKit", targets: ["DocumentIRKit"]),
    .library(name: "ContainerKit", targets: ["ContainerKit"]),
    .library(name: "OOXMLKit", targets: ["OOXMLKit"]),
    .library(name: "DocumentRenderKit", targets: ["DocumentRenderKit"]),
    .library(name: "TypographyKit", targets: ["TypographyKit"]),
    .library(name: "ColorKit", targets: ["ColorKit"]),
    .library(name: "VectorOpsKit", targets: ["VectorOpsKit"]),
    .library(name: "CompressionKit", targets: ["CompressionKit"]),
    .library(name: "PDFCapsule", targets: ["PDFCapsule"]),
    .library(name: "VectorStoreCapsule", targets: ["VectorStoreCapsule"]),
    .library(name: "SyntaxCapsule", targets: ["SyntaxCapsule"]),
    .library(name: "GeometryCapsule", targets: ["GeometryCapsule"]),
    .library(name: "TextChunkingCapsule", targets: ["TextChunkingCapsule"]),
    .library(name: "VizAggregationCapsule", targets: ["VizAggregationCapsule"]),
    .library(name: "MediaFingerprintCapsule", targets: ["MediaFingerprintCapsule"]),
    .library(name: "VectorCapsule", targets: ["VectorCapsule"]),
    .library(name: "TextPipelineCapsule", targets: ["TextPipelineCapsule"]),
    .library(name: "VectorIndexCapsule", targets: ["VectorIndexCapsule"]),
    .library(name: "CosineSimilarityCapsule", targets: ["CosineSimilarityCapsule"]),
    .library(name: "RankFusionCapsule", targets: ["RankFusionCapsule"]),
    .library(name: "AnimationKit", targets: ["AnimationKit"]),
    .library(name: "SceneGraphCapsule", targets: ["SceneGraphCapsule"]),
    .library(name: "RenderPlanCapsule", targets: ["RenderPlanCapsule"]),
    .library(name: "HitTestCapsule", targets: ["HitTestCapsule"]),
    .library(name: "ObservabilityKit", targets: ["ObservabilityKit"]),
    .library(name: "SidecarOfficeService", targets: ["SidecarOfficeService"]),
    .library(name: "SidecarPDFService", targets: ["SidecarPDFService"]),
    .library(name: "SidecarTranslateService", targets: ["SidecarTranslateService"]),
    .library(name: "AnigmaNativeShims", targets: ["AnigmaNativeShims"]),
    
    // Canvas Engine Modules
    .library(name: "RuntimeOrchestrator", targets: ["RuntimeOrchestrator"]),
    .library(name: "PlatformAdapters", targets: ["PlatformAdapters"]),
    .library(name: "AnigmaUI", targets: ["AnigmaUI"]),
]

let executableProducts: [Product] = [
    .executable(name: "harmonia-surface", targets: ["HarmoniaSurface"]),
    .executable(name: "doctrine", targets: ["DoctrineCLI"]),
    .executable(name: "outlineum-zine", targets: ["OutlineumZine"]),
    .executable(name: "diaplasion-pipeline", targets: ["DiaplasionPipeline"]),
    .executable(name: "accessum-flow", targets: ["AccessumFlow"]),
    .executable(name: "ml-worker", targets: ["MLWorkerExecutable"]),
    .executable(name: "anigma-ast-services", targets: ["anigma-ast-services"]),
    .executable(name: "anigma", targets: ["AnigmaCLIExecutable"]),
    .executable(name: "anigma-cli", targets: ["AnigmaCLIExecutable"]),
    .executable(name: "anigma-app", targets: ["AnigmaAppMacExecutable"]),
    .executable(name: "anigma-mcp", targets: ["AnigmaMCPExecutable"]),
    .executable(name: "anigma-gemini-bridge", targets: ["AnigmaGeminiBridge"]),
    .executable(name: "anigma-status-bar", targets: ["AnigmaStatusBar"])
]

let capabilityProducts: [Product] = [
    .library(name: "HarmoniaModule", targets: ["HarmoniaModule"]),
    .library(name: "DiaplasionModule", targets: ["DiaplasionModule"]),
    .library(name: "AccessumModule", targets: ["AccessumModule"]),
    .library(name: "OutlineumModule", targets: ["OutlineumModule"]),
    .library(name: "PragmaModule", targets: ["PragmaModule"]),
    .library(name: "ConexusModule", targets: ["ConexusModule"]),
    .library(name: "CodexModule", targets: ["CodexModule"]),
    .library(name: "TranscriptumModule", targets: ["TranscriptumModule"]),
    .library(name: "ObservatoriumModule", targets: ["ObservatoriumModule"]),
    .library(name: "PolytroposModule", targets: ["PolytroposModule"]),
    .library(name: "VectorumModule", targets: ["VectorumModule"]),
    .library(name: "PraxisCore", targets: ["PraxisCore"]),
    .library(name: "CathedralModule", targets: ["CathedralModule"]),
    .library(name: "ContextumModule", targets: ["ContextumModule"]),
    .library(name: "ArtifactStoreModule", targets: ["ArtifactStoreModule"]),
    .library(name: "DevelopumModule", targets: ["DevelopumModule"]),
    .library(name: "ModelRegistryModule", targets: ["ModelRegistryModule"]),
    .library(name: "AnigmaAgents", targets: ["AnigmaAgents"]),
    .library(name: "AnigmaAIConsole", targets: ["AnigmaAIConsole"]),
    .executable(name: "harmonia", targets: ["HarmoniaCLI"]),
    .executable(name: "anigmad", targets: ["AnigmaDaemon"]),
    .library(name: "AnigmaMCPModule", targets: ["AnigmaMCPModule"])
]

let nativeTargets: [Target] = [
    .target(name: "CHarfBuzz", path: "Packages/CHarfBuzz", publicHeadersPath: "."),
    .target(name: "CFreeType", path: "Packages/CFreeType", publicHeadersPath: "."),
    .target(
        name: "CClipper2",
        path: "Packages/CClipper2",
        exclude: ["example.c", "Package.swift"],
        sources: [
            "clipper2_wrapper.cpp",
            "Clipper2/CPP/Clipper2Lib/src/clipper.engine.cpp",
            "Clipper2/CPP/Clipper2Lib/src/clipper.offset.cpp",
            "Clipper2/CPP/Clipper2Lib/src/clipper.triangulation.cpp",
            "Clipper2/CPP/Clipper2Lib/src/clipper.rectclip.cpp",
            "Clipper2/CPP/Utils/clipper.svg.cpp",
        ],
        publicHeadersPath: ".",
        cxxSettings: [
            .headerSearchPath("Clipper2/CPP/Clipper2Lib/include"),
            .headerSearchPath("Clipper2/CPP/Utils"),
            .unsafeFlags(["-Wno-sign-conversion", "-Wno-float-conversion", "-Wno-unused-parameter"]),
        ],
        linkerSettings: [
            .unsafeFlags(["-L", "/Users/user/Developer/GitHub/Anigma_clean/anigma/Vendor/lib"])
        ]
    ),
    .target(
        name: "PDFNative",
        path: "Packages/PDFCapsule/Sources/PDFNative",
        publicHeadersPath: "include",
        cxxSettings: [
            .headerSearchPath("include"),
            .headerSearchPath("../../../../Vendor/include")
        ],
        linkerSettings: [
            .linkedLibrary("pdfium"),
            .unsafeFlags(["-L", "/Users/user/Developer/GitHub/Anigma_clean/anigma/Vendor/lib"]) 
        ]
    ),
    .target(
        name: "MarkdownNative",
        path: "Packages/MarkdownCapsule/Sources/MarkdownNative",
        publicHeadersPath: "include",
        cxxSettings: [
            .headerSearchPath("include"),
            .headerSearchPath("src")
        ]
    ),
    .target(
        name: "SyntaxNative",
        path: "Packages/SyntaxCapsule/Sources/SyntaxNative",
        publicHeadersPath: "include",
        cxxSettings: [
            .headerSearchPath("include"),
            .headerSearchPath("src")
        ]
    ),
    .target(
        name: "VectorStoreNative",
        path: "Packages/VectorStoreCapsule/Sources/VectorStoreNative",
        publicHeadersPath: "include",
        cSettings: [
            .define("SQLITE_CORE"),
            .define("SQLITE_VEC_VERSION", to: "\"0.1.7-alpha.2\""),
            .define("SQLITE_VEC_VERSION_MAJOR", to: "0"),
            .define("SQLITE_VEC_VERSION_MINOR", to: "1"),
            .define("SQLITE_VEC_VERSION_PATCH", to: "7"),
            .define("SQLITE_VEC_DATE", to: "\"2024-01-10\""),
            .define("SQLITE_VEC_SOURCE", to: "\"anigma-cli\""),
            .define("SQLITE_VEC_API", to: ""),
            .define("SQLITE_VEC_ENABLE_NEON", .when(platforms: [.macOS, .iOS, .tvOS, .watchOS])),
            .unsafeFlags(["-Wno-c23-extensions"]),
        ],
        cxxSettings: [
            .headerSearchPath("include")
        ]
    ),
    .target(
        name: "AnigmaNativeShims",
        path: "Native/Shims",
        exclude: [
            "Package.swift",
            "src/vector_capsule",
            "src/viz_aggregation_capsule",
            "src/cosine_similarity_capsule",
            "src/rank_fusion_capsule",
            "src/text_chunking_capsule",
            "src/layout_engine_capsule",
            "src/MediaFingerprintCapsule"
        ],
        sources: [
            "src/capsule_core",
            "src/kernel",
            "src/common"
        ],
        publicHeadersPath: "include",
        cSettings: [
            .headerSearchPath("../../Vendor/include"),
            .define("ANIGMA_CAPSULE_IMPLEMENTATION")
        ],
        cxxSettings: [
            .define("ANIGMA_CAPSULE_IMPLEMENTATION"),
            .unsafeFlags(["-Wno-everything"])
        ],
        swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
        linkerSettings: [
            .unsafeFlags(["-L", "/Users/user/Developer/GitHub/Anigma_clean/anigma/Vendor/lib"])
        ]
    ),
    .target(
        name: "NativeKernel",
        dependencies: ["AnigmaNativeShims"],
        path: "Native/Kernel",
        sources: ["src/kernel_context.cpp"],
        publicHeadersPath: "include",
        cxxSettings: [
            .headerSearchPath("include"),
            .headerSearchPath("../Shims/include"),
            .unsafeFlags(["-O3", "-ffast-math"]) // Performance optimizations
        ],
        linkerSettings: [
            .unsafeFlags(["-L", "/Users/user/Developer/GitHub/Anigma_clean/anigma/Vendor/lib"])
        ]
    ),
    .target(
        name: "CompressionNative",
        path: "Packages/CompressionKit/Sources/CompressionNative",
        publicHeadersPath: "include",
        cxxSettings: [
            .headerSearchPath("include"),
            .unsafeFlags(["-I/opt/homebrew/include"])
        ],
        linkerSettings: [
            .unsafeFlags(["-L/opt/homebrew/lib"]),
            .linkedLibrary("zstd")
        ]
    ),
    .target(
        name: "GeometryNative",
        path: "Packages/GeometryCapsule/Sources/GeometryNative",
        publicHeadersPath: "include",
        cxxSettings: [
            .headerSearchPath("include"),
            .headerSearchPath("src/Clipper2Lib/include"),
            .unsafeFlags(["-Wno-sign-conversion", "-Wno-float-conversion", "-Wno-unused-parameter"])
        ]
    ),
    .target(
        name: "TextChunkingNative",
        path: "Packages/TextChunkingCapsule/Sources/TextChunkingNative",
        publicHeadersPath: "include",
        cxxSettings: [ .headerSearchPath("include"), .unsafeFlags(["-I/opt/homebrew/include"]) ], linkerSettings: [ .unsafeFlags(["-L/opt/homebrew/lib"]), .linkedLibrary("avcodec"), .linkedLibrary("avformat"), .linkedLibrary("avutil"), .linkedLibrary("swscale"), .linkedLibrary("swresample") ]
    ),
    .target(
        name: "LayoutEngineNative",
        path: "Packages/LayoutEngineCapsule/Sources/LayoutEngineNative",
        publicHeadersPath: "include",
        cxxSettings: [
            .headerSearchPath("include"),
            .headerSearchPath("../../../../Vendor/include")
        ]
    ),
    .target(
        name: "VizAggregationNative",
        path: "Packages/VizAggregationCapsule/Sources/VizAggregationNative",
        publicHeadersPath: "include",
        cxxSettings: [ .headerSearchPath("include"), .unsafeFlags(["-I/opt/homebrew/include"]) ], linkerSettings: [ .unsafeFlags(["-L/opt/homebrew/lib"]), .linkedLibrary("avcodec"), .linkedLibrary("avformat"), .linkedLibrary("avutil"), .linkedLibrary("swscale"), .linkedLibrary("swresample") ]
    ),
    .target(
        name: "MediaFingerprintNative",
        path: "Packages/MediaFingerprintCapsule/Sources/MediaFingerprintNative",
        publicHeadersPath: "include",
        cxxSettings: [ .headerSearchPath("include"), .unsafeFlags(["-I/opt/homebrew/include"]) ], linkerSettings: [ .unsafeFlags(["-L/opt/homebrew/lib"]), .linkedLibrary("avcodec"), .linkedLibrary("avformat"), .linkedLibrary("avutil"), .linkedLibrary("swscale"), .linkedLibrary("swresample") ]
    ),
    .target(
        name: "MediaContainerNative",
        path: "Packages/MediaContainerCapsule/Sources/MediaContainerNative",
        publicHeadersPath: "include",
        cxxSettings: [ .headerSearchPath("include"), .unsafeFlags(["-I/opt/homebrew/include"]) ], linkerSettings: [ .unsafeFlags(["-L/opt/homebrew/lib"]), .linkedLibrary("avcodec"), .linkedLibrary("avformat"), .linkedLibrary("avutil"), .linkedLibrary("swscale"), .linkedLibrary("swresample") ]
    ),
    .target(
        name: "VectorNative",
        dependencies: ["CClipper2"],
        path: "Packages/VectorCapsule/Sources/VectorNative",
        publicHeadersPath: "include",
        cxxSettings: [
            .headerSearchPath("include"),
            .headerSearchPath("../../../CClipper2")
        ]
    ),
    .target(
        name: "TextPipelineNative",
        path: "Packages/TextPipelineCapsule/Sources/TextPipelineNative",
        publicHeadersPath: "include",
        cxxSettings: [
            .headerSearchPath("include"),
            .unsafeFlags(["-I/opt/homebrew/opt/icu4c/include"])
        ],
        linkerSettings: [
            .unsafeFlags(["-L/opt/homebrew/opt/icu4c/lib"]),
            .linkedLibrary("icuuc"),
            .linkedLibrary("icui18n")
        ]
    ),
    .target(
        name: "VectorIndexNative",
        path: "Packages/VectorIndexCapsule/Sources/VectorIndexNative",
        publicHeadersPath: "include",
        cxxSettings: [ .headerSearchPath("include"), .unsafeFlags(["-I/opt/homebrew/include"]) ], linkerSettings: [ .unsafeFlags(["-L/opt/homebrew/lib"]), .linkedLibrary("avcodec"), .linkedLibrary("avformat"), .linkedLibrary("avutil"), .linkedLibrary("swscale"), .linkedLibrary("swresample") ]
    ),
    .target(
        name: "CosineNative",
        path: "Packages/CosineSimilarityCapsule/Sources/CosineNative",
        publicHeadersPath: "include",
        cxxSettings: [ .headerSearchPath("include"), .unsafeFlags(["-I/opt/homebrew/include"]) ], linkerSettings: [ .unsafeFlags(["-L/opt/homebrew/lib"]), .linkedLibrary("avcodec"), .linkedLibrary("avformat"), .linkedLibrary("avutil"), .linkedLibrary("swscale"), .linkedLibrary("swresample") ]
    ),
    .target(
        name: "RankFusionNative",
        path: "Packages/RankFusionCapsule/Sources/RankFusionNative",
        publicHeadersPath: "include",
        cxxSettings: [ .headerSearchPath("include"), .unsafeFlags(["-I/opt/homebrew/include"]) ], linkerSettings: [ .unsafeFlags(["-L/opt/homebrew/lib"]), .linkedLibrary("avcodec"), .linkedLibrary("avformat"), .linkedLibrary("avutil"), .linkedLibrary("swscale"), .linkedLibrary("swresample") ]
    ),
    .target(
        name: "SceneGraphNative",
        path: "Packages/SceneGraphCapsule/Sources/SceneGraphNative",
        publicHeadersPath: "include",
        cxxSettings: [ .headerSearchPath("include"), .unsafeFlags(["-I/opt/homebrew/include"]) ], linkerSettings: [ .unsafeFlags(["-L/opt/homebrew/lib"]), .linkedLibrary("avcodec"), .linkedLibrary("avformat"), .linkedLibrary("avutil"), .linkedLibrary("swscale"), .linkedLibrary("swresample") ]
    ),
    .target(
        name: "RenderPlanNative",
        path: "Packages/RenderPlanCapsule/Sources/RenderPlanNative",
        publicHeadersPath: "include",
        cxxSettings: [
            .headerSearchPath("include"),
            .headerSearchPath("../../../SceneGraphCapsule/Sources/SceneGraphNative/include")
        ]
    ),
    .target(
        name: "HitTestNative",
        dependencies: ["SceneGraphNative"],
        path: "Packages/HitTestCapsule/Sources/HitTestNative",
        publicHeadersPath: "include",
        cxxSettings: [
            .headerSearchPath("include"),
            .headerSearchPath("../../../SceneGraphCapsule/Sources/SceneGraphNative/include")
        ]
    ),
    .target(
        name: "AnimationNative",
        path: "Packages/AnimationKit/Sources/AnimationNative",
        publicHeadersPath: "include",
        cxxSettings: [ .headerSearchPath("include"), .unsafeFlags(["-I/opt/homebrew/include"]) ], linkerSettings: [ .unsafeFlags(["-L/opt/homebrew/lib"]), .linkedLibrary("avcodec"), .linkedLibrary("avformat"), .linkedLibrary("avutil"), .linkedLibrary("swscale"), .linkedLibrary("swresample") ]
    )
]

let coreTargets: [Target] = [
    .target(name: "PDFCapsule", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "PDFNative"], path: "Packages/PDFCapsule/Sources/PDFCapsule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "MarkdownCapsule", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "MarkdownNative"], path: "Packages/MarkdownCapsule/Sources/MarkdownCapsule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "SyntaxCapsule", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "SyntaxNative"], path: "Packages/SyntaxCapsule/Sources/SyntaxCapsule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "VectorStoreCapsule", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "VectorStoreNative"], path: "Packages/VectorStoreCapsule/Sources/VectorStoreCapsule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaFoundation", path: "Packages/AnigmaFoundation/Sources/AnigmaFoundation", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)] + debugPerformanceSettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaCore",
            dependencies: ["AnigmaFoundation", "AnigmaPrimitives", "ContractsCore", "DatabaseCore", "StorageCore", "InferenceCore", "GovernanceCore", "SecurityEventsManager", "TextChunkingCapsule", "LayoutEngineCapsule", "TelemetryCore", "NativeKernel", "AnigmaNativeShims", .product(name: "Toml", package: "swift-toml"), .product(name: "Crypto", package: "swift-crypto")], path: "Packages/AnigmaCore/Sources/AnigmaCore", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaPrimitives", dependencies: [.product(name: "Crypto", package: "swift-crypto")], path: "Packages/AnigmaPrimitives", exclude: ["README.md", "ToolContracts/ToolContracts/README.md"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "DatabaseCore", dependencies: ["ContractsCore", "VectorStoreCapsule", .product(name: "GRDB", package: "GRDB.swift")], path: "Packages/DatabaseCore", exclude: ["README.md", "Schema_Master.sql", "Schema_Evidence.sql", "Schema_BuildDiagnostics.sql", "Schema_CourtSafe.sql", "Schema_DocumentUnits.sql", "Schema_EvidenceBundle.sql"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "ContractsCore", dependencies: ["AnigmaPrimitives", .product(name: "ArgumentParser", package: "swift-argument-parser")], path: "Packages/ContractsCore", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "ModelRegistry", dependencies: ["ContractsCore"], path: "Packages/ModelRegistry/Sources", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "CapabilityCore", dependencies: ["AnigmaPrimitives", "AnigmaCore"], path: "Packages/CapabilityCore", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "DoctrineCore", dependencies: [], path: "Packages/DoctrineCore", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "TelemetryCore", dependencies: ["AnigmaPrimitives"], path: "Packages/TelemetryCore", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "ExecutionCore", dependencies: ["TelemetryCore", "AnigmaPrimitives", "MLWorkerCommon"], path: "Packages/ExecutionCore", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "InferenceCore", dependencies: [], path: "Packages/InferenceCore", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "CanonicalTokenizer", dependencies: ["ContractsCore", .product(name: "Crypto", package: "swift-crypto"), .product(name: "Numerics", package: "swift-numerics")], path: "Packages/CanonicalTokenizer", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "GovernanceCore", dependencies: ["AnigmaPrimitives", "DatabaseCore", "ContractsCore", .product(name: "Toml", package: "swift-toml")], path: "Packages/GovernanceCore", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "StorageCore", dependencies: ["DatabaseCore", "GovernanceCore"], path: "Packages/StorageCore", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "GovernedMigrationCore", dependencies: ["DoctrineCore", "SecurityEventsManager", "DatabaseCore"], path: "Packages/GovernedMigrationCore", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaASTServicesCore", dependencies: ["AnigmaPrimitives", .product(name: "SwiftSyntax", package: "swift-syntax"), .product(name: "SwiftParser", package: "swift-syntax")], path: "Packages/AnigmaASTServices", exclude: ["main.swift"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "SecurityEventsManager", dependencies: [], path: "Packages/SecurityEventsManager", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaClientKit", dependencies: ["ContractsCore"], path: "Packages/AnigmaClientKit", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaSidecar", dependencies: ["AnigmaPrimitives", .product(name: "AsyncHTTPClient", package: "async-http-client")], path: "Packages/AnigmaSidecar", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaSystemSpine", dependencies: [], path: "Packages/AnigmaSystemSpine", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "DataCore", dependencies: ["AnigmaPrimitives"], path: "Packages/DataCore", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "DataEngine", dependencies: ["DataCore", "AnigmaPrimitives", "AnigmaSystemSpine"], path: "Packages/DataEngine", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "RendererKit", dependencies: ["DataCore"], path: "Packages/RendererKit", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "DataUI", dependencies: ["DataCore", "DataEngine", "RendererKit", "AnigmaClientKit"], path: "Packages/DataUI", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaTUI", dependencies: [], path: "Packages/AnigmaTUI/Sources/AnigmaTUI", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "Workflows", dependencies: ["DataCore", "DataEngine", "AnigmaSystemSpine"], path: "Packages/Workflows", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "ExportCore", dependencies: ["AnigmaSystemSpine", "DataCore"], path: "Packages/ExportCore", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "ExportUI", dependencies: ["ExportCore", "AnigmaSystemSpine", "DataCore"], path: "Packages/ExportUI", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaWork", dependencies: ["AnigmaCore", "DataCore", "DataEngine", "AnigmaSystemSpine", "ExportCore", "RendererKit"], path: "Packages/AnigmaWork", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaCorporate", dependencies: ["AnigmaCore", "HarmoniaModule", "AnigmaSystemSpine"], path: "Packages/AnigmaCorporate", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaEducation", dependencies: ["AnigmaCore", "AnigmaSystemSpine"], path: "Packages/AnigmaEducation", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaAgents", dependencies: ["AnigmaCore", "AnigmaSystemSpine", "DataCore", "DataEngine", "AnigmaCorporate", "AnigmaEducation", "HarmoniaModule", "PraxisCore"], path: "Packages/AnigmaAgents", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaAIConsole", dependencies: ["AnigmaCore", "AnigmaSystemSpine", "AnigmaAgents", "DataCore"], path: "Packages/AnigmaAIConsole", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "DocumentIRKit", dependencies: [], path: "Packages/DocumentIRKit", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "ContainerKit", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives"], path: "Packages/ContainerKit", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "OOXMLKit", dependencies: ["ContainerKit", "AnigmaNativeShims", "AnigmaPrimitives"], path: "Packages/OOXMLKit", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "DocumentRenderKit", dependencies: ["DataCore", "AnigmaNativeShims", "AnigmaPrimitives"], path: "Packages/DocumentRenderKit", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "TypographyKit", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives"], path: "Packages/TypographyKit", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "ColorKit", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives"], path: "Packages/ColorKit", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "VectorOpsKit", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "VectorNative"], path: "Packages/VectorOpsKit", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "CapsuleCore", dependencies: ["AnigmaPrimitives", "AnigmaNativeShims"], path: "Packages/CapsuleCore/Sources/CapsuleCore", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "CompressionKit", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "CompressionNative"], path: "Packages/CompressionKit/Sources/CompressionKit", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "GeometryCapsule", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "GeometryNative"], path: "Packages/GeometryCapsule/Sources/GeometryCapsule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "TextChunkingCapsule", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "TextChunkingNative", "TelemetryCore"], path: "Packages/TextChunkingCapsule/Sources/TextChunkingCapsule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "LayoutEngineCapsule", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "LayoutEngineNative", "PDFNative"], path: "Packages/LayoutEngineCapsule/Sources/LayoutEngineCapsule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "VizAggregationCapsule", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "VizAggregationNative"], path: "Packages/VizAggregationCapsule/Sources/VizAggregationCapsule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "MediaFingerprintCapsule", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "MediaFingerprintNative", "TelemetryCore"], path: "Packages/MediaFingerprintCapsule/Sources/MediaFingerprintCapsule", swiftSettings: [.unsafeFlags(["-strict-concurrency=minimal"]), .interoperabilityMode(.Cxx)]),
    .target(name: "MediaContainerCapsule", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "MediaContainerNative"], path: "Packages/MediaContainerCapsule/Sources/MediaContainerCapsule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "VectorCapsule", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "VectorNative"], path: "Packages/VectorCapsule/Sources/VectorCapsule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "TextPipelineCapsule", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "TextPipelineNative", "TelemetryCore"], path: "Packages/TextPipelineCapsule/Sources/TextPipelineCapsule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "VectorIndexCapsule", dependencies: ["AnigmaPrimitives", "CapsuleCore", "VectorIndexNative", "TelemetryCore"], path: "Packages/VectorIndexCapsule/Sources/VectorIndexCapsule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "CosineSimilarityCapsule", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "CosineNative"], path: "Packages/CosineSimilarityCapsule/Sources/CosineSimilarityCapsule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "RankFusionCapsule", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "RankFusionNative"], path: "Packages/RankFusionCapsule/Sources/RankFusionCapsule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "SceneGraphCapsule", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "SceneGraphNative"], path: "Packages/SceneGraphCapsule/Sources/SceneGraphCapsule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "RenderPlanCapsule", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "SceneGraphCapsule", "RenderPlanNative"], path: "Packages/RenderPlanCapsule/Sources/RenderPlanCapsule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "HitTestCapsule", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "SceneGraphCapsule", "HitTestNative"], path: "Packages/HitTestCapsule/Sources/HitTestCapsule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnimationKit", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "AnimationNative"], path: "Packages/AnimationKit/Sources/AnimationKit", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "ObservabilityKit", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives"], path: "Packages/ObservabilityKit", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "SidecarOfficeService", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives"], path: "Packages/SidecarOfficeService", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "SidecarPDFService", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives"], path: "Packages/SidecarPDFService", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "SidecarTranslateService", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives"], path: "Packages/SidecarTranslateService", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaHostKit", dependencies: ["AnigmaClientKit", "AnigmaCore", "AnigmaPrimitives", "ContractsCore", "AnigmaDaemonCore", "AnigmaSidecar"], path: "Packages/AnigmaHostKit", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaHostMac", dependencies: ["AnigmaClientKit", "AnigmaHostKit", "ContractsCore", "AnigmaSidecar", "AnigmaDaemonCore", .product(name: "GRDB", package: "GRDB.swift"), .product(name: "Crypto", package: "swift-crypto"), "SyntaxCapsule", "MarkdownCapsule"], path: "Packages/AnigmaHostMac", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "MLWorkerCommon", dependencies: ["ContractsCore", .product(name: "ArgumentParser", package: "swift-argument-parser"), .product(name: "MLXLMCommon", package: "mlx-swift-lm"), .product(name: "MLXEmbedders", package: "mlx-swift-lm")], path: "Packages/MLWorkerCommon", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "TechDebtAudit", dependencies: [], path: "Packages/TechDebtAudit", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "PlatformCore", dependencies: ["AnigmaCore", "CapabilityCore", "ContractsCore"], path: "Packages/PlatformCore", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaDaemonCore", dependencies: ["AnigmaCore", "DatabaseCore", "ExecutionCore", "GovernanceCore", "StorageCore", "TelemetryCore", "ContractsCore", "MLWorkerCommon", "AnigmaPrimitives", "AnigmaMCPModule", "AnigmaASTServicesCore", "TextChunkingCapsule", "LayoutEngineCapsule", "VectorCapsule", "CompressionKit", "RLMModule", "VectorIndexCapsule", "ContextumModule", "InferenceCore", "SyntaxCapsule", "MarkdownCapsule", "TechDebtAudit", "DiaplasionModule", "OutlineumModule", "HarmoniaModule", "CathedralModule", "ModelRegistry", "ModelRegistryModule", "VectorumModule", "DataEngine", "ExportCore", "AnigmaAgents", "AnigmaSystemSpine", .product(name: "Hummingbird", package: "hummingbird"), .product(name: "HummingbirdTLS", package: "hummingbird")], path: "Packages/AnigmaDaemonCore", exclude: ["README.md", "Protos/anigma.proto", "JobKinds/README.md"], swiftSettings: [.unsafeFlags(["-strict-concurrency=minimal"]), .interoperabilityMode(.Cxx)]),
    .target(
        name: "RuntimeOrchestrator",
        dependencies: ["AnigmaNativeShims", "NativeKernel", "SceneGraphCapsule", "RenderPlanCapsule"],
        path: "Sources/RuntimeOrchestrator",
        swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)] + debugPerformanceSettings
    ),
    .target(
        name: "PlatformAdapters",
        dependencies: ["RuntimeOrchestrator", "AnigmaNativeShims"],
        path: "Sources/PlatformAdapters",
        swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)] + debugPerformanceSettings
    ),
    .target(
        name: "AnigmaUI",
        dependencies: ["PlatformAdapters", "RuntimeOrchestrator"],
        path: "Sources/AnigmaUI",
        swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)] + debugPerformanceSettings,
        linkerSettings: [
            .linkedFramework("SwiftUI"),
            .linkedFramework("CoreAudio")
        ]
    ),
    .target(name: "GoldenKit", path: "Packages/AnigmaTestSupport/Sources/GoldenKit", swiftSettings: strictConcurrencySettings),
    .target(name: "AnigmaTestSupport", dependencies: ["GoldenKit", "AnigmaCore", "AnigmaPrimitives", "ContractsCore", "DatabaseCore", "PolytroposModule"], path: "Packages/AnigmaTestSupport", exclude: ["Sources/GoldenKit"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaCLICore", dependencies: ["ContractsCore", "AnigmaCore"], path: "Packages/AnigmaCLI/Core", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaCLIEventing", dependencies: ["AnigmaCLICore"], path: "Packages/AnigmaCLI/Eventing", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaCLIProviders", dependencies: ["AnigmaCLICore", "AnigmaCLIDatabase", "ContractsCore"], path: "Packages/AnigmaCLI/Providers", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaCLIRouter", dependencies: ["AnigmaCLICore", "AnigmaCLIProviders"], path: "Packages/AnigmaCLI/Router", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaCLIGovernance", dependencies: ["AnigmaCLICore", "AnigmaCLIProviders"], path: "Packages/AnigmaCLI/Governance", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaCLIOrchestrator", dependencies: ["AnigmaCLICore", "AnigmaCLIEventing", "AnigmaCLIGovernance", "AnigmaCLIProviders", "AnigmaCLIRouter"], path: "Packages/AnigmaCLI/Orchestrator", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaCLIOnboarding", dependencies: ["AnigmaCLICore", "AnigmaCLIDatabase", "AnigmaCLIProviders", "AnigmaCLIML", "DatabaseCore", "ModelManagement", .product(name: "GRDB", package: "GRDB.swift")], path: "Packages/AnigmaCLI/Onboarding", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaCLIDatabase", dependencies: ["VectorStoreCapsule", "AnigmaCLICore", "TextChunkingCapsule", .product(name: "Crypto", package: "swift-crypto")], path: "Packages/AnigmaCLI/Database", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaCLIRAG", dependencies: ["VectorStoreCapsule", "TextChunkingCapsule"], path: "Packages/AnigmaCLI/RAG", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaCLIML", dependencies: ["AnigmaCLICore", "AnigmaCLIDatabase", "AnigmaCLIMLIntegration", "AnigmaCLIProviders", "AnigmaCLILocalInference", "AnigmaCLIRAG"], path: "Packages/AnigmaCLI/ML", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaCLIUI", dependencies: [], path: "Packages/AnigmaCLI/UI", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaCLITUI", dependencies: ["AnigmaCLICore", "AnigmaCLIEventing", "AnigmaCLIDatabase", "AnigmaCLIML", "HarmoniaModule", "AnigmaTUI", "AnigmaSidecar"], path: "Packages/AnigmaCLI/Sources/TUI", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaCLIMLIntegration", dependencies: [], path: "Packages/AnigmaCLI/MLIntegration", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaCLIMCP", dependencies: ["AnigmaCLICore", "AnigmaPrimitives", "ContractsCore", "AnigmaCLIEventing", "AnigmaCLIGovernance"], path: "Packages/AnigmaCLIMCP", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "RLMModule", dependencies: ["AnigmaCore", "AnigmaPrimitives", "DatabaseCore", "ContextumModule", "ArtifactStoreModule", "HarmoniaModule", "VectorIndexCapsule", "TextPipelineCapsule", "TextChunkingCapsule", "LayoutEngineCapsule", "CapsuleCore", "InferenceCore", "MediaFingerprintCapsule"], path: "Sources/RLMModule", swiftSettings: [.unsafeFlags(["-strict-concurrency=minimal"]), .interoperabilityMode(.Cxx)]),
    .target(name: "ModelManagement", dependencies: ["AnigmaCore", "AnigmaSidecar", .product(name: "Crypto", package: "swift-crypto")], path: "Packages/AnigmaCLI/Sources/ModelManagement", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "AnigmaCLILocalInference", dependencies: ["InferenceCore", .product(name: "MLX", package: "mlx-swift"), .product(name: "MLXNN", package: "mlx-swift"), .product(name: "MLXRandom", package: "mlx-swift"), .product(name: "MLXOptimizers", package: "mlx-swift"), .product(name: "MLXLMCommon", package: "mlx-swift-lm")], path: "Packages/AnigmaCLI/Sources/LocalInference", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "PraxisCore", dependencies: [], path: "Packages/PraxisCore", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "PraxisModule", dependencies: ["PraxisCore", "ContractsCore"], path: "Packages/PraxisModule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)])
]

let moduleTargets: [Target] = [
    .target(name: "HarmoniaModule", dependencies: ["AnigmaCore", "ContractsCore", "AnigmaPrimitives", "CapabilityCore", "DatabaseCore", "TelemetryCore", "ExecutionCore", "DoctrineCore", "SecurityEventsManager", "AnigmaASTServicesCore", "MLWorkerCommon", .product(name: "MLXEmbedders", package: "mlx-swift-lm"), "CathedralModule", "StorageCore", "GovernedMigrationCore", "AnigmaCLIProviders", "AnigmaCLIRouter", "AnigmaCLIOrchestrator", "AnigmaCLIEventing", "AnigmaCLIGovernance", .product(name: "GRDB", package: "GRDB.swift"), "DataCore", "InferenceCore"], path: "Packages/HarmoniaModule", exclude: ["README.md", "Config"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "HarmoniaMemory", dependencies: ["AnigmaCore", "TelemetryCore", .product(name: "GRDB", package: "GRDB.swift")], path: "Packages/HarmoniaMemory", exclude: ["README.md"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "DiaplasionModule", dependencies: ["AnigmaCore", "TextChunkingCapsule"], path: "Packages/DiaplasionModule", exclude: ["README.md", "TestFiles"], 
        swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
        linkerSettings: [
            .linkedFramework("CoreAudio")
        ]),
    .target(name: "AccessumModule", dependencies: ["AnigmaCore", "ContractsCore", "TelemetryCore"], path: "Packages/AccessumModule/Sources/AccessumModule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "OutlineumModule", dependencies: ["AnigmaCore"], path: "Packages/OutlineumModule", exclude: ["README.md", "TestFiles"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "PragmaModule", dependencies: ["AnigmaCore", "AnigmaPrimitives", "ContractsCore"], path: "Packages/PragmaModule/Sources/PragmaModule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "ConexusModule", dependencies: ["AnigmaCore"], path: "Packages/ConexusModule/Sources/ConexusModule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "CodexModule", dependencies: ["AnigmaCore"], path: "Packages/CodexModule/Sources/CodexModule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "TranscriptumModule", dependencies: ["AnigmaCore"], path: "Packages/TranscriptumModule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "ObservatoriumModule", dependencies: ["AnigmaCore", "TelemetryCore"], path: "Packages/ObservatoriumModule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "PolytroposModule", dependencies: ["AnigmaCore", "AnigmaPrimitives", "MediaContainerCapsule", "ArtifactStoreModule", "MediaFingerprintCapsule", "DatabaseCore"], path: "Packages/PolytroposModule/Sources/PolytroposModule", swiftSettings: [.unsafeFlags(["-strict-concurrency=minimal"]), .interoperabilityMode(.Cxx)]),
    .target(name: "VectorumModule", dependencies: ["ContractsCore", "AnigmaCore", "CapabilityCore"], path: "Packages/VectorumModule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "CathedralModule", dependencies: ["AnigmaCore", "DatabaseCore", "ContextumModule"], path: "Packages/CathedralModule", exclude: ["CathedralModule.placeholder.swift.backup"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "ContextumModule", dependencies: ["AnigmaCore", "DatabaseCore", "ContractsCore", "CapsuleCore", "TextChunkingCapsule", "CompressionKit", "VizAggregationCapsule", "MediaFingerprintCapsule", "VectorCapsule", "TextPipelineCapsule"], path: "Sources/ContextumModule", swiftSettings: [.unsafeFlags(["-strict-concurrency=minimal"]), .interoperabilityMode(.Cxx)]),
    .target(name: "ArtifactStoreModule", dependencies: ["AnigmaCore", "ContractsCore", "DatabaseCore"], path: "Sources/ArtifactStoreModule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "DevelopumModule", dependencies: ["AnigmaCore", "DatabaseCore", "ContractsCore", "TelemetryCore", "ExecutionCore", "TextChunkingCapsule", "AnigmaSidecar", "AnigmaASTServicesCore", .product(name: "GRDB", package: "GRDB.swift")], path: "Packages/DevelopumModule", exclude: ["README.md"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(name: "ModelRegistryModule", dependencies: ["AnigmaCore", "ContractsCore", "DatabaseCore"], path: "Sources/ModelRegistryModule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .target(
        name: "AnigmaMCPModule",
        dependencies: [
            "AnigmaCore",
            "AnigmaPrimitives",
            "ContractsCore",
            "HarmoniaModule",
            "AccessumModule",
            "DiaplasionModule",
            "OutlineumModule",
            "PolytroposModule",
            "ContextumModule",
            "ArtifactStoreModule",
            "ModelRegistryModule",
            "MLWorkerCommon",
            "ModelRegistry",
            "ObservatoriumModule",
            "CathedralModule",
            "DatabaseCore",
            .product(name: "MCP", package: "swift-sdk")
        ],
        path: "Sources/AnigmaMCPModule",
        swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
    ),
    .target(
        name: "AnigmaMCPExecutable",
        dependencies: [
            "AnigmaSidecar"
        ],
        path: "Sources/AnigmaMCPExecutable",
        swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
    )
]

let executableTargets: [Target] = [
    .executableTarget(name: "anigma-ast-services", dependencies: ["AnigmaASTServicesCore", "AnigmaSidecar", "AnigmaPrimitives", .product(name: "SwiftSyntax", package: "swift-syntax"), .product(name: "SwiftParser", package: "swift-syntax"), .product(name: "ArgumentParser", package: "swift-argument-parser")], path: "Packages/AnigmaASTServicesCLI", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .executableTarget(name: "HarmoniaSurface", dependencies: ["AnigmaCore", "MLWorkerCommon", .product(name: "MLXLMCommon", package: "mlx-swift-lm"), .product(name: "MLXEmbedders", package: "mlx-swift-lm"), .product(name: "ArgumentParser", package: "swift-argument-parser")], path: "Packages/HarmoniaSurface", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .executableTarget(name: "DoctrineCLI", dependencies: ["HarmoniaModule", .product(name: "ArgumentParser", package: "swift-argument-parser")], path: "Packages/DoctrineCLI", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .executableTarget(name: "OutlineumZine", dependencies: ["AnigmaCore", "OutlineumModule", .product(name: "ArgumentParser", package: "swift-argument-parser")], path: "Packages/OutlineumZine", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .executableTarget(name: "DiaplasionPipeline", dependencies: ["AnigmaCore", "DiaplasionModule", "ContractsCore", .product(name: "ArgumentParser", package: "swift-argument-parser")], path: "Packages/DiaplasionPipeline", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .executableTarget(name: "AccessumFlow", dependencies: ["AnigmaCore", "DatabaseCore", "DiaplasionModule", "OutlineumModule", "HarmoniaModule", "MLWorkerCommon", .product(name: "ArgumentParser", package: "swift-argument-parser")], path: "Packages/AccessumFlow", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .executableTarget(name: "MLWorkerExecutable", dependencies: ["MLWorkerCommon", "ContractsCore", "AnigmaCore", "AnigmaPrimitives", .product(name: "MLXLMCommon", package: "mlx-swift-lm"), .product(name: "MLXEmbedders", package: "mlx-swift-lm"), .product(name: "ArgumentParser", package: "swift-argument-parser")], path: "Packages/MLWorkerExecutable", exclude: ["README.md", "Model/embedding-model.txt"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .executableTarget(name: "AnigmaAppMacExecutable", dependencies: ["AnigmaClientKit", "AnigmaHostMac", "AnigmaSystemSpine", "HarmoniaModule", "OutlineumModule", "DataUI", "AnigmaAgents", "AnigmaAIConsole", "ExportCore", "ExportUI", "AnigmaWork", "DataEngine", "ContractsCore", "DevelopumModule", "AnigmaCore", "DatabaseCore", "StorageCore"], path: "Sources/AnigmaAppMac", exclude: ["AppStore.swift.backup", "AppStore.swift.bak2"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .executableTarget(name: "AnigmaGeminiBridge", dependencies: ["AnigmaCore", "AnigmaPrimitives", .product(name: "Hummingbird", package: "hummingbird")], path: "Packages/AnigmaGeminiBridge/Sources/AnigmaGeminiBridge", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .executableTarget(name: "HarmoniaCLI", dependencies: ["AnigmaCLICore", "AnigmaCLIEventing", "AnigmaCLIGovernance", "AnigmaCLIOrchestrator", "AnigmaCLIProviders", "AnigmaCLIRouter", "AnigmaCore", "ContractsCore", "HarmoniaModule", "PraxisModule", "PraxisCore", "MLWorkerCommon", "HarmoniaMemory", "TechDebtAudit", "ExecutionCore", "StorageCore", "AnigmaDaemonCore", .product(name: "ArgumentParser", package: "swift-argument-parser")], path: "Packages/HarmoniaCLI", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .executableTarget(
        name: "AnigmaCLIExecutable",
        dependencies: [
            "AnigmaCLICore",
            "AnigmaCLIEventing",
            "AnigmaCLIOrchestrator",
            "AnigmaCLIProviders",
            "AnigmaCLIMCP",
            "AnigmaCLIRouter",
            "AnigmaCLIGovernance",
            "AnigmaCLIOnboarding",
            "AnigmaCLIUI",
            "AnigmaCLITUI",
            "ModelManagement",
            "AnigmaCore",
            "AnigmaPrimitives",
            "ContractsCore",
            "AnigmaMCPModule",
            "ModelRegistry",
            "HarmoniaModule",
            "AnigmaSidecar",
            .product(name: "MCP", package: "swift-sdk"),
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .product(name: "GRDB", package: "GRDB.swift")
        ],
        path: "Packages/AnigmaCLI/Executable",
        swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
    ),
    .executableTarget(
        name: "AnigmaStatusBar",
        dependencies: [
            "AnigmaSidecar",
            "AnigmaPrimitives"
        ],
        path: "Packages/AnigmaStatusBar",
        swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
    ),
    .executableTarget(name: "AnigmaDaemon", dependencies: ["AnigmaDaemonCore", "AnigmaASTServicesCore", "AnigmaSidecar", "StorageCore", "HarmoniaModule", "SidecarOfficeService", "SidecarPDFService", "SidecarTranslateService"], path: "Packages/AnigmaDaemon", exclude: ["README.md"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)])
]

let testTargets: [Target] = [
    .testTarget(name: "DatabaseCoreTests", dependencies: ["DatabaseCore", "ContractsCore"], path: "Tests/DatabaseCoreTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnigmaCoreTests", dependencies: ["AnigmaCore", "DatabaseCore", "ContractsCore", "AnigmaTestSupport"], path: "Tests/AnigmaCoreTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "DiaplasionModuleTests", dependencies: ["AnigmaCore", "DiaplasionModule"], path: "Tests/DiaplasionModuleTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "PraxisCoreTests", dependencies: ["PraxisCore", "PraxisModule"], path: "Tests/PraxisCoreTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "OutlineumModuleTests", dependencies: ["AnigmaCore", "OutlineumModule"], path: "Tests/OutlineumModuleTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "PragmaModuleTests", dependencies: ["AnigmaCore", "PragmaModule"], path: "Tests/PragmaModuleTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "ConexusModuleTests", dependencies: ["AnigmaCore", "ConexusModule"], path: "Tests/ConexusModuleTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "CodexModuleTests", dependencies: ["AnigmaCore", "CodexModule"], path: "Tests/CodexModuleTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "TranscriptumModuleTests", dependencies: ["AnigmaCore", "TranscriptumModule"], path: "Tests/TranscriptumModuleTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "ObservatoriumModuleTests", dependencies: ["AnigmaCore", "ObservatoriumModule"], path: "Tests/ObservatoriumModuleTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AccessumModuleTests", dependencies: ["AnigmaCore", "AccessumModule"], path: "Tests/AccessumModuleTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "PolytroposModuleTests", dependencies: ["AnigmaCore", "PolytroposModule", "AnigmaTestSupport"], path: "Tests/PolytroposModuleTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "TelemetryCoreTests", dependencies: ["TelemetryCore"], path: "Tests/TelemetryCoreTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "ExecutionCoreTests", dependencies: ["ExecutionCore"], path: "Tests/ExecutionCoreTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "PlatformCoreTests", dependencies: ["PlatformCore", "AnigmaCore", "CapabilityCore"], path: "Tests/PlatformCoreTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "CapabilityCoreTests", dependencies: ["CapabilityCore"], path: "Tests/CapabilityCoreTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "ContractsCoreTests", dependencies: ["ContractsCore"], path: "Tests/ContractsCoreTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "StorageCoreTests", dependencies: ["StorageCore", "DatabaseCore", "AnigmaCore", "GovernanceCore"], path: "Tests/StorageCoreTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "HarmoniaCLITests", dependencies: ["HarmoniaCLI", "StorageCore", "HarmoniaModule", "DatabaseCore", "AnigmaPrimitives"], path: "Tests/HarmoniaCLITests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "HarmoniaModuleTests", dependencies: ["HarmoniaModule", "AnigmaCore", "DatabaseCore"], path: "Tests/HarmoniaModuleTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnigmaDaemonTests", dependencies: ["AnigmaDaemonCore", "AnigmaTestSupport", "StorageCore", "TelemetryCore", .product(name: "Numerics", package: "swift-numerics")], path: "Tests/AnigmaDaemonTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "NegativeCompilationTests", dependencies: ["AnigmaClientKit"], path: "Tests/NegativeCompilationTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "CapsuleCoreTests", dependencies: ["CapsuleCore", "AnigmaPrimitives", "AnigmaNativeShims"], path: "Tests/CapsuleCoreTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnigmaSystemSpineTests", dependencies: ["AnigmaSystemSpine"], path: "Tests/AnigmaSystemSpineTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "DataEngineTests", dependencies: ["DataEngine", "DataCore"], path: "Tests/DataEngineTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "ContextumModuleTests", dependencies: ["ContextumModule", "DatabaseCore"], path: "Tests/ContextumModuleTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "ModelDeterminismTests", dependencies: ["ModelRegistry", "ContractsCore"], path: "Tests/ModelDeterminismTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnigmaCorporateTests", dependencies: ["AnigmaCorporate", "AnigmaCore", "AnigmaSystemSpine"], path: "Tests/AnigmaCorporateTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnigmaEducationTests", dependencies: ["AnigmaEducation"], path: "Tests/AnigmaEducationTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "GovernanceCoreTests", dependencies: ["GovernanceCore", "DatabaseCore", "AnigmaCore"], path: "Tests/GovernanceCoreTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnigmaAgentsTests", dependencies: ["AnigmaAgents", "AnigmaCore"], path: "Tests/AnigmaAgentsTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnigmaGeminiBridgeTests", dependencies: ["AnigmaGeminiBridge"], path: "Tests/AnigmaGeminiBridgeTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "DocumentRenderKitTests", dependencies: ["DocumentRenderKit"], path: "Tests/DocumentRenderKitTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnigmaCLICoreTests", dependencies: ["AnigmaCLICore"], path: "Tests/AnigmaCLICoreTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnigmaCLIDatabaseTests", dependencies: ["AnigmaCLIDatabase", "AnigmaCLICore"], path: "Tests/AnigmaCLIDatabaseTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnigmaCLIOrchestratorTests", dependencies: ["AnigmaCLIOrchestrator", "AnigmaCLICore"], path: "Tests/AnigmaCLIOrchestratorTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnigmaCLIProvidersTests", dependencies: ["AnigmaCLIProviders"], path: "Tests/AnigmaCLIProvidersTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnigmaCLIRouterTests", dependencies: ["AnigmaCLIRouter"], path: "Tests/AnigmaCLIRouterTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnigmaCLIGovernanceTests", dependencies: ["AnigmaCLIGovernance"], path: "Tests/AnigmaCLIGovernanceTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnigmaCLIEventingTests", dependencies: ["AnigmaCLIEventing"], path: "Tests/AnigmaCLIEventingTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnigmaCLIMCPTests", dependencies: ["AnigmaCLIMCP"], path: "Tests/AnigmaCLIMCPTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnigmaCLITests", dependencies: ["AnigmaCLIDatabase", "AnigmaCLICore", "AnigmaCLIOrchestrator"], path: "Tests/AnigmaCLITests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "CathedralModuleTests", dependencies: ["CathedralModule", "AnigmaCore", "DatabaseCore"], path: "Tests/CathedralModuleTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "ArtifactStoreModuleTests", dependencies: ["ArtifactStoreModule", "AnigmaCore", "ContractsCore", "DatabaseCore"], path: "Tests/ArtifactStoreModuleTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "ModelRegistryModuleTests", dependencies: ["ModelRegistryModule", "AnigmaCore", "ContractsCore", "DatabaseCore"], path: "Tests/ModelRegistryModuleTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnigmaPrimitivesTests", dependencies: ["AnigmaPrimitives"], path: "Tests/AnigmaPrimitivesTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "DataCoreTests", dependencies: ["DataCore", "AnigmaPrimitives"], path: "Tests/DataCoreTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "VectorumModuleTests", dependencies: ["VectorumModule", "AnigmaCore", "DatabaseCore"], path: "Tests/VectorumModuleTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "SecurityEventsManagerTests", dependencies: ["SecurityEventsManager", "AnigmaPrimitives"], path: "Tests/SecurityEventsManagerTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnigmaClientKitTests", dependencies: ["AnigmaClientKit", "AnigmaPrimitives", "ContractsCore"], path: "Tests/AnigmaClientKitTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "MLWorkerCommonTests", dependencies: ["MLWorkerCommon", "AnigmaPrimitives"], path: "Tests/MLWorkerCommonTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "DoctrineCoreTests", dependencies: ["DoctrineCore", "GovernanceCore", "AnigmaCore", "AnigmaPrimitives"], path: "Tests/DoctrineCoreTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "HarmoniaMemoryTests", dependencies: ["HarmoniaMemory", "AnigmaCore", "TelemetryCore"], path: "Tests/HarmoniaMemoryTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "HarmoniaSurfaceTests", dependencies: ["HarmoniaSurface"], path: "Tests/HarmoniaSurfaceTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "DoctrineCLITests", dependencies: ["DoctrineCLI"], path: "Tests/DoctrineCLITests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "DiaplasionPipelineTests", dependencies: ["DiaplasionPipeline"], path: "Tests/DiaplasionPipelineTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "ObservabilityKitTests", dependencies: ["ObservabilityKit"], path: "Tests/ObservabilityKitTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "CompressionKitTests", dependencies: ["CompressionKit"], path: "Tests/CompressionKitTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "TypographyKitTests", dependencies: ["TypographyKit"], path: "Tests/TypographyKitTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "AnimationKitTests", dependencies: ["AnimationKit"], path: "Tests/AnimationKitTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "ColorKitTests", dependencies: ["ColorKit"], path: "Tests/ColorKitTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "ContainerKitTests", dependencies: ["ContainerKit"], path: "Tests/ContainerKitTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "CanonicalTokenizerTests", dependencies: ["CanonicalTokenizer"], path: "Tests/CanonicalTokenizerTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "LayoutEngineCapsuleTests", dependencies: ["LayoutEngineCapsule", "CapsuleCore"], path: "Tests/LayoutEngineCapsuleTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "VizAggregationCapsuleTests", dependencies: ["VizAggregationCapsule", "CapsuleCore"], path: "Tests/VizAggregationCapsuleTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "MFCTests", dependencies: ["MediaFingerprintCapsule"], path: "Tests/MFCTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "VectorCapsuleTests", dependencies: ["VectorCapsule", "CapsuleCore"], path: "Tests/VectorCapsuleTests", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "EmbeddingStabilityTests", dependencies: ["ContractsCore", "VectorumModule"], path: "Tests/EmbeddingStability", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)])
]

let package = Package(
    name: "Anigma",
    platforms: [
        .macOS(.v14), .iOS(.v17), .tvOS(.v17), .watchOS(.v10)
    ],
    products: coreProducts + executableProducts + capabilityProducts,
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "510.0.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.29.1"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "2.29.2"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
        .package(url: "https://github.com/apple/swift-numerics.git", from: "1.0.2"),
        .package(url: "https://github.com/jdfergason/swift-toml.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/tree-sitter/swift-tree-sitter.git", from: "0.8.0"),
        .package(url: "https://github.com/apple/swift-cmark.git", from: "0.5.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.19.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.4.1"),
    ],
    targets: nativeTargets + coreTargets + moduleTargets + executableTargets + testTargets,
    cxxLanguageStandard: .cxx17
)
