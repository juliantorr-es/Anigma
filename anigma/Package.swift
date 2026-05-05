// swift-tools-version: 5.10
// Package.swift
import Foundation
import PackageDescription

let isCI = ProcessInfo.processInfo.environment["CI"] != nil

// Swift language mode settings to handle dependency compatibility
// Note: swiftLanguageMode was introduced in PackageDescription 6.0, but we're using 5.10
// For now, we'll use the version("6") syntax which is available in 5.10
let swiftLanguageMode: SwiftSetting = .unsafeFlags(["-swift-version", "6"])
let legacySwiftLanguageMode: SwiftSetting = .unsafeFlags(["-swift-version", "5"])

// Settings for dependencies that need Swift 5 compatibility
let swift5CompatibilitySettings: [SwiftSetting] = [
  .unsafeFlags(["-swift-version", "5"]),
  .enableUpcomingFeature("MemberImportVisibility"),
  .enableExperimentalFeature("BuiltinModule"),
  .enableExperimentalFeature("Lifetimes"),
  .enableExperimentalFeature("InoutLifetimeDependence"),
  .enableExperimentalFeature("SuppressedAssociatedTypes")
]
let enableFFmpegLinking = ProcessInfo.processInfo.environment["ENABLE_FFMPEG_LINKING"] == "1"
let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let vendorLibPath = "\(packageRoot)/Vendor/lib"
let vendorLinkerSettings: [LinkerSetting] = [
  .unsafeFlags(["-L", vendorLibPath])
]
let ffmpegLinkerSettings: [LinkerSetting] =
  enableFFmpegLinking
  ? [
    .linkedLibrary("avcodec"),
    .linkedLibrary("avformat"),
    .linkedLibrary("avutil"),
    .linkedLibrary("swscale"),
    .linkedLibrary("swresample")
  ] : []
let testRuntimeLinkerSettings: [LinkerSetting] = [
  .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", vendorLibPath]),
  .unsafeFlags(["-Xlinker", "-no_warn_duplicate_libraries"])
]

let testOnlyLinkerSettings: [LinkerSetting] = [
  .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", vendorLibPath]),
  .unsafeFlags(["-Xlinker", "-no_warn_duplicate_libraries"])
]

// PDFium-specific paths (relative to package root)
let pdfiumVendorPath = "\(packageRoot)/External/Vendor/PDFium/macos-arm64"
let pdfiumLinkerSettings: [LinkerSetting] = [
  .unsafeFlags(["-L", "\(pdfiumVendorPath)/lib"]),
  .unsafeFlags(["-I", "\(pdfiumVendorPath)/include"]),
  .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@loader_path/../../../External/Vendor/PDFium/macos-arm64/lib"])
]
let pdfiumHeaderSearchPath = "../../../External/Vendor/PDFium/macos-arm64/include"

let strictConcurrencySettings: [SwiftSetting] = [
  .unsafeFlags(["-strict-concurrency=targeted"])
]

let debugPerformanceSettings: [SwiftSetting] = [
  .unsafeFlags(["-Xfrontend", "-stats-output-dir", "-Xfrontend", ".build/stats"]),
  .unsafeFlags(["-Xfrontend", "-warn-long-function-bodies=100"]),
  .unsafeFlags(["-Xfrontend", "-warn-long-expression-type-checking=100"])
]

// Swift Language Mode Strategy
// ============================
// Main codebase targets Swift 6.0 language mode (.v6)
// However, some dependencies (swift-collections, swift-service-lifecycle) use Swift 5 mode
// This creates a manifest mismatch that needs to be handled carefully
//
// For our targets: Use swiftLanguageMode (.v6)
// For dependency compatibility: Use swift5CompatibilitySettings
//
// Note: The _RopeModule in swift-collections has a known Swift 6 compatibility issue
// with _modify accessors, forcing it to use .v5 mode. This should be revisited
// when swift-collections updates their Swift 6 support.

let skipTestsOnCI: [Target] = isCI ? [] : []  // Logic placeholder
let sceneGraphCapsuleTestsPathCandidates = [
  "Packages/SceneGraphCapsule/Tests/SceneGraphCapsuleTests",
  "Anigma/Packages/SceneGraphCapsule/Tests/SceneGraphCapsuleTests"
]
let sceneGraphCapsuleTestsPath = sceneGraphCapsuleTestsPathCandidates.first {
  FileManager.default.fileExists(atPath: $0)
}

let coreProducts: [Product] = [
  .library(name: "AnigmaFoundation", targets: ["AnigmaFoundation"]),
  .library(name: "AnigmaCore", targets: ["AnigmaCore"]),
  .library(name: "AnigmaGovernance", targets: ["AnigmaGovernance"]),
  .library(name: "AnigmaJobs", targets: ["AnigmaJobs"]),
  .library(name: "AnigmaPipeline", targets: ["AnigmaPipeline"]),
  .library(name: "AnigmaPrimitives", targets: ["AnigmaPrimitives"]),
  .library(name: "AnigmaEvents", targets: ["AnigmaEvents"]),
  .library(name: "CapsuleCore", targets: ["CapsuleCore"]),
  .library(name: "DatabaseCore", targets: ["DatabaseCore"]),
  .library(name: "RuntimeCore", targets: ["RuntimeCore"]),
  .library(name: "FoundationContracts", targets: ["FoundationContracts"]),
  .library(name: "IntelligenceContracts", targets: ["IntelligenceContracts"]),
  .library(name: "GovernanceContracts", targets: ["GovernanceContracts"]),
  .library(name: "EvidenceContracts", targets: ["EvidenceContracts"]),
  .library(name: "PersistenceContracts", targets: ["PersistenceContracts"]),
  .library(name: "MessagingContracts", targets: ["MessagingContracts"]),
  .library(name: "MediaPipelineContracts", targets: ["MediaPipelineContracts"]),
  .library(name: "RendererBackendContracts", targets: ["RendererBackendContracts"]),
  .library(name: "SecurityEventsContracts", targets: ["SecurityEventsContracts"]),
  .library(name: "ContractsCore", targets: ["ContractsCore"]),
  .library(name: "LayoutEngineContracts", targets: ["LayoutEngineContracts"]),
  .library(name: "PDFLayoutExtract", targets: ["PDFLayoutExtract"]),
  .library(name: "DaemonFeatureContracts", targets: ["DaemonFeatureContracts"]),
  .library(name: "DaemonKernel", targets: ["DaemonKernel"]),
  .library(name: "ModelRegistryDaemonFeature", targets: ["ModelRegistryDaemonFeature"]),
  .library(name: "DaemonStatusDaemonFeature", targets: ["DaemonStatusDaemonFeature"]),
  .library(name: "InferenceContracts", targets: ["InferenceContracts"]),
  .library(name: "SaturationInferenceCore", targets: ["SaturationInferenceCore"]),
  .library(name: "SaturatedModelRegistry", targets: ["SaturatedModelRegistry"]),
  .library(name: "GovernanceCore", targets: ["GovernanceCore"]),
  .library(name: "StorageCore", targets: ["StorageCore"]),
  .library(name: "CapabilityCore", targets: ["CapabilityCore"]),
  .library(name: "DoctrineCore", targets: ["DoctrineCore"]),
  .library(name: "SecurityEventsManager", targets: ["SecurityEventsManager"]),
  .library(name: "TelemetryCore", targets: ["TelemetryCore"]),
  .library(name: "SaturationKitCore", targets: ["SaturationKitCore"]),
  .library(name: "SaturationKit", targets: ["SaturationKit"]),
  .library(name: "CHarfBuzz", targets: ["CHarfBuzz"]),
  .library(name: "ExecutionCore", targets: ["ExecutionCore"]),
  .library(name: "InferenceCore", targets: ["InferenceCore"]),
  .library(name: "CanonicalTokenizer", targets: ["CanonicalTokenizer"]),
  .library(name: "PlatformCore", targets: ["PlatformCore"]),
  .library(name: "AnigmaClientKit", targets: ["AnigmaClientKit"]),
  // .library(name: "AnigmaHostKit", targets: ["AnigmaHostKit"]),
  // .library(name: "AnigmaHostMac", targets: ["AnigmaHostMac"]),
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
  .library(name: "ANEServicesCore", targets: ["ANEServicesCore"]),
  .library(name: "ANECapsuleContracts", targets: ["ANECapsuleContracts"]),
  .library(name: "ANECapabilityCatalog", targets: ["ANECapabilityCatalog"]),
  .library(name: "ANEExecutionReceipts", targets: ["ANEExecutionReceipts"]),
  .library(name: "ANEPlacementCoreML", targets: ["ANEPlacementCoreML"]),
  .library(name: "ANECapsuleIntegration", targets: ["ANECapsuleIntegration"]),

  // Native Capability Modules
  .library(name: "DocumentIRKit", targets: ["DocumentIRKit"]),
  .library(name: "ContainerKit", targets: ["ContainerKit"]),
  .library(name: "OOXMLKit", targets: ["OOXMLKit"]),
  .library(name: "DocumentRenderKit", targets: ["DocumentRenderKit"]),
  .library(name: "TypographyKit", targets: ["TypographyKit"]),
  .library(name: "TextRenderKit", targets: ["TextRenderKit"]),
  .library(name: "ColorKit", targets: ["ColorKit"]),
  .library(name: "TessellationCapsule", targets: ["TessellationCapsule"]),
  .library(name: "VectorOpsKit", targets: ["VectorOpsKit"]),
  .library(name: "CompressionKit", targets: ["CompressionKit"]),
  // .library(name: "PDFCapsule", targets: ["PDFCapsule"]),
  .library(name: "SyntaxCapsule", targets: ["SyntaxCapsule"]),
  .library(name: "GeometryCapsule", targets: ["GeometryCapsule"]),
  .library(name: "TextChunkingCapsule", targets: ["TextChunkingCapsule"]),
  .library(name: "VizAggregationCapsule", targets: ["VizAggregationCapsule"]),
  .library(name: "MediaFingerprintCapsule", targets: ["MediaFingerprintCapsule"]),
  .library(name: "VectorCapsule", targets: ["VectorCapsule"]),
  .library(name: "TextPipelineCapsule", targets: ["TextPipelineCapsule"]),

  // Advanced Document Processing Capsules
  // .library(name: "TableExtractionCapsule", targets: ["TableExtractionCapsule"]),
  // .library(name: "MathOCRCapsule", targets: ["MathOCRCapsule"]),
  // .library(name: "CitationExtractionCapsule", targets: ["CitationExtractionCapsule"]),
  // .library(name: "ReferenceResolutionCapsule", targets: ["ReferenceResolutionCapsule"]),
  // .library(name: "DiffCapsule", targets: ["DiffCapsule"]),
  .library(name: "VectorIndexCapsule", targets: ["VectorIndexCapsule"]),
  .library(name: "CosineSimilarityCapsule", targets: ["CosineSimilarityCapsule"]),
  .library(name: "RankFusionCapsule", targets: ["RankFusionCapsule"]),
  .library(name: "AnimationKit", targets: ["AnimationKit"]),
  .library(name: "SceneGraphCapsule", targets: ["SceneGraphCapsule"]),
  .library(name: "RenderIntentCapsule", targets: ["RenderIntentCapsule"]),
  .library(name: "RenderGraphCapsule", targets: ["RenderGraphCapsule"]),
  // .library(name: "RenderBackendCapsule", targets: ["RenderBackendCapsule"]),
  // .library(name: "RenderPlanCapsule", targets: ["RenderPlanCapsule"]),
  // .library(name: "HitTestCapsule", targets: ["HitTestCapsule"]),
  .library(name: "ObservabilityKit", targets: ["ObservabilityKit"]),
  .library(name: "SidecarOfficeService", targets: ["SidecarOfficeService"]),
  .library(name: "SidecarPDFService", targets: ["SidecarPDFService"]),
  .library(name: "SidecarTranslateService", targets: ["SidecarTranslateService"]),
  .library(name: "SubprocessPooling", targets: ["SubprocessPooling"]),
  .library(name: "AnigmaNativeShims", targets: ["AnigmaNativeShims"]),

  // Canvas Engine Modules
  .library(name: "RuntimeOrchestrator", targets: ["RuntimeOrchestrator"]),
  .library(name: "PlatformAdapters", targets: ["PlatformAdapters"]),
  // .library(name: "AnigmaUI", targets: ["AnigmaUI"])
]

let executableProducts: [Product] = [
  .executable(name: "anigma-mcp", targets: ["AnigmaMCPExecutable"]),
  // Canonical shipped executables: harmonia, anigmad, and ml-worker.
  // Launcher-only and benchmark surfaces stay here for packaging/developer workflows,
  // but are not part of the primary shipped CLI/daemon set.
  // .executable(name: "ml-worker", targets: ["MLWorkerExecutable"]),
  // .executable(name: "anigma-capsule-bench", targets: ["anigma-capsule-bench"]),
  .executable(name: "anigma-app", targets: ["AnigmaAppMacExecutable"]),  // Launcher-only app surface
  .executable(name: "anigmad", targets: ["AnigmaDaemon"]),
  .executable(name: "harmonia", targets: ["HarmoniaV2CLI"]),
  // .executable(name: "anigmad-verifier", targets: ["AnigmaDaemonVerifier"]),
]

let capabilityProducts: [Product] = [
  .library(name: "HarmoniaAPIContracts", targets: ["HarmoniaAPIContracts"]),
  .library(name: "HarmoniaInferenceContracts", targets: ["HarmoniaInferenceContracts"]),
  .library(name: "HarmoniaWorkflowContracts", targets: ["HarmoniaWorkflowContracts"]),
  // HarmoniaV2 - Clean modular replacement for HarmoniaModule (0 compilation errors)
  .library(name: "HarmoniaV2Contracts", targets: ["HarmoniaV2Contracts"]),
  .library(name: "HarmoniaV2Surface", targets: ["HarmoniaV2Surface"]),
  .library(name: "HarmoniaRuntime", targets: ["HarmoniaRuntime"]),
  .library(name: "HarmoniaCLIIntegration", targets: ["HarmoniaCLIIntegration"]),
  .library(name: "HarmoniaContractsIntegration", targets: ["HarmoniaContractsIntegration"]),
  .library(name: "HarmoniaDataIntegration", targets: ["HarmoniaDataIntegration"]),
  .library(name: "HarmoniaANEIntegration", targets: ["HarmoniaANEIntegration"]),
  .library(name: "HarmoniaV2Core", targets: ["HarmoniaV2Core"]),
  .library(name: "HarmoniaV2Inference", targets: ["HarmoniaV2Inference"]),
  .library(name: "HarmoniaV2Memory", targets: ["HarmoniaV2Memory"]),
  .library(name: "HarmoniaV2Orchestration", targets: ["HarmoniaV2Orchestration"]),
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
  .library(name: "IntelligenceCore", targets: ["IntelligenceCore"]),
  .library(name: "ArtifactStoreModule", targets: ["ArtifactStoreModule"]),
  // .library(name: "DevelopumModule", targets: ["DevelopumModule"]),
  .library(name: "ModelRegistryModule", targets: ["ModelRegistryModule"]),
  .library(name: "AnigmaAgents", targets: ["AnigmaAgents"]),
  .library(name: "AnigmaAIConsole", targets: ["AnigmaAIConsole"]),
  // .executable(name: "harmonia", targets: ["HarmoniaCLI"]),
  .library(name: "HarmoniaV2CLIKernel", targets: ["HarmoniaV2CLIKernel"]),  // NEW: Testable CLI kernel
  // .executable(name: "anigmad", targets: ["AnigmaDaemon"])
]

let nativeTargets: [Target] = [
  .target(
    name: "CHarfBuzz",
    path: "Packages/CHarfBuzz",
    publicHeadersPath: ".",
    cSettings: [
      .headerSearchPath("include/harfbuzz"),
      .headerSearchPath("include/freetype2")
    ],
    linkerSettings: [
      .linkedLibrary("harfbuzz"),
      .linkedLibrary("freetype")
    ]
  ),
  .target(name: "CFreeType", path: "Packages/CFreeType", publicHeadersPath: "."),
  .target(
    name: "CClipper2",
    path: "Packages/CClipper2",
    exclude: ["example.c"],
    sources: [
      "clipper2_wrapper.cpp",
      "Clipper2/CPP/Clipper2Lib/src/clipper.engine.cpp",
      "Clipper2/CPP/Clipper2Lib/src/clipper.offset.cpp",
      "Clipper2/CPP/Clipper2Lib/src/clipper.triangulation.cpp",
      "Clipper2/CPP/Clipper2Lib/src/clipper.rectclip.cpp",
      "Clipper2/CPP/Utils/clipper.svg.cpp"
    ],
    publicHeadersPath: ".",
    cxxSettings: [
      .headerSearchPath("Clipper2/CPP/Clipper2Lib/include"),
      .headerSearchPath("Clipper2/CPP/Utils"),
      .unsafeFlags(["-Wno-sign-conversion", "-Wno-float-conversion", "-Wno-unused-parameter"])
    ],
    linkerSettings: vendorLinkerSettings
  ),
  .target(
    name: "PDFNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/PDFCapsule/Sources/PDFNative",

    cxxSettings: [
      .headerSearchPath(pdfiumHeaderSearchPath)
    ],
    linkerSettings: [.linkedLibrary("pdfium")] + pdfiumLinkerSettings
  ),
  .target(
    name: "MarkdownNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/MarkdownCapsule/Sources/MarkdownNative",
    exclude: [
      "src/CMakeLists.txt",
      "src/case_fold_switch.inc",
      "src/config.h.in",
      "src/entities.inc",
      "src/libcmark-gfm.pc.in",
      "src/scanners.re"
    ],
    sources: ["src"],
    cSettings: [
      .headerSearchPath("src")
    ],
    cxxSettings: [
      .headerSearchPath("src")
    ]
  ),
  .target(
    name: "SyntaxNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/SyntaxCapsule/Sources/SyntaxNative",
    sources: [
      "src/lib.c",
      "src/languages/json/parser.c",
      "src/syntax_capsule.cpp"
    ],

    cSettings: [
      .headerSearchPath("src")
    ],
    cxxSettings: [
      .headerSearchPath("src")
    ]
  ),
  .target(
    name: "AnigmaNativeShims",
    path: "Packages/AnigmaNativeShims",
    exclude: [],
    sources: ["Sources"],
    publicHeadersPath: "include",
    cSettings: [
      .headerSearchPath("include"),
      .headerSearchPath("../../Vendor/include"),
      .define("ANIGMA_CAPSULE_IMPLEMENTATION")
    ],
    cxxSettings: [
      .headerSearchPath("include"),
      .define("ANIGMA_CAPSULE_IMPLEMENTATION"),
      .unsafeFlags([
        "-Wno-everything"
      ])
    ],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)] + [
      .interoperabilityMode(.Cxx)
    ],
    linkerSettings: vendorLinkerSettings
  ),
  .target(
    name: "NativeKernel",
    dependencies: ["AnigmaNativeShims"],
    path: "Native/Kernel",
    sources: ["src/kernel_context.cpp"],

    cxxSettings: [
      .headerSearchPath("include"),
      .unsafeFlags([
        "-O3", "-ffast-math"
      ]),  // Performance optimizations
    ],
    linkerSettings: vendorLinkerSettings
  ),
  .target(
    name: "GeometryNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/GeometryCapsule/Sources/GeometryNative",

    cxxSettings: [
      .headerSearchPath("src/Clipper2Lib/include"),
      .unsafeFlags([
        "-Wno-sign-conversion", "-Wno-float-conversion", "-Wno-unused-parameter"
      ])
    ]
  ),
  .target(
    name: "TextChunkingNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/TextChunkingCapsule/Sources/TextChunkingNative",

    cxxSettings: [],
    linkerSettings: ffmpegLinkerSettings
  ),
  .target(
    name: "LayoutEngineNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/LayoutEngineCapsule/Sources/LayoutEngineNative",

    cxxSettings: [
      .headerSearchPath("../../../../Vendor/include")
    ]
  ),
  .target(
    name: "VizAggregationNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/VizAggregationCapsule/Sources/VizAggregationNative",

    cxxSettings: [], linkerSettings: ffmpegLinkerSettings
  ),
  .target(
    name: "MediaFingerprintNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/MediaFingerprintCapsule/Sources/MediaFingerprintNative",

    cxxSettings: [],
    linkerSettings: ffmpegLinkerSettings
  ),
  .target(
    name: "MediaContainerNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/MediaContainerCapsule/Sources/MediaContainerNative",

    cxxSettings: [
      .headerSearchPath("include")
    ], linkerSettings: ffmpegLinkerSettings
  ),
  .target(
    name: "VectorNative",
    dependencies: ["CClipper2", "AnigmaNativeShims"],
    path: "Packages/VectorCapsule/Sources/VectorNative",

    cSettings: [
      .headerSearchPath("include")
    ],
    cxxSettings: [
      .headerSearchPath("include"),
      .headerSearchPath("../../../CClipper2")
    ]
  ),
  .target(
    name: "TextPipelineNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/TextPipelineCapsule/Sources/TextPipelineNative",
    cxxSettings: [],
    linkerSettings: []
  ),
  .target(
    name: "VectorIndexNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/VectorIndexCapsule/Sources/VectorIndexNative",

    cxxSettings: [],
    linkerSettings: ffmpegLinkerSettings
  ),
  .target(
    name: "TableExtractionNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/TableExtractionCapsule/Native",

    cxxSettings: [],
    linkerSettings: []
  ),

  // Advanced Document Processing Native Targets
  .target(
    name: "MathOCRNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/MathOCRCapsule/Native"
  ),
  .target(
    name: "CitationExtractionNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/CitationExtractionCapsule/Native"
  ),
  .target(
    name: "ReferenceResolutionNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/ReferenceResolutionCapsule/Native"
  ),
  .target(
    name: "DiffNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/DiffCapsule/Native"
  ),
  .target(
    name: "CosineNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/CosineSimilarityCapsule/Sources/CosineNative",

    cxxSettings: [],
    linkerSettings: ffmpegLinkerSettings
  ),
  .target(
    name: "RankFusionNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/RankFusionCapsule/Sources/RankFusionNative",

    cxxSettings: [],
    linkerSettings: ffmpegLinkerSettings
  ),
  .target(
    name: "SceneGraphNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/SceneGraphCapsule/Sources/SceneGraphNative",

    cxxSettings: [],
    linkerSettings: []
  ),
  .target(
    name: "RenderPlanNative",
    dependencies: ["AnigmaNativeShims", "SceneGraphNative"],
    path: "Packages/RenderPlanCapsule/Sources/RenderPlanNative"
  ),
  .target(
    name: "HitTestNative",
    dependencies: ["SceneGraphNative", "AnigmaNativeShims"],
    path: "Packages/HitTestCapsule/Sources/HitTestNative"
  ),
  .target(
    name: "AnimationNative",
    dependencies: ["AnigmaNativeShims"],
    path: "Packages/AnimationKit/Sources/AnimationNative",

    cxxSettings: [], linkerSettings: ffmpegLinkerSettings
  )
]

let coreTargets: [Target] = [
  // .target(name: "PDFCapsule", dependencies: ["AnigmaPrimitives", "CapsuleCore", "TelemetryCore", "PDFNative", "AnigmaNativeShims"], path: "Packages/PDFCapsule/Sources/PDFCapsule", swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "MarkdownCapsule",
    dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "MarkdownNative"],
    path: "Packages/MarkdownCapsule/Sources/MarkdownCapsule",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "SyntaxCapsule",
    dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "SyntaxNative"],
    path: "Packages/SyntaxCapsule/Sources/SyntaxCapsule",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaFoundation",
    dependencies: [
      "AnigmaPrimitives", "FoundationContracts", "GovernanceContracts", "EvidenceContracts",
      "IntelligenceContracts", "GovernanceCore", "StorageCore", "TelemetryCore",
      "MLWorkerInterfaces", "RendererBackendContracts"
    ],
    path: "Packages/AnigmaCore/Sources/AnigmaFoundation",
    exclude: ["AnigmaFoundation.swift", "Runtime/", "Integration/", "Backend/", "Tenant/", "Identity/", "Updates/"],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),

  .target(
    name: "RuntimeCore",
    dependencies: [
      "AnigmaFoundation", "DatabaseCore", "ContractsCore", "FoundationContracts",
      "GovernanceContracts", "EvidenceContracts", "IntelligenceContracts",
      "PersistenceContracts", "AnigmaPrimitives"
    ],
    path: "Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),

  .target(
    name: "AnigmaGovernance",
    dependencies: [
      "AnigmaFoundation",
      "GovernanceCore",
      "SecurityEventsManager",
      "ComplianceAuditModule",
      "FoundationContracts",
      "GovernanceContracts",
      "EvidenceContracts",
      "IntelligenceContracts"
    ],
    path: "Packages/AnigmaCore/Sources/AnigmaGovernance",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "ComplianceAuditModule",
    dependencies: [
      "ContractsCore",
      "AnigmaPrimitives",
      "DatabaseCore",
      .product(name: "Hummingbird", package: "hummingbird")
    ],
    path: "Packages/ComplianceAuditModule/Sources/ComplianceAuditModule",
    exclude: [
      "APIModels.swift",
      "AuditAPIController.swift",
      "AuditReportGenerationService.swift",
      "CSVReportExporter.swift",
      "PDFReportExporter.swift",
      "Schema_ComplianceAudit.sql"
    ],
    sources: [
      "ComplianceAuditModule.swift",
      "AuditModels.swift",
      "AuditLoggingService.swift"
    ],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "AnigmaJobs",
    dependencies: ["AnigmaFoundation", "AnigmaGovernance", "InferenceCore", "DatabaseCore"],
    path: "Packages/AnigmaCore/Sources/AnigmaJobs",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "MLWorkerInterfaces",
    dependencies: ["ContractsCore", "AnigmaPrimitives", "InferenceCore"],
    path: "Packages/AnigmaCore/Sources/AnigmaPipeline/Pipeline",
    exclude: [
      "AINodes.swift",
      "ArtifactStore.swift",
      "Contracts",
      "GrapheneCore.swift",
      "GrapheneEngine.swift",
      "GrapheneInferenceBridge.swift",
      "GraphenePrimitives.swift",
      "GrapheneProfiling.swift",
      "GrapheneRegistry.swift",
      "GrapheneStreaming.swift",
      "GrapheneSubgraph.swift",
      "GrapheneVerticalSlice.swift",
      "InferencePlaneAdapter.swift",
      "MediaFabricComponent.swift",
      "Metopticon",
      "MLWorkerEmbeddingComputer.swift",
      "PDFProcessing.swift",
      "PipelineContractRegistry.swift",
      "PipelineECS.swift",
      "PipelineGraph.swift",
      "PipelineModule.swift",
      "PipelineRunner.swift",
      "PipelineStatus.swift",
      "PipelineStatusSerializer.swift",
      "PluginSystem.swift",
      "SaturationSystem.swift"
    ],
    sources: ["MLWorkerInterface.swift"],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "AnigmaPipeline",
    dependencies: [
      "AnigmaFoundation",
      "AnigmaGovernance",
      "AnigmaJobs",
      "InferenceCore",
      "TextChunkingCapsule",
      "LayoutEngineContracts",
      "MediaPipelineContracts",
      "StorageCore",
      "MLWorkerInterfaces",
      "NativeKernel",
      "SaturationKit"
    ],
    path: "Packages/AnigmaCore/Sources/AnigmaPipeline",
    exclude: ["Pipeline/MLWorkerInterface.swift"],
    sources: [
      "Automation/Automation.swift",
      "Components/BoundedMemoryBenchmark.swift",
      "Components/ContractPayloadReferenceAdapter.swift",
      "Components/MemoryBudgetTelemetry.swift",
      "Components/MemoryComponent.swift",
      "Components/MemorySystem.swift",
      "Components/PayloadReferenceDecorator.swift",
      "Components/ResidencyComponent.swift",
      "Components/ResidencySystem.swift",
      "Components/SharedComponents.swift",
      "Inference/AuthConductor.swift",
      "Inference/TranslatorRegistry.swift",
      "Pipeline/AINodes.swift",
      "Pipeline/ArtifactStore.swift",
      "Pipeline/Contracts/EmbedTextContract.swift",
      "Pipeline/Contracts/HardeningAttestationContract.swift",
      "Pipeline/Contracts/HybridSearchContract.swift",
      "Pipeline/Contracts/IndexEmbeddingsContract.swift",
      "Pipeline/Contracts/PDFExtractContract.swift",
      "Pipeline/Contracts/PDFIngestContract.swift",
      "Pipeline/Contracts/PDFQACheckContract.swift",
      "Pipeline/Contracts/PDFSegmentContract.swift",
      "Pipeline/Contracts/RunSwiftTestsContract.swift",
      "Pipeline/GrapheneCore.swift",
      "Pipeline/GrapheneEngine.swift",
      "Pipeline/GrapheneInferenceBridge.swift",
      "Pipeline/GraphenePrimitives.swift",
      "Pipeline/GrapheneProfiling.swift",
      "Pipeline/GrapheneRegistry.swift",
      "Pipeline/GrapheneStreaming.swift",
      "Pipeline/GrapheneSubgraph.swift",
      "Pipeline/GrapheneVerticalSlice.swift",
      "Pipeline/InferencePlaneAdapter.swift",
      "Pipeline/MediaFabricComponent.swift",
      "Pipeline/Metopticon/MetopticonDashboard.swift",
      "Pipeline/Metopticon/MetopticonIntegration.swift",
      "Pipeline/Metopticon/MetopticonManifest.swift",
      "Pipeline/Metopticon/MetopticonModule.swift",
      "Pipeline/Metopticon/MetopticonRBAC.swift",
      "Pipeline/Metopticon/MetopticonRunner.swift",
      "Pipeline/MLWorkerEmbeddingComputer.swift",
      "Pipeline/PDFProcessing.swift",
      "Pipeline/PipelineContractRegistry.swift",
      "Pipeline/PipelineECS.swift",
      "Pipeline/PipelineGraph.swift",
      "Pipeline/PipelineModule.swift",
      "Pipeline/PipelineRunner.swift",
      "Pipeline/PipelineStatus.swift",
      "Pipeline/PipelineStatusSerializer.swift",
      "Pipeline/PluginSystem.swift",
      "Pipeline/SaturationSystem.swift",
      "Reasoning/AdversarialScenarios.swift",
      "Reasoning/ContinuousReasoning.swift",
      "Reasoning/DomainPuzzleBuilders.swift",
      "Reasoning/DomainReasoningIntegration.swift",
      "Reasoning/IRService.swift",
      "Reasoning/MakerEngine.swift",
      "Reasoning/MakerEnhancements/DeterminismContext.swift",
      "Reasoning/MakerEnhancements/MakerEnhancementLayer.swift",
      "Reasoning/MakerEnhancements/MakerEnhancementSupport.swift",
      "Reasoning/MakerEnhancements/MakerReceipt.swift",
      "Reasoning/MetaPuzzles.swift",
      "Reasoning/PuzzleBuilders.swift",
      "Reasoning/ReasoningIntegration.swift",
      "Reasoning/ReasoningKernel.swift",
      "Reasoning/ReasoningOrchestrator.swift",
      "Reasoning/ReasoningTransitionLane.swift",
      "Reasoning/TwoTierReasoning.swift",
      "SceneGraph.swift",
    ],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "AnigmaCore",
    dependencies: [
      "AnigmaFoundation",
      "AnigmaGovernance",
      "AnigmaJobs",
      "AnigmaPipeline"
    ],
    path: "Packages/AnigmaCore/Sources/AnigmaCoreUmbrella",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "AnigmaPrimitives",
    dependencies: ["AnigmaNativeShims", .product(name: "Crypto", package: "swift-crypto")],
    path: "Packages/AnigmaPrimitives", exclude: [],
    swiftSettings: strictConcurrencySettings),
  .target(
    name: "PersistenceContracts",
    dependencies: ["FoundationContracts"],
    path: "Packages/ContractsCore/Sources/PersistenceContracts"
  ),
  .target(
    name: "SecurityEventsContracts",
    dependencies: ["FoundationContracts"],
    path: "Packages/ContractsCore/Sources/SecurityEventsContracts",
    swiftSettings: strictConcurrencySettings
  ),
  .target(
    name: "AnigmaEvents", dependencies: ["AnigmaPrimitives"], path: "Packages/AnigmaEvents",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "DatabaseCore",
    dependencies: [
      "FoundationContracts", "EvidenceContracts", "GovernanceContracts", "VectorIndexCapsule",
      "SecurityEventsContracts",
      .product(name: "PostgresNIO", package: "postgres-nio")
    ], path: "Packages/DatabaseCore",
    exclude: [
      "Schema_Master.sql", "Schema_Evidence.sql", "Schema_BuildDiagnostics.sql",
      "Schema_CourtSafe.sql", "Schema_DocumentUnits.sql", "Schema_EvidenceBundle.sql",
      "GovernedPersistence_RLS.sql"
    ], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "FoundationContracts",
    dependencies: ["AnigmaPrimitives"],
    path: "Packages/ContractsCore/Sources/FoundationContracts",
    swiftSettings: strictConcurrencySettings
  ),
  .target(
    name: "GovernanceContracts",
    dependencies: ["FoundationContracts", "AnigmaPrimitives"],
    path: "Packages/ContractsCore/Sources/GovernanceContracts",
    swiftSettings: strictConcurrencySettings
  ),
  .target(
    name: "EvidenceContracts",
    dependencies: [
      "GovernanceContracts", "FoundationContracts", "AnigmaPrimitives"
    ],
    path: "Packages/ContractsCore/Sources/EvidenceContracts",
    swiftSettings: strictConcurrencySettings
  ),
  .target(
    name: "IntelligenceContracts",
    dependencies: [
      "EvidenceContracts",
      "GovernanceContracts",
      "FoundationContracts",
      "AnigmaPrimitives",
      .product(name: "ArgumentParser", package: "swift-argument-parser")
    ],
    path: "Packages/ContractsCore/Sources/IntelligenceContracts",
    swiftSettings: strictConcurrencySettings
  ),
  .target(
    name: "ContractsCore",
    dependencies: [
      "FoundationContracts",
      "GovernanceContracts",
      "EvidenceContracts",
      "IntelligenceContracts",
      "SecurityEventsContracts"
    ],
    path: "Packages/ContractsCore/Sources/ContractsCore",
    swiftSettings: strictConcurrencySettings
  ),
  .target(
    name: "DaemonFeatureContracts",
    dependencies: [],
    path: "Packages/DaemonFeatureContracts/Sources",
    swiftSettings: strictConcurrencySettings
  ),
  .target(
    name: "DaemonKernel",
    dependencies: ["DaemonFeatureContracts"],
    path: "Packages/DaemonKernel/Sources",
    swiftSettings: strictConcurrencySettings
  ),
  .target(
    name: "ModelRegistryDaemonFeature",
    dependencies: ["DaemonFeatureContracts", "ModelRegistry"],
    path: "Packages/ModelRegistryDaemonFeature/Sources",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "DaemonStatusDaemonFeature",
    dependencies: ["DaemonFeatureContracts"],
    path: "Packages/DaemonStatusDaemonFeature/Sources",
    swiftSettings: strictConcurrencySettings
  ),
  .target(
    name: "ModelRegistry",
    dependencies: ["IntelligenceContracts", "FoundationContracts", "DatabaseCore"],
    path: "Packages/ModelRegistry/Sources",
    exclude: [
      "CLI",
      "CoreMLConversionPipelineDemo.swift",
      "CoreMLVerificationDemo.swift",
      "ModelRegistryTests.swift",
      "ModelDeterminismHarness.swift",
      "ModelGovernanceService.swift",
      "ModelRegistry+Events.swift",
      "PolicyDemo.swift",
      "PolicyIntegrationTest.swift",
      "SimplePolicyTest.swift"
    ],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "CapabilityCore", dependencies: ["AnigmaPrimitives", "AnigmaCore"],
    path: "Packages/CapabilityCore",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "DoctrineCore", dependencies: [], path: "Packages/DoctrineCore",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "TelemetryCore", dependencies: ["AnigmaPrimitives", "CapsuleCore"],
    path: "Packages/TelemetryCore",
    exclude: ["Package.swift.backup"],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "SaturationKitCore",
    dependencies: ["AnigmaPrimitives", "AnigmaNativeShims"],
    path: "Packages/SaturationKit/Sources/SaturationKit",
    exclude: [
      "BinaryAtlasStandard.swift",
      "DSLMemoryBridge.swift",
      "MetalBlake3Compression.swift",
      "MetalSaturatedSearchMegakernel.swift",
      "SaturatedHeartbeatPacket.swift",
      "SaturatedLoggingRing.swift",
      "SaturatedSearch.metal",
      "SaturationKitExports.swift",
      "SearchMegakernel.swift",
      "TextProjection.swift"
    ],
    sources: [
      "Blake3CompressionCore.swift",
      "Blake3Digest.swift",
      "LanePriorityScheduler.swift",
      "WriteCombineBuffer.swift",
    ],
    swiftSettings: strictConcurrencySettings
  ),
  .target(
    name: "SaturationKit",
    dependencies: ["SaturationKitCore", "AnigmaPrimitives"],
    path: "Packages/SaturationKit/Sources/SaturationKit",
    exclude: [
      "Blake3CompressionCore.swift",
      "Blake3Digest.swift",
      "LanePriorityScheduler.swift",
      "WriteCombineBuffer.swift"
    ],
    resources: [.copy("SaturatedSearch.metal")],
    swiftSettings: strictConcurrencySettings,
    linkerSettings: [.linkedFramework("Metal")]
  ),
  .target(
    name: "ExecutionCore",
    dependencies: [
      "TelemetryCore", "AnigmaPrimitives", "MLWorkerCommon", "DatabaseCore", "HardwareAuthorityContracts"
    ], path: "Packages/ExecutionCore",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "InferenceCore", dependencies: ["IntelligenceContracts", "FoundationContracts"],
    path: "Packages/InferenceCore",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "InferenceContracts",
    dependencies: [],
    path: "Packages/InferenceContracts/Sources/InferenceContracts",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "SaturationInferenceCore",
    dependencies: ["InferenceContracts"],
    path: "Packages/SaturationInferenceCore/Sources/SaturationInferenceCore",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: [
      .linkedFramework("Metal"),
      .linkedFramework("Accelerate"),
    ]),
  .target(
    name: "SaturatedModelRegistry",
    dependencies: ["InferenceContracts", "SaturationInferenceCore"],
    path: "Packages/SaturatedModelRegistry/Sources/SaturatedModelRegistry",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: [
      .linkedFramework("Metal"),
      .linkedFramework("Accelerate"),
    ]),
  .target(
    name: "CanonicalTokenizer",
    dependencies: [
      "FoundationContracts", .product(name: "Crypto", package: "swift-crypto"),
      .product(name: "Numerics", package: "swift-numerics")
    ], path: "Packages/CanonicalTokenizer",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "GovernanceCore",
    dependencies: [
      "AnigmaPrimitives", "DatabaseCore", "GovernanceContracts", "FoundationContracts",
      "MessagingContracts",
      .product(name: "Toml", package: "swift-toml")
    ], path: "Packages/GovernanceCore",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "StorageCore",
    dependencies: [
      "DatabaseCore", "GovernanceCore", "AnigmaPrimitives", "FoundationContracts",
      "GovernanceContracts"
    ], path: "Packages/StorageCore",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "GovernedMigrationCore",
    dependencies: ["DoctrineCore", "SecurityEventsManager", "DatabaseCore"],
    path: "Packages/GovernedMigrationCore",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaASTServicesCore",
    dependencies: [
      "AnigmaPrimitives", .product(name: "SwiftSyntax", package: "swift-syntax"),
      .product(name: "SwiftParser", package: "swift-syntax")
    ], path: "Packages/AnigmaASTServices", exclude: ["main.swift"],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "SecurityEventsManager", dependencies: ["SecurityEventsContracts"],
    path: "Packages/SecurityEventsManager",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaClientKit", dependencies: ["FoundationContracts", "ContractsCore"],
    path: "Packages/AnigmaClientKit",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaSidecar",
    dependencies: [
      "AnigmaPrimitives", "AnigmaNativeShims",
      .product(name: "AsyncHTTPClient", package: "async-http-client")
    ], path: "Packages/AnigmaSidecar",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaSystemSpine", dependencies: [], path: "Packages/AnigmaSystemSpine",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "DataCore", dependencies: ["AnigmaPrimitives"], path: "Packages/DataCore",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "DataEngine",
    dependencies: ["DataCore", "AnigmaPrimitives", "AnigmaSystemSpine", "AnigmaEvents"],
    path: "Packages/DataEngine",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "RendererKit",
    dependencies: ["DataCore", "CapsuleCore", "AnigmaEvents"],
    path: "Packages/RendererKit",
    exclude: [
      "Renderer.swift",
      "DataGridRenderer.swift",
      "ProfilerRenderer.swift",
      "Sources/RendererKit/OpenGLRenderer.swift"
    ],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "DataUI", dependencies: ["DataCore", "DataEngine", "RendererKit", "AnigmaClientKit"],
    path: "Packages/DataUI",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "HardwareAuthorityContracts", dependencies: ["AnigmaPrimitives"],
    path: "Packages/HardwareAuthorityContracts",
    swiftSettings: strictConcurrencySettings),
  .target(
    name: "HardwareAuthority", dependencies: ["AnigmaPrimitives", "HardwareAuthorityContracts"],
    path: "Packages/HardwareAuthority",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaTUI", dependencies: [], path: "Packages/AnigmaTUI/Sources/AnigmaTUI",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "Workflows",
    dependencies: ["DataCore", "DataEngine", "AnigmaSystemSpine", "AnigmaEvents"],
    path: "Packages/Workflows",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "ExportCore",
    dependencies: ["AnigmaSystemSpine", "DataCore", "AnigmaEvents", "AnigmaNativeShims"],
    path: "Packages/ExportCore",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "ExportUI",
    dependencies: ["ExportCore", "AnigmaSystemSpine", "DataCore", "AnigmaEvents"],
    path: "Packages/ExportUI",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaWork",
    dependencies: [
      "AnigmaCore", "DataCore", "DataEngine", "AnigmaSystemSpine", "ExportCore", "RendererKit",
      "AnigmaEvents"
    ], path: "Packages/AnigmaWork",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaCorporate",
    dependencies: ["AnigmaCore", "HarmoniaV2Surface", "AnigmaSystemSpine", "ContextumModule"],
    path: "Packages/AnigmaCorporate",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaEducation", dependencies: ["AnigmaCore", "AnigmaSystemSpine"],
    path: "Packages/AnigmaEducation",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaAgents",
    dependencies: [
      "AnigmaCore", "AnigmaSystemSpine", "DataCore", "DataEngine", "AnigmaEvents",
      "AnigmaCorporate", "AnigmaEducation", "HarmoniaV2Surface", "PraxisCore"
    ], path: "Packages/AnigmaAgents",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaAIConsole",
    dependencies: ["AnigmaCore", "AnigmaSystemSpine", "AnigmaAgents", "DataCore"],
    path: "Packages/AnigmaAIConsole",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "DocumentIRKit", dependencies: ["TelemetryCore", "AnigmaPrimitives"],
    path: "Packages/DocumentIRKit",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "ContainerKit",
    dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "TelemetryCore"],
    path: "Packages/ContainerKit",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "OOXMLKit", dependencies: ["ContainerKit", "AnigmaNativeShims", "AnigmaPrimitives"],
    path: "Packages/OOXMLKit",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "DocumentRenderKit",
    dependencies: [
      "DataCore", "AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "TelemetryCore",
      "DocumentIRKit", "RenderPlanCapsule"
    ], path: "Packages/DocumentRenderKit",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "TypographyKit", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore"],
    path: "Packages/TypographyKit",
    exclude: [
      "Sources/TypographyKit/FontMetrics.swift", "Sources/TypographyKit/GlyphInfo.swift",
      "Sources/TypographyKit/TextShaper.swift"
    ], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "TextRenderKit",
    dependencies: [
      "AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "RendererKit", "SaturationKit",
      "CHarfBuzz"
    ],
    path: "Anigma/Packages/TextRenderKit",
    exclude: [
      "Sources/TextRenderKit/Rasterization/Rasterizer.swift",
      "Sources/TextRenderKit/TextRenderOptimizer.swift",
      
    ],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "ColorKit", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives"],
    path: "Packages/ColorKit",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "ANEServicesCore", dependencies: [],
    path: "Packages/ANEServicesCore/Sources/ANEServicesCore",
    swiftSettings: strictConcurrencySettings),
  .target(
    name: "ANECapsuleContracts",
    dependencies: ["ANEServicesCore"],
    path: "Packages/ANECapsuleContracts/Sources/ANECapsuleContracts",
    swiftSettings: strictConcurrencySettings
  ),
  .target(
    name: "ANECapabilityCatalog",
    dependencies: ["ANECapsuleContracts", "ANEServicesCore", "CapsuleCore"],
    path: "Packages/ANECapabilityCatalog/Sources/ANECapabilityCatalog",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "ANEExecutionReceipts",
    dependencies: ["ANECapsuleContracts", "ANEServicesCore", "CapsuleCore", "AnigmaPrimitives"],
    path: "Packages/ANEExecutionReceipts/Sources/ANEExecutionReceipts",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "ANEPlacementCoreML",
    dependencies: [
      "ANECapsuleContracts", "ANECapabilityCatalog", "ANEServicesCore", "CapsuleCore"
    ],
    path: "Packages/ANEPlacementCoreML/Sources/ANEPlacementCoreML",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "ANECapsuleIntegrationInternal",
    dependencies: ["ANECapsuleContracts", "CapsuleCore", "ANEServicesCore", "TelemetryCore"],
    path: "Packages/ANECapsuleIntegration/Sources/ANECapsuleIntegrationInternal",
    swiftSettings: [.unsafeFlags(["-strict-concurrency=minimal"]), .interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "ANECapsuleIntegration",
    dependencies: [
      "ANECapsuleContracts",
      "ANECapabilityCatalog",
      "ANEExecutionReceipts",
      "ANEPlacementCoreML",
      "ANECapsuleIntegrationInternal",
      "CapsuleCore",
      "AnigmaPrimitives",
      "ANEServicesCore",
      "TelemetryCore"
    ],
    path: "Packages/ANECapsuleIntegration/Sources/ANECapsuleIntegration",
    exclude: ["ANECapsuleIntegrationStub.swift"],
    swiftSettings: [
      .unsafeFlags(["-strict-concurrency=minimal", "-Onone"]), .interoperabilityMode(.Cxx)
    ]
  ),
  .target(
    name: "TessellationCapsule", dependencies: ["CapsuleCore"],
    path: "Packages/TessellationCapsule/Sources/TessellationCapsule",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "VectorOpsKit",
    dependencies: [
      "AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "VectorNative",
      "ANECapsuleIntegration", "ANEServicesCore"
    ],
    path: "Packages/VectorOpsKit",
    exclude: [
      "Sources/VectorOpsKit/VectorIndexCapsuleANE.swift",
      "Sources/VectorOpsKit/VectorCapsuleWrapper.swift"
    ],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: [.linkedFramework("Metal")]
  ),
  .target(
    name: "CapsuleCore", dependencies: ["AnigmaPrimitives", "AnigmaNativeShims"],
    path: "Packages/CapsuleCore/Sources/CapsuleCore", exclude: ["CapsuleErrorAssertions.swift"],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "CompressionKit",
    dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore"],
    path: "Packages/CompressionKit/Sources/CompressionKit",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "GeometryCapsule",
    dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "GeometryNative"],
    path: "Packages/GeometryCapsule/Sources/GeometryCapsule",
    exclude: ["GeometryCapsule.swift", "GeometryCapsuleInternal.swift"],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "TextChunkingCapsule",
    dependencies: [
      "AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "TextChunkingNative", "TelemetryCore"
    ], path: "Packages/TextChunkingCapsule/Sources/TextChunkingCapsule",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "LayoutEngineCapsule",
    dependencies: [
      "AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "TelemetryCore", "LayoutEngineNative",
      "PDFNative"
    ], path: "Packages/LayoutEngineCapsule/Sources/LayoutEngineCapsule",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "LayoutEngineContracts",
    dependencies: [
      "AnigmaPrimitives",
      "FoundationContracts",
      "EvidenceContracts"
    ],
    path: "Packages/LayoutEngineContracts/Sources/LayoutEngineContracts",
    swiftSettings: strictConcurrencySettings
  ),
  .target(
    name: "PDFLayoutExtract",
    dependencies: [
      "AnigmaFoundation",
      "AnigmaGovernance",
      "AnigmaJobs",
      "AnigmaPrimitives",
      "InferenceCore",
      "LayoutEngineContracts",
      "LayoutEngineCapsule",
      "FoundationContracts",
      "EvidenceContracts"
    ],
    path: "Packages/PDFLayoutExtract/Sources/PDFLayoutExtract",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "VizAggregationCapsule",
    dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "VizAggregationNative"],
    path: "Packages/VizAggregationCapsule/Sources/VizAggregationCapsule",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "MediaFingerprintCapsule",
    dependencies: [
      "AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "MediaFingerprintNative",
      "TelemetryCore", "ANECapsuleIntegration", "ANEServicesCore"
    ],
    path: "Packages/MediaFingerprintCapsule/Sources/MediaFingerprintCapsule",
    exclude: [
      "MediaFingerprintCapsuleStub.swift",
      "MediaFingerprintCapsuleWrapper.swift",
      "MediaFingerprintNativeBridge.swift",
      "MediaFingerprintTypes.swift",
      
    ],
    swiftSettings: [.unsafeFlags(["-strict-concurrency=minimal"]), .interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "MediaContainerCapsule",
    dependencies: ["AnigmaPrimitives", "CapsuleCore", "MediaContainerNative", "AnigmaNativeShims"],
    path: "Packages/MediaContainerCapsule/Sources/MediaContainerCapsule",
    exclude: ["MediaContainerCapsuleInternal.swift"],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "VectorCapsule",
    dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "VectorNative"],
    path: "Packages/VectorCapsule/Sources/VectorCapsule",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "TextPipelineCapsule",
    dependencies: [
      "AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "TextPipelineNative", "TelemetryCore",
      "ANECapsuleIntegration", "ANEServicesCore"
    ],
    path: "Packages/TextPipelineCapsule/Sources/TextPipelineCapsule",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "VectorIndexCapsule",
    dependencies: [
      "AnigmaPrimitives", "CapsuleCore", "TelemetryCore", "AnigmaNativeShims", "SaturationKit", "VectorIndexNative"
    ], path: "Packages/VectorIndexCapsule/Sources/VectorIndexCapsule",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "CosineSimilarityCapsule",
    dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "CosineNative"],
    path: "Packages/CosineSimilarityCapsule/Sources/CosineSimilarityCapsule",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "RankFusionCapsule",
    dependencies: [
      "AnigmaNativeShims", "AnigmaPrimitives", "CapsuleCore", "TelemetryCore", "RankFusionNative"
    ], path: "Packages/RankFusionCapsule/Sources/RankFusionCapsule",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "SceneGraphCapsule",
    dependencies: ["AnigmaPrimitives", "CapsuleCore", "SceneGraphNative", "AnigmaNativeShims", "TelemetryCore"],
    path: "Packages/SceneGraphCapsule/Sources/SceneGraphCapsule",
    exclude: ["SceneGraphCapsuleANE.swift"],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "RenderIntentCapsule",
    dependencies: [
      "AnigmaPrimitives", "CapsuleCore", .product(name: "Crypto", package: "swift-crypto")
    ], path: "Packages/RenderIntentCapsule/Sources/RenderIntentCapsule",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "RenderGraphCapsule",
    dependencies: ["AnigmaPrimitives", "CapsuleCore", "RenderIntentCapsule", "TelemetryCore"],
    path: "Packages/RenderGraphCapsule/Sources/RenderGraphCapsule",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "RenderBackendCapsule",
    dependencies: [
      "AnigmaPrimitives", "CapsuleCore", "RenderIntentCapsule", "RenderGraphCapsule",
      "TelemetryCore", "StorageCore", "SceneGraphCapsule", "HitTestCapsule"
    ], path: "Packages/RenderBackendCapsule/Sources/RenderBackendCapsule",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: [
      .linkedFramework("Metal"), .linkedFramework("MetalKit"), .linkedFramework("CoreGraphics"),
      .linkedFramework("CoreText")
    ]),
  .target(
    name: "RenderPlanCapsule",
    dependencies: [
      "AnigmaPrimitives", "CapsuleCore", "SceneGraphCapsule", "RenderPlanNative",
      "AnigmaNativeShims"
    ], path: "Packages/RenderPlanCapsule/Sources/RenderPlanCapsule",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "HitTestCapsule",
    dependencies: ["SceneGraphCapsule", "HitTestNative", "AnigmaNativeShims"],
    path: "Packages/HitTestCapsule/Sources/HitTestCapsule",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnimationKit",
    dependencies: [
      "AnigmaNativeShims", "AnigmaPrimitives", "AnimationNative", "CapsuleCore", "VectorOpsKit"
    ],
    path: "Packages/AnimationKit/Sources/AnimationKit",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "ObservabilityKit", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives"],
    path: "Packages/ObservabilityKit",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "SidecarOfficeService", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives"],
    path: "Packages/SidecarOfficeService",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "SidecarPDFService", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives", "PDFNative"],
    path: "Packages/SidecarPDFService/Sources/SidecarPDFService",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "PDFSidecarClient", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives"],
    path: "Packages/SidecarPDFService/Sources/PDFSidecarClient",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .executableTarget(
    name: "PDFSidecarExecutable", dependencies: ["PDFSidecarClient", "SidecarPDFService", "PDFNative", "AnigmaNativeShims"],
    path: "Packages/SidecarPDFService/Sources/PDFSidecarExecutable",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),

  // Subprocess Pooling Package (Phase 1-5: td-12f9d2)
  .target(
    name: "SubprocessPooling", dependencies: [],
    path: "Packages/SubprocessPooling/Sources",
    swiftSettings: strictConcurrencySettings),
  .testTarget(
    name: "SubprocessPoolingTests", dependencies: ["SubprocessPooling"],
    path: "Tests/SubprocessPoolingTests",
    swiftSettings: strictConcurrencySettings),

  .target(
    name: "SidecarTranslateService", dependencies: ["AnigmaNativeShims", "AnigmaPrimitives"],
    path: "Packages/SidecarTranslateService",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  // .target(name: "PDFExporterKit", dependencies: ["AnigmaPrimitives", "CapsuleCore", "DocumentIRKit", "LayoutEngineCapsule", "TelemetryCore", "TableExtractionCapsule", "MathOCRCapsule", "CitationExtractionCapsule", "ReferenceResolutionCapsule", "DiffCapsule"], path: "Packages/PDFExporterKit/Sources/PDFExporterKit", exclude: ["Artifacts", "LayoutAnalyzerCapsule.swift", "PDFExporterKit.swift"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  // .target(name: "BookAssemblerCapsule", dependencies: ["AnigmaPrimitives", "CapsuleCore", "DocumentIRKit", "TelemetryCore", "PDFExporterKit", "ChunkNormalizerCapsule"], path: "Packages/BookAssemblerCapsule/Sources/BookAssemblerCapsule", exclude: ["BookAssemblerCapsule.swift", "BookAssemblerConfig.swift"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  // .target(name: "ChunkNormalizerCapsule", dependencies: ["AnigmaPrimitives", "CapsuleCore", "DocumentIRKit", "TelemetryCore", "PDFExporterKit", "TextChunkingCapsule"], path: "Packages/ChunkNormalizerCapsule/Sources/ChunkNormalizerCapsule", exclude: ["ChunkNormalizerCapsule.swift", "ChunkNormalizerConfig.swift"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  // .target(name: "BookExportCapsule", dependencies: ["AnigmaPrimitives", "CapsuleCore", "PDFExporterKit", "BookAssemblerCapsule", "ChunkNormalizerCapsule", "LayoutEngineCapsule", "TelemetryCore"], path: "Packages/BookExportCapsule/Sources/BookExportCapsule", exclude: ["BookExportCapsule.swift"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),

  // Advanced Document Processing Capsules
  // .target(name: "TableExtractionCapsule", dependencies: ["AnigmaPrimitives", "CapsuleCore", "TelemetryCore", "LayoutEngineCapsule", "TableExtractionNative", "AnigmaNativeShims"], path: "Packages/TableExtractionCapsule/Sources/TableExtractionCapsule", exclude: ["TableExtractionCapsuleStub.swift"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  // .target(name: "MathOCRCapsule", dependencies: ["AnigmaPrimitives", "CapsuleCore", "TelemetryCore", "LayoutEngineCapsule", "MathOCRNative", "AnigmaNativeShims"], path: "Packages/MathOCRCapsule/Sources/MathOCRCapsule", exclude: ["MathOCRCapsule.swift"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  // .target(name: "CitationExtractionCapsule", dependencies: ["AnigmaPrimitives", "CapsuleCore", "TelemetryCore", "LayoutEngineCapsule", "CitationExtractionNative", "AnigmaNativeShims"], path: "Packages/CitationExtractionCapsule/Sources/CitationExtractionCapsule", exclude: ["CitationExtractionCapsule.swift"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  // .target(name: "ReferenceResolutionCapsule", dependencies: ["AnigmaPrimitives", "CapsuleCore", "TelemetryCore", "LayoutEngineCapsule", "CitationExtractionCapsule", "ReferenceResolutionNative", "AnigmaNativeShims"], path: "Packages/ReferenceResolutionCapsule/Sources/ReferenceResolutionCapsule", exclude: ["ReferenceResolutionCapsule.swift"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  // .target(name: "DiffCapsule", dependencies: ["AnigmaPrimitives", "CapsuleCore", "TelemetryCore", "LayoutEngineCapsule", "DiffNative", "AnigmaNativeShims"], path: "Packages/DiffCapsule/Sources/DiffCapsule", exclude: ["DiffCapsule.swift"], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),

  .target(
    name: "AnigmaHostKit",
    dependencies: [
      "AnigmaClientKit", "AnigmaCore", "AnigmaPrimitives", "ContractsCore", "AnigmaDaemonCore",
      "AnigmaSidecar"
    ], path: "Packages/AnigmaHostKit",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaHostMac",
    dependencies: [
      "AnigmaClientKit", "AnigmaHostKit", "ContractsCore", "AnigmaSidecar", "AnigmaDaemonCore",
      "AnigmaASTServicesCore", "AnigmaPrimitives",
      .product(name: "Crypto", package: "swift-crypto"), "SyntaxCapsule"
    ], path: "Packages/AnigmaHostMac",
    resources: [.copy("Resources/Monaco/placeholder.txt")],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "MLWorkerCommon",
    dependencies: [
      "AnigmaCore", "ContractsCore",
      .product(name: "ArgumentParser", package: "swift-argument-parser"),
      .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
      .product(name: "MLXEmbedders", package: "mlx-swift-lm")
    ], path: "Packages/MLWorkerCommon",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "TechDebtAudit", dependencies: [], path: "Packages/TechDebtAudit",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "PlatformCore", dependencies: ["AnigmaCore", "CapabilityCore", "ContractsCore"],
    path: "Packages/PlatformCore",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaDaemonCore",
    dependencies: [
      "AnigmaCore", "AnigmaPipeline", "DatabaseCore", "ExecutionCore", "GovernanceCore",
      "StorageCore", "TelemetryCore", "ContractsCore", "MLWorkerCommon", "MLWorkerInterfaces",
      "AnigmaPrimitives", "AnigmaEvents", "AnigmaASTServicesCore", "TextChunkingCapsule",
      "LayoutEngineCapsule", "VectorCapsule", "VectorIndexCapsule", "RankFusionCapsule",
      "ContextumModule", "InferenceCore", "SyntaxCapsule", "TechDebtAudit", "DiaplasionModule",
      "OutlineumModule", "HarmoniaV2Surface", "RLMModule", "CathedralModule", "ModelRegistry",
      "ModelRegistryModule", "VectorumModule", "DataEngine", "ExportCore", "AnigmaAgents",
      "AnigmaSystemSpine", "AnigmaMCPModule", "CodexModule", "TranscriptumModule",
      "SubprocessPooling",
      .product(name: "MCP", package: "swift-sdk"),
      .product(name: "Hummingbird", package: "hummingbird"),
      .product(name: "HummingbirdTLS", package: "hummingbird")
    ], path: "Packages/AnigmaDaemonCore",
    exclude: ["Protos/anigma.capnp"],
    resources: [.copy("Protos/anigma.proto")],
    swiftSettings: [.unsafeFlags(["-strict-concurrency=minimal"]), .interoperabilityMode(.Cxx)]),
  .target(
    name: "RuntimeOrchestrator",
    dependencies: ["AnigmaNativeShims", "NativeKernel", "SceneGraphCapsule"],
    path: "Sources/RuntimeOrchestrator",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
      + debugPerformanceSettings
  ),
  .target(
    name: "PlatformAdapters",
    dependencies: ["RuntimeOrchestrator", "AnigmaNativeShims"],
    path: "Sources/PlatformAdapters",
    resources: [.copy("Shaders.metal")],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
      + debugPerformanceSettings
  ),
  // Canonical UI implementation lives under Sources/AnigmaUI.
  // Legacy tree Packages/AnigmaUI is intentionally unbound.
  // .target(
  //   name: "AnigmaUI",
  //   dependencies: ["PlatformAdapters", "RuntimeOrchestrator"],
  //   path: "Sources/AnigmaUI",
  //   swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  //     + debugPerformanceSettings,
  //   linkerSettings: [
  //     .linkedFramework("SwiftUI"),
  //     .linkedFramework("CoreAudio")
  //   ]
  // )
  .target(
    name: "GoldenKit", dependencies: ["ContractsCore"], path: "Packages/AnigmaTestSupport/Sources/GoldenKit",
    exclude: [],
    swiftSettings: strictConcurrencySettings),
  .target(
    name: "AnigmaTestSupport",
    dependencies: [
      "GoldenKit", "AnigmaCore", "AnigmaPrimitives", "ContractsCore", "DatabaseCore",
      "PolytroposModule"
    ], path: "Packages/AnigmaTestSupport/Sources/AnigmaTestSupport",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaCLICore", dependencies: ["ContractsCore", "AnigmaCore"],
    path: "Packages/AnigmaCLI/Core", exclude: ["CLIAnalyticsTests.swift"],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaCLIEventing", dependencies: ["AnigmaCLICore"], path: "Packages/AnigmaCLI/Eventing",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaCLIProviders",
    dependencies: ["AnigmaCLICore", "AnigmaCLIDatabase", "ContractsCore"],
    path: "Packages/AnigmaCLI/Providers",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaCLIRouter", dependencies: ["AnigmaCLICore", "AnigmaCLIProviders"],
    path: "Packages/AnigmaCLI/Router",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaCLIGovernance", dependencies: ["AnigmaCLICore", "AnigmaCLIProviders"],
    path: "Packages/AnigmaCLI/Governance",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaCLIOrchestrator",
    dependencies: [
      "AnigmaCLICore", "AnigmaCLIEventing", "AnigmaCLIGovernance", "AnigmaCLIProviders",
      "AnigmaCLIRouter"
    ], path: "Packages/AnigmaCLI/Orchestrator", exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaCLIOnboarding",
    dependencies: [
      "AnigmaCLICore", "AnigmaCLIDatabase", "AnigmaCLIProviders", "AnigmaCLIML", "DatabaseCore",
      "ModelManagement"
    ], path: "Packages/AnigmaCLI/Onboarding",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaCLIDatabase",
    dependencies: [
      "AnigmaCLICore", "TextChunkingCapsule", "CanonicalTokenizer",
      .product(name: "Crypto", package: "swift-crypto")
    ], path: "Packages/AnigmaCLI/Database", exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaCLIRAG", dependencies: ["AnigmaCLIDatabase"], path: "Packages/AnigmaCLI/RAG",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaCLIML",
    dependencies: [
      "AnigmaCLICore", "AnigmaCLIDatabase", "AnigmaCLIMLIntegration", "AnigmaCLIProviders",
      "AnigmaCLILocalInference", "AnigmaCLIRAG"
    ], path: "Packages/AnigmaCLI/ML",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaCLIUI", dependencies: [], path: "Packages/AnigmaCLI/UI",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaCLITUI",
    dependencies: [
      "AnigmaCLICore", "AnigmaCLIEventing", "AnigmaCLIDatabase", "AnigmaCLIML", "AnigmaTUI",
      "AnigmaSidecar", "AnigmaEvents"
    ], path: "Packages/AnigmaCLI/Sources/TUI",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaCLIMLIntegration", dependencies: [], path: "Packages/AnigmaCLI/MLIntegration",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaCLIMCP",
    dependencies: [
      "AnigmaCLICore", "AnigmaPrimitives", "ContractsCore", "AnigmaCLIEventing",
      "AnigmaCLIGovernance"
    ], path: "Packages/AnigmaCLIMCP", exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "RLMModule",
    dependencies: [
      "AnigmaCore", "AnigmaPrimitives", "DatabaseCore", "ContextumModule", "ArtifactStoreModule",
      "HarmoniaV2Surface", "VectorIndexCapsule", "VectorOpsKit", "TextPipelineCapsule",
      "TextChunkingCapsule", "CapsuleCore", "InferenceCore", "VizAggregationCapsule",
      "MediaContainerCapsule", "MediaFingerprintCapsule", "CosineSimilarityCapsule",
      "RankFusionCapsule", "CompressionKit", "CapabilityCore"
    ], path: "Sources/RLMModule",
    exclude: ["ContextEnvironment.swift.new"],
    swiftSettings: [.unsafeFlags(["-strict-concurrency=minimal"]), .interoperabilityMode(.Cxx)]),
  .target(
    name: "ModelManagement",
    dependencies: [
      "AnigmaCore", "AnigmaSidecar", .product(name: "Crypto", package: "swift-crypto")
    ], path: "Packages/AnigmaCLI/Sources/ModelManagement",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaCLILocalInference",
    dependencies: [
      "InferenceCore", .product(name: "MLX", package: "mlx-swift"),
      .product(name: "MLXNN", package: "mlx-swift"),
      .product(name: "MLXRandom", package: "mlx-swift"),
      .product(name: "MLXOptimizers", package: "mlx-swift"),
      .product(name: "MLXLMCommon", package: "mlx-swift-lm")
    ], path: "Packages/AnigmaCLI/Sources/LocalInference", exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "PraxisCore", dependencies: ["AnigmaPrimitives", "AnigmaNativeShims"], path: "Packages/PraxisCore",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "PraxisModule", dependencies: ["PraxisCore", "ContractsCore"],
    path: "Packages/PraxisModule",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
]

let moduleTargets: [Target] = [
  .target(
    name: "MediaCore",
    dependencies: [
      "ContractsCore",
      "MediaPipelineContracts",
      "GovernanceCore",
      "SaturationKit",
      "AnigmaFoundation"
    ],
    path: "Sources/MediaCore",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: [
      .linkedFramework("Metal"),
      .linkedFramework("MetalPerformanceShaders"),
      .linkedFramework("CoreVideo"),
      .linkedFramework("CoreGraphics"),
      .linkedFramework("ImageIO"),
      .linkedFramework("AVFoundation")
    ]
  ),
  .target(
    name: "MessagingContracts",
    dependencies: [
      "FoundationContracts",
      "AnigmaPrimitives"
    ],
    path: "Packages/ContractsCore/Sources/MessagingContracts",
    swiftSettings: strictConcurrencySettings
  ),
  .target(
    name: "MediaPipelineContracts",
    dependencies: ["ContractsCore", "FoundationContracts"],
    path: "Packages/ContractsCore/Sources/MediaPipelineContracts"
  ),
  .target(
    name: "RendererBackendContracts",
    dependencies: [],
    path: "Packages/RendererBackendContracts/Sources/RendererBackendContracts",
    swiftSettings: strictConcurrencySettings
  ),
  .target(
    name: "HarmoniaWorkflowContracts",
    dependencies: ["AnigmaPrimitives", "AnigmaNativeShims"],
    path: "Packages/HarmoniaWorkflowContracts/Sources/HarmoniaWorkflowContracts",
    swiftSettings: strictConcurrencySettings
  ),
  .target(
    name: "HarmoniaAPIContracts",
    dependencies: ["HarmoniaWorkflowContracts"],
    path: "Packages/HarmoniaAPIContracts/Sources/HarmoniaAPIContracts",
    swiftSettings: strictConcurrencySettings
  ),
  .target(
    name: "HarmoniaInferenceContracts",
    dependencies: ["AnigmaCore"],
    path: "Packages/HarmoniaInferenceContracts/Sources/HarmoniaInferenceContracts",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "HarmoniaCLIIntegration",
    dependencies: [
      "AnigmaCLIProviders", "AnigmaCLIRouter", "AnigmaCLIOrchestrator", "AnigmaCLIEventing",
      "AnigmaCLIGovernance"
    ],
    path: "Packages/HarmoniaCLIIntegration/Sources/HarmoniaCLIIntegration",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "HarmoniaContractsIntegration",
    dependencies: [
      "HarmoniaAPIContracts", "HarmoniaInferenceContracts", "HarmoniaWorkflowContracts",
      "HarmoniaV2Surface"
    ],
    path: "Packages/HarmoniaContractsIntegration/Sources/HarmoniaContractsIntegration",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "HarmoniaDataIntegration",
    dependencies: ["DatabaseCore", "StorageCore", "DataCore", "GovernedMigrationCore"],
    path: "Packages/HarmoniaDataIntegration/Sources/HarmoniaDataIntegration",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "HarmoniaANEIntegration",
    dependencies: ["ANECapsuleIntegration", "ANEServicesCore"],
    path: "Packages/HarmoniaANEIntegration/Sources/HarmoniaANEIntegration",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  // HarmoniaV2 - Modular replacement (0 errors, 19/19 tests passing)
  .target(
    name: "HarmoniaV2Core",
    dependencies: ["AnigmaFoundation"],
    path: "Packages/HarmoniaV2/HarmoniaCore/Sources",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "HarmoniaV2Inference",
    dependencies: ["HarmoniaV2Core"],
    path: "Packages/HarmoniaV2/HarmoniaInference/Sources",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "HarmoniaV2Memory",
    dependencies: ["HarmoniaV2Core"],
    path: "Packages/HarmoniaV2/HarmoniaMemory/Sources",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "HarmoniaV2Orchestration",
    dependencies: ["HarmoniaV2Core", "HarmoniaV2Inference", "HarmoniaV2Memory"],
    path: "Packages/HarmoniaV2/HarmoniaOrchestration/Sources",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  // HarmoniaV2Contracts - Lightweight contracts module with minimal dependencies
  .target(
    name: "HarmoniaV2Contracts",
    dependencies: [],
    path: "Packages/HarmoniaV2/HarmoniaContracts/Sources",
    swiftSettings: strictConcurrencySettings
  ),

  // Canonical Harmonia surface lives in the V2 tree below.
  // Legacy tree Packages/HarmoniaSurface is intentionally unbound.
  .target(
    name: "HarmoniaV2Surface",
    dependencies: [
      "HarmoniaV2Core",
      "HarmoniaV2Inference",
      "HarmoniaV2Memory",
      "HarmoniaV2Orchestration",
      "HarmoniaV2Contracts",
      "InferenceCore",
      "AnigmaCore",
      "AnigmaFoundation",
      "AnigmaPrimitives",
      "AnigmaEvents",
      "TelemetryCore",
      "GovernanceCore",
      "DatabaseCore",
      "ContractsCore",
      "ContextumModule",
      "DiaplasionModule"
    ],
    path: "Packages/HarmoniaV2/HarmoniaSurface/Sources",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  // Stable executable-facing facade for the harmonia CLI.
  .target(
    name: "HarmoniaRuntime",
    dependencies: [
      "AnigmaPrimitives", "ExecutionCore", "TelemetryCore", "HarmoniaV2Contracts",
      "HarmoniaV2Surface"
    ],
    path: "Packages/HarmoniaRuntime/Sources",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "HarmoniaMemory",
    dependencies: ["AnigmaCore", "TelemetryCore", "DatabaseCore", "AnigmaPrimitives"],
    path: "Packages/HarmoniaMemory",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "DiaplasionModule",
    dependencies: ["AnigmaCore", "AnigmaPipeline", "TextChunkingCapsule"],
    path: "Packages/DiaplasionModule",
    exclude: ["DiaplasionModuleStub.swift", "TestFiles"],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: [
      .linkedFramework("CoreAudio")
    ]
  ),
  .target(
    name: "AccessumModule",
    dependencies: ["AnigmaCore", "AnigmaPipeline", "ContractsCore", "TelemetryCore"],
    path: "Packages/AccessumModule/Sources/AccessumModule",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "OutlineumModule",
    dependencies: ["AnigmaCore"],
    path: "Packages/OutlineumModule",
    exclude: ["TestFiles"],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "PragmaModule",
    dependencies: ["AnigmaCore"],
    path: "Packages/PragmaModule/Sources/PragmaModule",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "ConexusModule",

    dependencies: ["AnigmaCore"],
    path: "Packages/ConexusModule/Sources/ConexusModule",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "CodexModule", dependencies: ["AnigmaCore"],
    path: "Packages/CodexModule/Sources/CodexModule",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "TranscriptumModule",
    dependencies: ["AnigmaPrimitives", "AnigmaCore", "AnigmaSystemSpine"],
    path: "Packages/TranscriptumModule",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "ObservatoriumModule",
    dependencies: ["AnigmaPrimitives", "AnigmaCore"],
    path: "Packages/ObservatoriumModule",
    exclude: ["ObservatoriumModuleStub.swift", "Components"],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "PolytroposModule",
    dependencies: [
      "AnigmaCore", "AnigmaPrimitives", "MediaContainerCapsule", "ArtifactStoreModule",
      "MediaFingerprintCapsule", "DatabaseCore", "RendererBackendContracts"
    ], path: "Packages/PolytroposModule/Sources/PolytroposModule",
    swiftSettings: [.unsafeFlags(["-strict-concurrency=minimal"]), .interoperabilityMode(.Cxx)]),
  .target(
    name: "VectorumModule", dependencies: ["ContractsCore", "AnigmaCore", "CapabilityCore"],
    path: "Packages/VectorumModule",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "CathedralModule", dependencies: ["AnigmaCore", "DatabaseCore", "ContextumModule"],
    path: "Packages/CathedralModule", exclude: ["CathedralModule.placeholder.swift.backup"],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "ContextumModule",
    dependencies: [
      "AnigmaCore",
      "AnigmaPrimitives",
      "DatabaseCore",
      "ContractsCore",
      "TelemetryCore",
      "CapsuleCore",
      "CanonicalTokenizer",
      "CompressionKit",
      "TextPipelineCapsule",
      "TextChunkingCapsule",
      "VectorCapsule",
      "CosineSimilarityCapsule",
      "RankFusionCapsule",
      "VizAggregationCapsule",
      "MediaFingerprintCapsule",
      "GovernanceCore",
      "InferenceCore",
      "SaturationKit",
      "AnigmaEvents"
    ],
    path: "Sources/ContextumModule",
    exclude: ["ContextumModuleStub.swift"],
    swiftSettings: [.unsafeFlags(["-strict-concurrency=minimal"]), .interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "IntelligenceCore",
    dependencies: ["AnigmaCore", "ContractsCore", "DatabaseCore"],
    path: "Sources/IntelligenceCore",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .testTarget(
    name: "IntelligenceCoreTests",
    dependencies: ["IntelligenceCore", "AnigmaCore", "ContractsCore"],
    path: "Tests/IntelligenceCoreTests",
    exclude: ["SimpleModel.mlmodelc"],
    resources: [.copy("SimpleModel.mlmodel")],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings
  ),
  .target(
    name: "ArtifactStoreModule", dependencies: ["AnigmaCore", "ContractsCore", "DatabaseCore"],
    path: "Sources/ArtifactStoreModule",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "ModelRegistryModule", dependencies: ["AnigmaCore", "ContractsCore", "DatabaseCore"],
    path: "Sources/ModelRegistryModule",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .target(
    name: "AnigmaMCPModule",
    dependencies: [
      "AnigmaCore",
      "AnigmaPrimitives",
      "ContractsCore",
      "HarmoniaV2Surface",
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
      "AnigmaEvents",
      "TelemetryCore",
      .product(name: "MCP", package: "swift-sdk")
    ],
    path: "Sources/AnigmaMCPModule",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .target(
    name: "BenchmarkHarness",
    dependencies: ["CapsuleCore"],
    path: "Anigma/Benchmarks/BenchmarkHarness/Sources/BenchmarkHarness",
    swiftSettings: [swiftLanguageMode, .interoperabilityMode(.Cxx)]
  ),
  // TODO: Fix missing imports and type definitions in BenchmarkSamples
  /*
  .target(
      name: "BenchmarkSamples",
      dependencies: ["BenchmarkHarness", "RendererKit", "AnimationKit"],
      path: "Anigma/Benchmarks/BenchmarkHarness/Sources/BenchmarkSamples",
      swiftSettings: [swiftLanguageMode, .interoperabilityMode(.Cxx)]
  ),
  */
  .target(
    name: "VectorIndexCapsuleBenchmarks",
    dependencies: [
      "BenchmarkHarness",
      "VectorIndexCapsule"
    ],
    path: "Packages/VectorIndexCapsule/Benchmarks",
    swiftSettings: [
      swiftLanguageMode, .interoperabilityMode(.Cxx),
      .unsafeFlags(["-Onone", "-enforce-exclusivity=unchecked"])
    ]
  ),
  .target(
    name: "RankFusionCapsuleBenchmarks",
    dependencies: [
      "BenchmarkHarness",
      "RankFusionCapsule"
    ],
    path: "Packages/RankFusionCapsule/Benchmarks",
    swiftSettings: [
      swiftLanguageMode, .interoperabilityMode(.Cxx),
      .unsafeFlags(["-Onone", "-enforce-exclusivity=unchecked"])
    ]
  ),
  .target(
    name: "TextChunkingCapsuleBenchmarks",
    dependencies: [
      "BenchmarkHarness",
      "TextChunkingCapsule",
      "TextPipelineCapsule"
    ],
    path: "Packages/TextChunkingCapsule/Benchmarks",
    swiftSettings: [
      swiftLanguageMode, .interoperabilityMode(.Cxx),
      .unsafeFlags(["-Onone", "-enforce-exclusivity=unchecked"])
    ]
  ),
  /*
  .target(
      name: "PDFCapsuleBenchmarks",
      dependencies: [
          "BenchmarkHarness",
          "PDFCapsule"
      ],
      path: "Packages/PDFCapsule/Benchmarks",
      swiftSettings: [swiftLanguageMode, .interoperabilityMode(.Cxx), .unsafeFlags(["-Onone", "-enforce-exclusivity=unchecked"])]
  ),
  */
  /*
  .target(
      name: "LayoutEngineCapsuleBenchmarks",
      dependencies: [
          "BenchmarkHarness",
          "LayoutEngineCapsule"
      ],
      path: "Packages/LayoutEngineCapsule/Benchmarks",
      swiftSettings: [swiftLanguageMode, .interoperabilityMode(.Cxx), .unsafeFlags(["-Onone", "-enforce-exclusivity=unchecked"])]
  ),
  */
]

let executableTargets: [Target] = [
  .executableTarget(
    name: "AnigmaMCPExecutable",
    dependencies: [
      "AnigmaSidecar"
    ],
    path: "Sources/AnigmaMCPExecutable",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  // .executableTarget(name: "MLWorkerExecutable", dependencies: ["MLWorkerCommon", "ContractsCore", "AnigmaCore", "AnigmaPrimitives", .product(name: "MLXLMCommon", package: "mlx-swift-lm"), .product(name: "MLXEmbedders", package: "mlx-swift-lm"), .product(name: "ArgumentParser", package: "swift-argument-parser")], path: "Packages/MLWorkerExecutable", exclude: [], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  // Launcher-only app: thin wrapper that launches bundled binaries
  // Updated: Assistant-first launcher surface
  .executableTarget(
    name: "AnigmaAppMacExecutable",
    dependencies: [
      "HarmoniaV2Surface",
      "AnigmaCore",
      "AnigmaHostMac",
      "AnigmaSidecar",
      "SaturationKitCore",
      "ModelManagement",
      "AnigmaAgents",
      "AnigmaAIConsole",
      "AnigmaHostKit",
      "SceneGraphNative",
      "RenderPlanNative",
      "AnigmaWork",
      "RuntimeOrchestrator",
      "PlatformAdapters",
      // "AnigmaUI",
      .product(name: "SwiftUICharts", package: "SwiftUICharts")
    ],
    path: "Sources/AnigmaAppMac",
    exclude: [
      "AnigmaApp.swift.backup",
      "AppState.swift.backup",
      "AppStore.swift.backup",
      "AppStore.swift.bak2",
      "ObservatoriumDashboardView.swift.backup",
      "AssistantIntegrationExample.swift",
      "Transparency/TransparencyIntegrationTest.swift",
      "Stores/analyze_build_errors.py",
      "Stores/build_errors_summary.json",
      "Stores/capture_build_errors.sh",
      "Stores/build_errors_raw.txt",
      "Stores/build_errors_report.txt",
      "Stores/debug_build.sh",
      "Stores/setup_debug_tools.sh",
      "Stores/suggest_fixes.sh",
      "Stores/QUICK_REFERENCE.txt",
    ],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  /*
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
      path: "Anigma/Benchmarks/BenchmarkHarness/Sources/anigma-capsule-bench",
      swiftSettings: [swiftLanguageMode, .interoperabilityMode(.Cxx)]
  ),
  */
  // QUARANTINED LEGACY SURFACE (td-810db3):
  // HarmoniaCLI is archive-only. It imports old HarmoniaModule-facing commands that
  // are not the shipped `harmonia` executable. Do not uncomment this target as a
  // migration shortcut; port individual product intent through HarmoniaRuntime /
  // HarmoniaV2CLI with focused tests.
  /*
  .executableTarget(name: "HarmoniaCLI", dependencies: [
      "AnigmaCLICore", "AnigmaCLIEventing", "AnigmaCLIGovernance", "AnigmaCLIOrchestrator",
      "AnigmaCLIProviders", "AnigmaCLIRouter", "AnigmaCore", "AnigmaPipeline", "ContractsCore",
      "HarmoniaRuntime",  // Stable executable-facing backend facade
      "AccessumModule",
      "DiaplasionModule",
      "HarmoniaV2Core",  // NEW: For ExecutionContext types
      "OutlineumModule",
      "PraxisModule", "PraxisCore", "MLWorkerCommon", "HarmoniaMemory",
      "TechDebtAudit", "ExecutionCore", "StorageCore",
      .product(name: "ArgumentParser", package: "swift-argument-parser")
  ], path: "Packages/HarmoniaCLI", exclude: [
      "DaemonCommand.swift",
      "PrincipalityProjectControllerPreviewCompat.swift",
      "RefactorCommand.swift",
      "ScoutCommands.swift",
      "RealHarnessRunner.swift",
      "SelfHostCommands.swift",
      "Swift6StepCommands.swift",
      "ToolCommand.swift",
      "VaultCommand.swift"
  ], swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
     linkerSettings: [
      .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../../../Vendor/lib"])
     ]),
  */
  // HarmoniaV2CLIKernel - Testable CLI functions (library for testing)
  .target(
    name: "HarmoniaV2CLIKernel",
    dependencies: [
      "HarmoniaV2Core",
      "HarmoniaV2Memory",
      "HarmoniaV2Inference",
      "AnigmaCore",
      "AnigmaFoundation",
      "AnigmaGovernance",
      "AnigmaJobs",
      "DatabaseCore",
      "RuntimeCore",
      "ContractsCore",
      "GovernanceCore"
    ], path: "Packages/HarmoniaV2CLI", exclude: ["CutoverCommands.swift", "Main.swift"],
    sources: ["CLIKernel.swift"],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  // HarmoniaV2CLI - Standalone proof-of-concept (pure V2, no legacy dependencies)
  .executableTarget(
    name: "HarmoniaV2CLI",
    dependencies: [
      "HarmoniaV2CLIKernel",
      "HarmoniaRuntime",
      "HarmoniaV2Surface",
      "HarmoniaV2Core",
      "HarmoniaV2Memory",
      "AnigmaFoundation",
      "AnigmaGovernance",
      "AnigmaJobs",
      "DatabaseCore",
      "RuntimeCore",
      "ContractsCore",
      "GovernanceCore",
      .product(name: "ArgumentParser", package: "swift-argument-parser")
    ], path: "Packages/HarmoniaV2CLI", exclude: ["CLIKernel.swift"],
    sources: ["CutoverCommands.swift", "Main.swift"],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings),
  /*
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
          "HarmoniaV2Surface",
          "AnigmaSidecar",
          .product(name: "MCP", package: "swift-sdk"),
          .product(name: "ArgumentParser", package: "swift-argument-parser"),
  
      ],
      path: "Packages/AnigmaCLI/Executable",
      swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  */
  .executableTarget(
    name: "AnigmaStatusBar",
    dependencies: [
      "AnigmaSidecar",
      "AnigmaPrimitives"
    ],
    path: "Packages/AnigmaStatusBar",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .executableTarget(
    name: "AnigmaDaemon",
    dependencies: [
      "AnigmaDaemonCore",
      "AnigmaCLIDatabase",
      "DaemonKernel",
      "ModelRegistryDaemonFeature",
      "DaemonStatusDaemonFeature",
      "AnigmaSidecar",
      "StorageCore",
      "HarmoniaV2Surface",
      "HarmoniaV2CLIKernel",
      "HarmoniaRuntime",
      "AnigmaCore",
      "GovernanceCore",
      "SidecarOfficeService",
      "SidecarPDFService",
      "PDFSidecarClient",
      "SidecarTranslateService",
      "AnigmaEvents",
      .product(name: "ArgumentParser", package: "swift-argument-parser")
    ],
    path: "Packages/AnigmaDaemon",
    exclude: [],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: [
      .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../../../Vendor/lib"])
    ]
  ),
  /*
  .executableTarget(
      name: "AnigmaDaemonVerifier",
      dependencies: [
          "AnigmaDaemonCore"
      ],
      path: "Packages/AnigmaDaemonVerifier",
      exclude: [],
      sources: ["main.swift"],
      swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  */
  .executableTarget(
    name: "AnigmaDaemonSimple",
    dependencies: [],
    path: "Sources/AnigmaDaemonSimple",
    exclude: [],
    swiftSettings: [.unsafeFlags(["-strict-concurrency=minimal"])]
  )
]

let baseTestTargets: [Target] = [
  .testTarget(
    name: "BackendReadinessContractTests",
    dependencies: [
      "AnigmaCore"
    ],
    path: "Packages/AnigmaCore/Tests/BackendReadinessTests/ContractTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings
  ),
  .testTarget(
    name: "BackendReadinessRegistryTests",
    dependencies: [
      "AnigmaCore"
    ],
    path: "Packages/AnigmaCore/Tests/BackendReadinessTests/RegistryTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings
  ),
  .testTarget(
    name: "BackendReadinessExecutionTests",
    dependencies: [
      "AnigmaCore"
    ],
    path: "Packages/AnigmaCore/Tests/BackendReadinessTests/ExecutionTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings
  ),
  .testTarget(
    name: "BackendReadinessIntegrationTests",
    dependencies: [
      "AnigmaCore"
    ],
    path: "Packages/AnigmaCore/Tests/BackendReadinessTests/IntegrationTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings
  ),
  .testTarget(
    name: "MediaCoreTests",
    dependencies: [
      "MediaCore",
      "ContractsCore",
      "SaturationKit",
      "MediaPipelineContracts"
    ],
    path: "Tests/MediaCoreTests",
    exclude: ["Fixtures"],
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings
  ),
  // .testTarget(
  //   name: "GovernanceCoreTests",
  //   dependencies: [
  //     "ContractsCore",
  //     "CathedralModule",
  //     "PDFSidecarClient",
  //     "SidecarPDFService"
  //   ],
  //   path: "Tests/GovernanceCoreTests",
  //   swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
  //   linkerSettings: testRuntimeLinkerSettings
  // ),
  // .testTarget(
  //   name: "CathedralModuleTests",
  //   dependencies: [
  //     "CathedralModule",
  //     "ContractsCore",
  //     "AnigmaPrimitives"
  //   ],
  //   path: "Tests/CathedralModuleTests",
  //   swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
  //   linkerSettings: testRuntimeLinkerSettings
  // ),
  .testTarget(
    name: "AnigmaPrimitivesTests",
    dependencies: [
      "AnigmaPrimitives"
    ],
    path: "Tests/Constitutional/AnigmaPrimitivesTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings
  ),
  // .testTarget(
  //   name: "CosineSimilarityCapsuleTests",
  //   dependencies: [
  //     "CosineSimilarityCapsule"
  //   ],
  //   path: "Tests/CosineSimilarityCapsuleTests",
  //   swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
  //   linkerSettings: testRuntimeLinkerSettings
  // ),
  .testTarget(
    name: "RankFusionCapsuleTests",
    dependencies: [
      "RankFusionCapsule"
    ],
    path: "Packages/RankFusionCapsule/Tests/RankFusionCapsuleTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings
  ),
  .testTarget(
    name: "CompressionKitTests",
    dependencies: [
      "CompressionKit"
    ],
    path: "Packages/CompressionKit/Tests/CompressionKitTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings
  ),
  .testTarget(
    name: "LayoutEngineCapsuleTests",
    dependencies: [
      "LayoutEngineCapsule"
    ],
    path: "Packages/LayoutEngineCapsule/Tests/LayoutEngineCapsuleTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings
  ),
  .testTarget(
    name: "VectorIndexCapsuleTests",
    dependencies: [
      "VectorIndexCapsule"
    ],
    path: "Packages/VectorIndexCapsule/Tests/VectorIndexCapsuleTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings
  ),
  .testTarget(
    name: "MediaFingerprintCapsuleTests",
    dependencies: [
      "MediaFingerprintCapsule"
    ],
    path: "Packages/MediaFingerprintCapsule/Tests/MediaFingerprintCapsuleTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings
  ),
  .testTarget(
    name: "TextPipelineCapsuleTests",
    dependencies: [
      "TextPipelineCapsule"
    ],
    path: "Packages/TextPipelineCapsule/Tests/TextPipelineCapsuleTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings
  ),
  // .testTarget(
  //   name: "AssistantEvalFixturesTests",
  //   dependencies: [
  //     "AnigmaAppMacExecutable",
  //     "AnigmaCore",
  //     "HarmoniaV2Surface",
  //     "GoldenKit"
  //   ],
  //   path: "Tests/AssistantEvalFixturesTests",
  //   swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
  //   linkerSettings: testRuntimeLinkerSettings
  // ),
  .testTarget(
    name: "HarmoniaRuntimeTests",
    dependencies: [
      "HarmoniaRuntime",
      "AnigmaEvents"
    ],
    path: "Tests/HarmoniaRuntimeTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings
  ),
  // .testTarget(
  //   name: "DaemonKernelTests",
  //   dependencies: [
  //     "DaemonKernel",
  //     "DaemonFeatureContracts",
  //     "ModelRegistryDaemonFeature",
  //     "DaemonStatusDaemonFeature"
  //   ],
  //   path: "Tests/DaemonKernelTests",
  //   swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
  //   linkerSettings: testRuntimeLinkerSettings
  // ),
  /*
  .testTarget(
      name: "AnigmaDaemonVerifierTests",
      dependencies: [
          "AnigmaDaemonCore"
      ],
      path: "Tests/AnigmaDaemonVerifierTests",
      resources: [
          .process("Fixtures")
      ],
      swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  */
  /*
  .testTarget(
      name: "BackendStabilizationTests",
      dependencies: [
          "AnigmaPrimitives",
          "DatabaseCore",
          "HardwareAuthorityContracts",
          "ExecutionCore",
          "GovernanceCore"
      ],
      path: "Tests/BackendStabilizationTests",
      swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  */
  // .testTarget(
  //   name: "ExecutionCoreTests",
  //   dependencies: [
  //     "ExecutionCore",
  //     "TelemetryCore",
  //     "AnigmaPrimitives"
  //   ],
  //   path: "Tests/ExecutionCoreTests",
  //   swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
  //   linkerSettings: testRuntimeLinkerSettings
  // ),
  // .testTarget(
  //   name: "AnigmaCLIOrchestratorTests",
  //   dependencies: [
  //     "AnigmaCLIOrchestrator",
  //     "AnigmaCLICore"
  //   ],
  //   path: "Tests/AnigmaCLIOrchestratorTests",
  //   swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
  //   linkerSettings: testRuntimeLinkerSettings
  // ),
  .testTarget(
    name: "DatabaseCoreTests",
    dependencies: [
      "DatabaseCore",
      "FoundationContracts"
    ],
    path: "Tests/DatabaseCoreTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings
  ),
  .testTarget(
    name: "SaturationKitTests",
    dependencies: [
      "SaturationKit", "ExecutionCore", "AnigmaPrimitives", "TelemetryCore"
    ],
    path: "Tests/SaturationKitTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: testRuntimeLinkerSettings
  ),
  // .testTarget(
  //   name: "MessagingIntegrationTests",
  //   dependencies: [
  //     "AnigmaGovernance",
  //     "AnigmaCore",
  //     "ContractsCore",
  //     "DatabaseCore"
  //   ],
  //   path: "Tests/MessagingIntegrationTests",
  //   swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
  //   linkerSettings: testRuntimeLinkerSettings
  // )
  .testTarget(
    name: "InferenceContractsTests",
    dependencies: ["InferenceContracts"],
    path: "Packages/InferenceContracts/Tests/InferenceContractsTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]),
  .testTarget(
    name: "SaturationInferenceCoreTests",
    dependencies: ["SaturationInferenceCore"],
    path: "Packages/SaturationInferenceCore/Tests/SaturationInferenceCoreTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: [
      .linkedFramework("Metal"),
      .linkedFramework("Accelerate"),
    ]),
  .testTarget(
    name: "SaturatedModelRegistryTests",
    dependencies: ["SaturatedModelRegistry"],
    path: "Packages/SaturatedModelRegistry/Tests/SaturatedModelRegistryTests",
    swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)],
    linkerSettings: [
      .linkedFramework("Metal"),
      .linkedFramework("Accelerate"),
    ]),
]

// QUARANTINED LEGACY TEST SURFACE (td-810db3):
// HarmoniaModuleTests exercise the archived HarmoniaModule implementation. They
// are not evidence that Harmonia V3 works. Recreate any still-valuable behavior
// as HarmoniaRuntime/HarmoniaV2 tests before re-enabling.
let harmoniaModuleTestTargets: [Target] = [
  /*
  .testTarget(
      name: "HarmoniaModuleTests",
      dependencies: [
          "HarmoniaModule",
          "ContractsCore"
      ],
      path: "Tests/HarmoniaModuleTests",
      swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  ),
  .testTarget(
      name: "TextRenderKitTests",
      dependencies: [
          "TextRenderKit",
          "RendererKit",
          "SaturationKit"
      ],
      path: "Anigma/Packages/TextRenderKit/Tests/TextRenderKitTests",
      swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
  )
  */
]

let sceneGraphCapsuleTestTargets: [Target] = {
  // Isolate broken tests to unblock focused work (e.g., SaturationKit)
  return []
  /*
  guard let sceneGraphCapsuleTestsPath else {
      return []
  }
  return [
      .testTarget(
          name: "SceneGraphCapsuleTests",
          dependencies: [
              "SceneGraphCapsule",
              "CapsuleCore",
              "TelemetryCore"
          ],
          path: sceneGraphCapsuleTestsPath,
          swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)]
      )
  ]
  */
}()

let testTargets: [Target] =
  baseTestTargets + harmoniaModuleTestTargets + sceneGraphCapsuleTestTargets

let package = Package(
  name: "Anigma",
  platforms: [
    .macOS(.v14), .iOS(.v17), .tvOS(.v17), .watchOS(.v10)
  ],
  products: coreProducts + executableProducts + capabilityProducts,
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    .package(url: "https://github.com/apple/swift-syntax.git", from: "510.0.0"),
    .package(url: "https://github.com/mecid/SwiftUICharts.git", branch: "main"),
    .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.29.1"),
    .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "2.29.2"),
    .package(url: "https://github.com/apple/swift-numerics.git", from: "1.0.2"),
    .package(url: "https://github.com/jdfergason/swift-toml.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    .package(url: "https://github.com/apple/swift-cmark.git", from: "0.5.0"),
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
    .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.19.0"),
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.4.1"),
    .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.29.0"),
  ],
  targets: nativeTargets + coreTargets + moduleTargets + executableTargets + testTargets,
  cxxLanguageStandard: .cxx17
)
