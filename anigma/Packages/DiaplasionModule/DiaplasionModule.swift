//
//  DiaplasionModule.swift
//  DiaplasionModule
//
//  Diaplasion (from Greek "διάπλασις" – reshaping / remolding):
//  The alt-media / transformation engine that takes source documents and produces
//  alternate, accessible forms: OCR, structured text, EPUB, braille-ready,
//  audio-ready, large-print, etc.
//
//  Migration Source: /Users/user/Developer/GitHub/Harmonia_DSPS_AltMediaEngine
//
//  Components (in Components/):
//  - DocumentSourceComponent: Original document reference and format
//  - IngestedDocumentComponent: Extracted page images ready for OCR
//  - TransformRequestComponent: Transformation request with target formats
//  - OCRResultComponent: OCR extraction results with confidence scores
//  - ChunkedTextComponent: Semantically chunked text for processing
//  - AccessibleOutputComponent: Final accessible output references
//
//  Systems (in Systems/):
//  - DocumentIngestSystem: Load and validate source documents (IMPLEMENTED)
//  - OCRExtractionSystem: Perform OCR on images/PDFs (IMPLEMENTED)
//  - TextChunkingSystem: Semantic chunking of extracted text (IMPLEMENTED)
//  - EPUBExportSystem: Generate accessible EPUB 3 output (IMPLEMENTED)
//  - BrailleExportSystem: Generate UEB Grade 1/2 braille, BRF/PEF output (IMPLEMENTED)
//  - AudioPrepSystem: Prepare text for TTS with SSML and normalization (IMPLEMENTED)
//  - DiaplasionQASystem: Validate outputs for accessibility compliance (IMPLEMENTED)
//
//  Workflows (in Pipelines/):
//  - DocumentToEPUBWorkflow: Full pipeline for document → EPUB
//  - DocumentToBrailleWorkflow: Full pipeline for document → Braille
//  - DocumentToAudioWorkflow: Full pipeline for document → Audio-ready
//  - OCROnlyWorkflow: Lightweight OCR extraction only
//  - MultiFormatWorkflow: Generate multiple output formats in one pass
//

import AnigmaCore
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Module Info

/// DiaplasionModule version information.
public enum DiaplasionModuleVersion {
    public static let major = 0
    public static let minor = 2
    public static let patch = 0
    public static let string = "\(major).\(minor).\(patch)"
}

// MARK: - Module Registration

/// Registers Diaplasion-specific systems and workflows with the ECS.
public enum DiaplasionModule: CapabilityModule {
    public static func register(runtime: PlatformRuntime) async throws {
        let world = await runtime.getWorld()
        let registry = await runtime.getWorkflowRegistry()
        let runner = await runtime.getWorkflowRunner()
        try await register(world: world, registry: registry, runner: runner)
    }

    /// Register all Diaplasion systems and workflows with the world.
    ///
    /// Call this during app startup to enable alt-media transformation pipelines.
    ///
    /// - Parameters:
    ///   - world: The ECS world to register systems with.
    ///   - registry: The workflow registry to register workflows with.
    ///   - runner: Optional workflow runner to register systems for execution.
    public static func register(
        world: World,
        registry: WorkflowRegistry,
        runner: WorkflowRunner? = nil
    ) async throws {
        // Register implemented systems
        await world.registerSystem(DocumentIngestSystem())
        await world.registerSystem(OCRExtractionSystem())
        await world.registerSystem(TextChunkingSystem())

        // Register export systems (for workflow completion)
        await world.registerSystem(EPUBExportSystem())
        await world.registerSystem(BrailleExportSystem())
        await world.registerSystem(AudioPrepSystem())
        await world.registerSystem(DiaplasionQASystem())

        // Register with workflow runner if provided
        if let runner = runner {
            await runner.registerSystem(DocumentIngestSystem())
            await runner.registerSystem(OCRExtractionSystem())
            await runner.registerSystem(TextChunkingSystem())
            await runner.registerSystem(EPUBExportSystem())
            await runner.registerSystem(BrailleExportSystem())
            await runner.registerSystem(AudioPrepSystem())
            await runner.registerSystem(DiaplasionQASystem())
        }

        // Register workflows
        await registry.register(DocumentToEPUBWorkflow())
        await registry.register(DocumentToBrailleWorkflow())
        await registry.register(DocumentToAudioWorkflow())
        await registry.register(OCROnlyWorkflow())
        await registry.register(MultiFormatWorkflow())

        await Logger.shared.info(
            "DiaplasionModule v\(DiaplasionModuleVersion.string) registered",
            category: "Diaplasion"
        )
    }

    /// Creates a pre-configured set of systems for the OCR pipeline.
    ///
    /// Use this for custom pipeline construction without full module registration.
    public static func createOCRPipeline(
        cacheDirectory: URL? = nil,
        renderDPI: CGFloat = 150,
        recognitionLevel: OCRExtractionSystem.RecognitionLevel = .accurate
    ) -> [any System] {
        [
            DocumentIngestSystem(cacheDirectory: cacheDirectory, renderDPI: renderDPI),
            OCRExtractionSystem(recognitionLevel: recognitionLevel),
            TextChunkingSystem()
        ]
    }
}

// MARK: - Job Types

/// Job types for Diaplasion transformation pipelines.
public enum DiaplasionJobType {
    public static let documentToEPUB = "diaplasion.document_to_epub"
    public static let documentToBraille = "diaplasion.document_to_braille"
    public static let documentToAudio = "diaplasion.document_to_audio"
    public static let ocrExtraction = "diaplasion.ocr_extraction"
    public static let textChunking = "diaplasion.text_chunking"
    public static let multiFormat = "diaplasion.multi_format"
}
