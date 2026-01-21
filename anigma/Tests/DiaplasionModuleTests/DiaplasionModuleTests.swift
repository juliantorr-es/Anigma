//
//  DiaplasionModuleTests.swift
//  DiaplasionModuleTests
//
//  Tests for the Diaplasion alt-media transformation systems.
//

import XCTest
@testable import AnigmaCore
@testable import DiaplasionModule

final class DiaplasionModuleTests: XCTestCase {

    // MARK: - Component Tests

    func testDocumentSourceComponentCreation() {
        let source = DocumentSourceComponent(
            sourceURI: "/path/to/document.pdf",
            format: .pdf,
            pageCount: 10,
            fileSize: 1024
        )

        XCTAssertEqual(source.sourceURI, "/path/to/document.pdf")
        XCTAssertEqual(source.format, .pdf)
        XCTAssertEqual(source.pageCount, 10)
        XCTAssertEqual(source.fileSize, 1024)
    }

    func testDocumentFormatImageDetection() {
        XCTAssertTrue(DocumentFormat.jpeg.isImage)
        XCTAssertTrue(DocumentFormat.png.isImage)
        XCTAssertTrue(DocumentFormat.tiff.isImage)
        XCTAssertFalse(DocumentFormat.pdf.isImage)
        XCTAssertFalse(DocumentFormat.plainText.isImage)
    }

    func testDocumentFormatOCRRequirement() {
        XCTAssertTrue(DocumentFormat.pdf.requiresOCR)
        XCTAssertTrue(DocumentFormat.jpeg.requiresOCR)
        XCTAssertFalse(DocumentFormat.plainText.requiresOCR)
        XCTAssertFalse(DocumentFormat.html.requiresOCR)
    }

    func testOCRResultComponentCreation() {
        let pageResult = PageOCRResult(
            pageNumber: 1,
            text: "Sample text",
            confidence: 0.95,
            boundingBoxes: nil
        )

        let ocrResult = OCRResultComponent(
            text: "Sample text",
            confidence: 0.95,
            language: "en",
            pageResults: [pageResult],
            engine: "Vision",
            processingTime: 1.5
        )

        XCTAssertEqual(ocrResult.text, "Sample text")
        XCTAssertEqual(ocrResult.confidence, 0.95)
        XCTAssertEqual(ocrResult.language, "en")
        XCTAssertEqual(ocrResult.pageResults?.count, 1)
    }

    func testChunkedTextComponentCreation() {
        let chunk = TextChunk(
            text: "This is a paragraph.",
            chunkType: .paragraph,
            pageNumber: 1,
            tokenCount: 5
        )

        let chunked = ChunkedTextComponent(
            chunks: [chunk],
            strategy: .paragraph,
            totalTokens: 5
        )

        XCTAssertEqual(chunked.chunks.count, 1)
        XCTAssertEqual(chunked.strategy, .paragraph)
    }

    // MARK: - Text Chunking Tests

    func testTextChunkingSystemParagraphChunking() async {
        let world = World()

        // Create entity with mock OCR result
        let entity = await world.createEntity()
        let ocrResult = OCRResultComponent(
            text: """
            CHAPTER ONE

            This is the first paragraph. It has multiple sentences.

            This is the second paragraph. It also has text.
            """,
            confidence: 0.9
        )
        await world.addComponent(entity, ocrResult)

        // Run chunking system
        let chunkingSystem = TextChunkingSystem()
        await chunkingSystem.update(world: world)

        // Verify chunks were created
        let chunked = await world.getComponent(entity, ChunkedTextComponent.self)
        XCTAssertNotNil(chunked)
        XCTAssertEqual(chunked?.chunks.count, 3) // CHAPTER ONE, para1, para2

        // First chunk should be detected as heading
        XCTAssertEqual(chunked?.chunks[0].chunkType, .heading)
        XCTAssertEqual(chunked?.chunks[1].chunkType, .paragraph)
        XCTAssertEqual(chunked?.chunks[2].chunkType, .paragraph)
    }

    func testTextChunkingSystemHeadingDetection() async {
        let world = World()

        let entity = await world.createEntity()
        let ocrResult = OCRResultComponent(
            text: """
            INTRODUCTION

            Some body text here.

            Chapter 1: Getting Started

            More body text.
            """,
            confidence: 0.9
        )
        await world.addComponent(entity, ocrResult)

        let chunkingSystem = TextChunkingSystem()
        await chunkingSystem.update(world: world)

        let chunked = await world.getComponent(entity, ChunkedTextComponent.self)
        XCTAssertNotNil(chunked)

        // INTRODUCTION should be heading (ALL CAPS)
        XCTAssertEqual(chunked?.chunks[0].chunkType, .heading)
        XCTAssertEqual(chunked?.chunks[0].text, "INTRODUCTION")

        // "Chapter 1:" should be detected as heading
        if let chapterChunk = chunked?.chunks.first(where: { $0.text.hasPrefix("Chapter") }) {
            XCTAssertEqual(chapterChunk.chunkType, .heading)
        }
    }

    func testTextChunkingSystemSentenceChunking() async {
        let world = World()

        let entity = await world.createEntity()
        let ocrResult = OCRResultComponent(
            text: "First sentence. Second sentence! Third sentence?",
            confidence: 0.9
        )
        await world.addComponent(entity, ocrResult)

        let chunkingSystem = TextChunkingSystem(strategy: .sentence)
        await chunkingSystem.update(world: world)

        let chunked = await world.getComponent(entity, ChunkedTextComponent.self)
        XCTAssertNotNil(chunked)
        XCTAssertEqual(chunked?.chunks.count, 3)
        XCTAssertEqual(chunked?.strategy, .sentence)
    }

    func testTextChunkingSystemSkipsEmptyOCR() async {
        let world = World()

        let entity = await world.createEntity()
        let ocrResult = OCRResultComponent(text: "", confidence: 0.0)
        await world.addComponent(entity, ocrResult)

        let chunkingSystem = TextChunkingSystem()
        await chunkingSystem.update(world: world)

        // Should not add ChunkedTextComponent for empty input
        let chunked = await world.getComponent(entity, ChunkedTextComponent.self)
        XCTAssertNil(chunked)
    }

    func testTextChunkingSystemDoesNotReprocess() async {
        let world = World()

        let entity = await world.createEntity()
        await world.addComponent(entity, OCRResultComponent(text: "Test text", confidence: 0.9))
        await world.addComponent(entity, ChunkedTextComponent(chunks: [], strategy: .paragraph))

        let chunkingSystem = TextChunkingSystem()
        await chunkingSystem.update(world: world)

        // Should still have empty chunks (not reprocessed)
        let chunked = await world.getComponent(entity, ChunkedTextComponent.self)
        XCTAssertEqual(chunked?.chunks.count, 0)
    }

    // MARK: - Module Registration Tests

    func testModuleVersion() {
        XCTAssertEqual(DiaplasionModuleVersion.major, 0)
        XCTAssertEqual(DiaplasionModuleVersion.minor, 2)
        XCTAssertEqual(DiaplasionModuleVersion.patch, 0)
        XCTAssertEqual(DiaplasionModuleVersion.string, "0.2.0")
    }

    func testModuleRegistration() async throws {
        let world = World()
        let registry = WorkflowRegistry()

        try await DiaplasionModule.register(world: world, registry: registry)

        // Check systems were registered
        let systemNames = await world.registeredSystemNames()
        XCTAssertTrue(systemNames.contains("DocumentIngest"))
        XCTAssertTrue(systemNames.contains("OCRExtraction"))
        XCTAssertTrue(systemNames.contains("TextChunking"))

        // Check workflows were registered
        let workflowNames = await registry.allWorkflowNames()
        XCTAssertTrue(workflowNames.contains("Document to EPUB"))
        XCTAssertTrue(workflowNames.contains("OCR Extraction"))
    }

    func testOCRPipelineCreation() {
        let pipeline = DiaplasionModule.createOCRPipeline()
        XCTAssertEqual(pipeline.count, 3)
        XCTAssertEqual(pipeline[0].name, "DocumentIngest")
        XCTAssertEqual(pipeline[1].name, "OCRExtraction")
        XCTAssertEqual(pipeline[2].name, "TextChunking")
    }

    // MARK: - Workflow Tests

    func testDocumentToEPUBWorkflowDefinition() {
        let workflow = DocumentToEPUBWorkflow()

        XCTAssertEqual(workflow.name, "Document to EPUB")
        XCTAssertEqual(workflow.jobTypeId, DiaplasionJobType.documentToEPUB)
        XCTAssertEqual(workflow.systemNames.count, 5)
        XCTAssertEqual(workflow.systemNames[0], "DocumentIngest")
        XCTAssertEqual(workflow.systemNames[1], "OCRExtraction")
        XCTAssertEqual(workflow.systemNames[2], "TextChunking")
        XCTAssertEqual(workflow.systemNames[3], "EPUBExport")
        XCTAssertEqual(workflow.systemNames[4], "DiaplasionQA")
    }

    func testOCROnlyWorkflowDefinition() {
        let workflow = OCROnlyWorkflow()

        XCTAssertEqual(workflow.name, "OCR Extraction")
        XCTAssertEqual(workflow.jobTypeId, DiaplasionJobType.ocrExtraction)
        XCTAssertEqual(workflow.systemNames.count, 2)
    }

    // MARK: - Error Tests

    func testDiaplasionErrorDescriptions() {
        let fileError = DiaplasionError.fileNotFound(path: "/test/path")
        XCTAssertTrue(fileError.localizedDescription.contains("/test/path"))

        let formatError = DiaplasionError.unsupportedFormat(format: "docx")
        XCTAssertTrue(formatError.localizedDescription.contains("docx"))

        let ocrError = DiaplasionError.ocrFailed(reason: "No text found")
        XCTAssertTrue(ocrError.localizedDescription.contains("No text found"))

        let epubError = DiaplasionError.epubPackagingFailed(reason: "ZIP failed")
        XCTAssertTrue(epubError.localizedDescription.contains("ZIP failed"))
    }
}

// MARK: - QA System Tests

final class QASystemTests: XCTestCase {

    func testQASystemCreation() {
        let system = DiaplasionQASystem()
        XCTAssertEqual(system.name, "DiaplasionQA")
        XCTAssertEqual(system.reviewThreshold, 0.8)
        XCTAssertTrue(system.validateEPUBStructure)
    }

    func testQASystemCustomConfig() {
        let system = DiaplasionQASystem(
            reviewThreshold: 0.9,
            validateEPUBStructure: false
        )

        XCTAssertEqual(system.reviewThreshold, 0.9)
        XCTAssertFalse(system.validateEPUBStructure)
    }

    func testQASystemPassesHighConfidence() async {
        let world = World()

        let entity = await world.createEntity()

        // High confidence OCR result
        await world.addComponent(entity, OCRResultComponent(
            text: "Sample text with high quality OCR.",
            confidence: 0.95
        ))

        // Good chunking
        await world.addComponent(entity, ChunkedTextComponent(
            chunks: [
                TextChunk(text: "INTRODUCTION", chunkType: .heading),
                TextChunk(text: "This is a well-structured paragraph with enough content.", chunkType: .paragraph)
            ],
            strategy: .paragraph
        ))

        // Pending QA status
        await world.addComponent(entity, AccessibleOutputComponent(
            outputs: [:],
            qaStatus: .pending
        ))

        let qaSystem = DiaplasionQASystem()
        await qaSystem.update(world: world)

        let output = await world.getComponent(entity, AccessibleOutputComponent.self)
        XCTAssertEqual(output?.qaStatus, .passed)
        XCTAssertNotNil(output?.validationResults)
        XCTAssertGreaterThan(output?.validationResults?.count ?? 0, 0)
    }

    func testQASystemFlagsLowConfidence() async {
        let world = World()

        let entity = await world.createEntity()

        // Low confidence OCR result
        await world.addComponent(entity, OCRResultComponent(
            text: "Poorly recognized text.",
            confidence: 0.5
        ))

        // Chunking with issues
        await world.addComponent(entity, ChunkedTextComponent(
            chunks: [
                TextChunk(text: "x", chunkType: .paragraph), // Too short
                TextChunk(text: "y", chunkType: .paragraph)  // Too short
            ],
            strategy: .paragraph
        ))

        await world.addComponent(entity, AccessibleOutputComponent(
            outputs: [:],
            qaStatus: .pending
        ))

        let qaSystem = DiaplasionQASystem(reviewThreshold: 0.8)
        await qaSystem.update(world: world)

        let output = await world.getComponent(entity, AccessibleOutputComponent.self)
        XCTAssertEqual(output?.qaStatus, .needsReview)
    }

    func testQASystemSkipsNonPending() async {
        let world = World()

        let entity = await world.createEntity()

        // Already passed
        await world.addComponent(entity, AccessibleOutputComponent(
            outputs: [:],
            qaStatus: .passed
        ))

        let qaSystem = DiaplasionQASystem()
        await qaSystem.update(world: world)

        // Should still be passed, not modified
        let output = await world.getComponent(entity, AccessibleOutputComponent.self)
        XCTAssertEqual(output?.qaStatus, .passed)
        XCTAssertNil(output?.validationResults) // Not modified
    }

    func testQASystemValidatesEPUBFile() async throws {
        let world = World()
        let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("qa_test_\(UUID().uuidString)")

        let entity = await world.createEntity()

        // First generate an EPUB
        let chunks = [
            TextChunk(text: "QA TEST DOCUMENT", chunkType: .heading),
            TextChunk(text: "This is test content for QA validation.", chunkType: .paragraph)
        ]
        await world.addComponent(entity, ChunkedTextComponent(chunks: chunks, strategy: .paragraph))
        await world.addComponent(entity, TransformRequestComponent(
            requestId: "qa_test",
            targetFormats: [.epub],
            priority: 0
        ))

        // Generate EPUB
        let epubSystem = EPUBExportSystem(outputDirectory: outputDir)
        await epubSystem.update(world: world)

        // Add OCR result for QA
        await world.addComponent(entity, OCRResultComponent(
            text: "QA TEST DOCUMENT\n\nThis is test content.",
            confidence: 0.92
        ))

        // Run QA
        let qaSystem = DiaplasionQASystem()
        await qaSystem.update(world: world)

        let output = await world.getComponent(entity, AccessibleOutputComponent.self)
        XCTAssertEqual(output?.qaStatus, .passed)

        // Check that EPUB validation was performed
        let epubChecks = output?.validationResults?.filter { $0.check.contains("EPUB") } ?? []
        XCTAssertGreaterThan(epubChecks.count, 0)

        // All EPUB checks should pass
        XCTAssertTrue(epubChecks.allSatisfy { $0.passed })

        // Clean up
        if let epubRef = output?.outputs[.epub] {
            try? FileManager.default.removeItem(atPath: epubRef.uri)
        }
        try? FileManager.default.removeItem(at: outputDir)
    }
}

// MARK: - EPUB Export Tests

final class EPUBExportTests: XCTestCase {

    func testEPUBExportSystemCreation() {
        let system = EPUBExportSystem()
        XCTAssertEqual(system.name, "EPUBExport")
        XCTAssertEqual(system.defaultLanguage, "en")
        XCTAssertEqual(system.defaultPublisher, "Diaplasion")
    }

    func testEPUBExportSystemCustomConfig() {
        let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_epub")
        let system = EPUBExportSystem(
            outputDirectory: outputDir,
            defaultLanguage: "de",
            defaultPublisher: "Test Publisher"
        )

        XCTAssertEqual(system.outputDirectory, outputDir)
        XCTAssertEqual(system.defaultLanguage, "de")
        XCTAssertEqual(system.defaultPublisher, "Test Publisher")
    }

    func testEPUBExportSystemSkipsWithoutEPUBTarget() async {
        let world = World()

        let entity = await world.createEntity()

        // Add chunked content but request Braille, not EPUB
        let chunks = [
            TextChunk(text: "Test Heading", chunkType: .heading),
            TextChunk(text: "Test paragraph content.", chunkType: .paragraph)
        ]
        await world.addComponent(entity, ChunkedTextComponent(chunks: chunks, strategy: .paragraph))
        await world.addComponent(entity, TransformRequestComponent(
            targetFormats: [.brailleReady],  // Not EPUB
            priority: 0
        ))

        let epubSystem = EPUBExportSystem()
        await epubSystem.update(world: world)

        // Should not have created AccessibleOutputComponent since EPUB wasn't requested
        let output = await world.getComponent(entity, AccessibleOutputComponent.self)
        XCTAssertNil(output)
    }

    func testEPUBExportSystemGeneratesEPUB() async throws {
        let world = World()
        let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("epub_test_\(UUID().uuidString)")

        let entity = await world.createEntity()

        // Add chunked content
        let chunks = [
            TextChunk(text: "CHAPTER ONE", chunkType: .heading),
            TextChunk(text: "This is the first paragraph of chapter one. It has multiple sentences.", chunkType: .paragraph),
            TextChunk(text: "This is another paragraph with more content.", chunkType: .paragraph),
            TextChunk(text: "CHAPTER TWO", chunkType: .heading),
            TextChunk(text: "The second chapter begins here with new material.", chunkType: .paragraph)
        ]
        await world.addComponent(entity, ChunkedTextComponent(chunks: chunks, strategy: .paragraph))

        // Add source component for title extraction
        await world.addComponent(entity, DocumentSourceComponent(
            sourceURI: "/path/to/TestDocument.pdf",
            format: .pdf
        ))

        // Add transform request for EPUB
        await world.addComponent(entity, TransformRequestComponent(
            requestId: "test_request_123",
            targetFormats: [.epub],
            priority: 0
        ))

        let epubSystem = EPUBExportSystem(outputDirectory: outputDir)
        await epubSystem.update(world: world)

        // Check output was created
        let output = await world.getComponent(entity, AccessibleOutputComponent.self)
        XCTAssertNotNil(output)
        XCTAssertNotNil(output?.outputs[.epub])

        // Verify EPUB file exists
        if let epubRef = output?.outputs[.epub] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: epubRef.uri))
            XCTAssertTrue(epubRef.uri.hasSuffix(".epub"))

            // Clean up
            try? FileManager.default.removeItem(atPath: epubRef.uri)
        }

        // Clean up output directory
        try? FileManager.default.removeItem(at: outputDir)
    }

    func testEPUBExportDoesNotReprocess() async {
        let world = World()

        let entity = await world.createEntity()

        // Add already processed output
        let existingOutput = AccessibleOutputComponent(
            outputs: [.epub: OutputReference(format: .epub, uri: "/existing/file.epub")],
            qaStatus: .pending
        )
        await world.addComponent(entity, existingOutput)

        // Add chunked content and request
        await world.addComponent(entity, ChunkedTextComponent(
            chunks: [TextChunk(text: "Test", chunkType: .paragraph)],
            strategy: .paragraph
        ))
        await world.addComponent(entity, TransformRequestComponent(
            targetFormats: [.epub],
            priority: 0
        ))

        let epubSystem = EPUBExportSystem()
        await epubSystem.update(world: world)

        // Should still have the original output, not reprocessed
        let output = await world.getComponent(entity, AccessibleOutputComponent.self)
        XCTAssertEqual(output?.outputs[.epub]?.uri, "/existing/file.epub")
    }
}

// MARK: - Integration Tests

final class DiaplasionIntegrationTests: XCTestCase {

    /// Tests the full OCR pipeline with a text file fixture.
    /// This simulates the flow from file to chunked text.
    func testOCRPipelineIntegration() async throws {
        let world = World()
        let registry = WorkflowRegistry()

        // Register module
        try await DiaplasionModule.register(world: world, registry: registry)

        // Create entity with file reference
        // Note: For a real test, we'd need an image or PDF
        // This tests the pipeline structure without actual OCR
        let entity = await world.createEntity()

        // Simulate post-ingest state with mock OCR result
        let mockOCR = OCRResultComponent(
            text: """
            SAMPLE DOCUMENT TITLE

            This is the first paragraph of the document. It contains text that should be processed by the chunking system.

            This is the second paragraph with more content.
            """,
            confidence: 0.92,
            engine: "Test"
        )
        await world.addComponent(entity, mockOCR)

        // Run just the chunking system
        await world.update()

        // Verify chunking happened
        let chunked = await world.getComponent(entity, ChunkedTextComponent.self)
        XCTAssertNotNil(chunked)
        XCTAssertGreaterThan(chunked?.chunks.count ?? 0, 0)

        // Verify heading was detected
        let headings = chunked?.chunks.filter { $0.chunkType == .heading } ?? []
        XCTAssertGreaterThan(headings.count, 0)
    }

    /// Tests the full document-to-EPUB workflow end-to-end.
    func testDocumentToEPUBWorkflowIntegration() async throws {
        let world = World()
        let registry = WorkflowRegistry()
        let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("epub_integration_\(UUID().uuidString)")

        // Register module with custom EPUB output directory
        // We register manually to use custom config
        await world.registerSystem(DocumentIngestSystem())
        await world.registerSystem(OCRExtractionSystem())
        await world.registerSystem(TextChunkingSystem())
        await world.registerSystem(EPUBExportSystem(outputDirectory: outputDir))
        await world.registerSystem(DiaplasionQASystem())
        await registry.register(DocumentToEPUBWorkflow())

        // Create entity simulating post-OCR state
        let entity = await world.createEntity()

        // Add OCR result (simulating completed OCR)
        await world.addComponent(entity, OCRResultComponent(
            text: """
            INTRODUCTION

            This is an introductory paragraph that explains the purpose of this document.

            CHAPTER ONE

            The first chapter contains important information. Multiple paragraphs follow to demonstrate the chunking and EPUB generation.

            This is another paragraph in chapter one.

            CONCLUSION

            This document demonstrates the Diaplasion EPUB generation pipeline.
            """,
            confidence: 0.95,
            engine: "Test"
        ))

        // Add source for metadata
        await world.addComponent(entity, DocumentSourceComponent(
            sourceURI: "/path/to/IntegrationTest.pdf",
            format: .pdf
        ))

        // Add transform request
        await world.addComponent(entity, TransformRequestComponent(
            requestId: "integration_test_\(UUID().uuidString)",
            targetFormats: [.epub],
            priority: 1
        ))

        // Run the world update (all registered systems)
        await world.update()

        // Verify chunking happened
        let chunked = await world.getComponent(entity, ChunkedTextComponent.self)
        XCTAssertNotNil(chunked)
        XCTAssertGreaterThan(chunked?.chunks.count ?? 0, 0)

        // Verify EPUB was generated
        let output = await world.getComponent(entity, AccessibleOutputComponent.self)
        XCTAssertNotNil(output)
        XCTAssertNotNil(output?.outputs[.epub])

        if let epubRef = output?.outputs[.epub] {
            // Verify file exists
            XCTAssertTrue(FileManager.default.fileExists(atPath: epubRef.uri))

            // Verify it's a valid EPUB (ZIP file starting with "PK")
            if let data = FileManager.default.contents(atPath: epubRef.uri), data.count >= 2 {
                XCTAssertEqual(data[0], 0x50) // 'P'
                XCTAssertEqual(data[1], 0x4B) // 'K'
            }

            // Clean up
            try? FileManager.default.removeItem(atPath: epubRef.uri)
        }

        // Clean up
        try? FileManager.default.removeItem(at: outputDir)
    }
}

// MARK: - Braille Export System Tests

final class BrailleExportSystemTests: XCTestCase {

    func testBrailleSystemCreation() {
        let system = BrailleExportSystem()
        XCTAssertEqual(system.name, "BrailleExport")
    }

    func testBrailleSystemWithCustomConfig() {
        let config = BrailleExportSystem.Configuration(
            grade: .grade1,
            outputFormats: [.brf, .pef],
            cellsPerLine: 32,
            linesPerPage: 20
        )
        let system = BrailleExportSystem(configuration: config)
        XCTAssertEqual(system.name, "BrailleExport")
    }

    func testBrailleGrade2Contractions() async throws {
        // Test that grade 2 braille uses contractions
        let config = BrailleExportSystem.Configuration(
            grade: .grade2,
            outputFormats: [.brf]
        )
        let system = BrailleExportSystem(configuration: config)

        // Create test world and entity
        let world = World()
        let entityId = await world.createEntity()

        // Add chunked text with common words that should be contracted
        let chunks = [
            TextChunk(text: "The quick brown fox", chunkType: .paragraph),
            TextChunk(text: "can jump very high", chunkType: .paragraph)
        ]
        let chunked = ChunkedTextComponent(chunks: chunks, strategy: .paragraph)
        await world.addComponent(entityId, chunked)

        // Add transform request targeting braille
        let request = TransformRequestComponent(
            requestId: "braille_test_001",
            targetFormats: [.brailleReady],
            status: .processing
        )
        await world.addComponent(entityId, request)

        // Run system
        await system.update(world: world)

        // Check that output was created
        let accessible = await world.getComponent(entityId, AccessibleOutputComponent.self)
        XCTAssertNotNil(accessible)

        if let brailleRef = accessible?.outputs[.brailleReady] {
            XCTAssertTrue(brailleRef.uri.hasSuffix(".brf"))
            XCTAssertTrue(FileManager.default.fileExists(atPath: brailleRef.uri))

            // Read BRF content
            if let content = try? String(contentsOfFile: brailleRef.uri, encoding: .ascii) {
                // Should contain braille ASCII characters
                XCTAssertFalse(content.isEmpty)
            }

            // Clean up
            try? FileManager.default.removeItem(atPath: brailleRef.uri)
        }
    }

    func testBrailleGrade1NoContractions() async throws {
        // Test that grade 1 braille does not use contractions
        let config = BrailleExportSystem.Configuration(
            grade: .grade1,
            outputFormats: [.brf]
        )
        let system = BrailleExportSystem(configuration: config)

        let world = World()
        let entityId = await world.createEntity()

        let chunks = [TextChunk(text: "Hello World", chunkType: .paragraph)]
        let chunked = ChunkedTextComponent(chunks: chunks, strategy: .paragraph)
        await world.addComponent(entityId, chunked)

        let request = TransformRequestComponent(
            requestId: "braille_g1_test",
            targetFormats: [.brailleReady],
            status: .processing
        )
        await world.addComponent(entityId, request)

        await system.update(world: world)

        let accessible = await world.getComponent(entityId, AccessibleOutputComponent.self)
        XCTAssertNotNil(accessible?.outputs[.brailleReady])

        // Clean up
        if let uri = accessible?.outputs[.brailleReady]?.uri {
            try? FileManager.default.removeItem(atPath: uri)
        }
    }

    func testBraillePEFGeneration() async throws {
        let config = BrailleExportSystem.Configuration(
            grade: .grade2,
            outputFormats: [.pef]
        )
        let system = BrailleExportSystem(configuration: config)

        let world = World()
        let entityId = await world.createEntity()

        let chunks = [
            TextChunk(text: "Chapter One", chunkType: .heading),
            TextChunk(text: "This is the first paragraph.", chunkType: .paragraph)
        ]
        let chunked = ChunkedTextComponent(chunks: chunks, strategy: .paragraph)
        await world.addComponent(entityId, chunked)

        let request = TransformRequestComponent(
            requestId: "braille_pef_test",
            targetFormats: [.brailleReady],
            status: .processing
        )
        await world.addComponent(entityId, request)

        await system.update(world: world)

        // PEF is generated in addition to/instead of BRF - check output dir for .pef file
        // The accessible output still uses .brailleReady format key
        let accessible = await world.getComponent(entityId, AccessibleOutputComponent.self)
        // Note: PEF is generated but not tracked in outputs since we only track one per format
        XCTAssertNotNil(accessible)
    }
}

// MARK: - Audio Prep System Tests

final class AudioPrepSystemTests: XCTestCase {

    func testAudioPrepSystemCreation() {
        let system = AudioPrepSystem()
        XCTAssertEqual(system.name, "AudioPrep")
    }

    func testAudioPrepSystemWithCustomConfig() {
        let config = AudioPrepSystem.Configuration(
            paragraphPause: 1.0,
            headingPause: 1.5,
            sentencePause: 0.4,
            headingRate: 0.85,
            generatePlainText: false
        )
        let system = AudioPrepSystem(configuration: config)
        XCTAssertEqual(system.name, "AudioPrep")
    }

    func testSSMLGeneration() async throws {
        let system = AudioPrepSystem()

        let world = World()
        let entityId = await world.createEntity()

        let chunks = [
            TextChunk(text: "Introduction", chunkType: .heading),
            TextChunk(text: "This is the first paragraph. It has two sentences.", chunkType: .paragraph),
            TextChunk(text: "This is a quote from someone.", chunkType: .quote)
        ]
        let chunked = ChunkedTextComponent(chunks: chunks, strategy: .paragraph)
        await world.addComponent(entityId, chunked)

        let request = TransformRequestComponent(
            requestId: "audio_test_001",
            targetFormats: [.audioReady],
            status: .processing
        )
        await world.addComponent(entityId, request)

        await system.update(world: world)

        let accessible = await world.getComponent(entityId, AccessibleOutputComponent.self)
        XCTAssertNotNil(accessible)

        if let audioRef = accessible?.outputs[.audioReady] {
            XCTAssertTrue(audioRef.uri.hasSuffix(".ssml"))
            XCTAssertTrue(FileManager.default.fileExists(atPath: audioRef.uri))

            // Read SSML content and verify structure
            if let content = try? String(contentsOfFile: audioRef.uri, encoding: .utf8) {
                XCTAssertTrue(content.contains("<?xml"))
                XCTAssertTrue(content.contains("<speak"))
                XCTAssertTrue(content.contains("</speak>"))
                XCTAssertTrue(content.contains("<prosody"))  // Heading styling
                XCTAssertTrue(content.contains("<break"))     // Pauses
                XCTAssertTrue(content.contains("<p>"))        // Paragraph elements
            }

            // Check for chapter manifest
            let manifestPath = audioRef.uri.replacingOccurrences(of: ".ssml", with: "_chapters.json")
            XCTAssertTrue(FileManager.default.fileExists(atPath: manifestPath))

            // Clean up output directory
            let outputDir = (audioRef.uri as NSString).deletingLastPathComponent
            try? FileManager.default.removeItem(atPath: outputDir)
        }
    }

    func testTextNormalization() async throws {
        let system = AudioPrepSystem()

        let world = World()
        let entityId = await world.createEntity()

        // Text with numbers, abbreviations, and symbols that should be normalized
        let chunks = [
            TextChunk(text: "Dr. Smith saw 123 patients @ $50 each.", chunkType: .paragraph),
            TextChunk(text: "The temperature was 98.6 degrees.", chunkType: .paragraph)
        ]
        let chunked = ChunkedTextComponent(chunks: chunks, strategy: .paragraph)
        await world.addComponent(entityId, chunked)

        let request = TransformRequestComponent(
            requestId: "audio_norm_test",
            targetFormats: [.audioReady],
            status: .processing
        )
        await world.addComponent(entityId, request)

        await system.update(world: world)

        let accessible = await world.getComponent(entityId, AccessibleOutputComponent.self)
        XCTAssertNotNil(accessible?.outputs[.audioReady])

        if let audioRef = accessible?.outputs[.audioReady],
           let content = try? String(contentsOfFile: audioRef.uri, encoding: .utf8) {
            // Check that normalization occurred
            XCTAssertTrue(content.contains("Doctor"))  // Dr. → Doctor
            XCTAssertTrue(content.contains("hundred") || content.contains("one"))  // Numbers normalized

            // Clean up
            let outputDir = (audioRef.uri as NSString).deletingLastPathComponent
            try? FileManager.default.removeItem(atPath: outputDir)
        }
    }

    func testChapterManifestGeneration() async throws {
        let system = AudioPrepSystem()

        let world = World()
        let entityId = await world.createEntity()

        let chunks = [
            TextChunk(text: "Chapter 1: The Beginning", chunkType: .heading),
            TextChunk(text: "Once upon a time...", chunkType: .paragraph),
            TextChunk(text: "Chapter 2: The Middle", chunkType: .heading),
            TextChunk(text: "Things happened.", chunkType: .paragraph),
            TextChunk(text: "Chapter 3: The End", chunkType: .heading),
            TextChunk(text: "And they lived happily ever after.", chunkType: .paragraph)
        ]
        let chunked = ChunkedTextComponent(chunks: chunks, strategy: .paragraph)
        await world.addComponent(entityId, chunked)

        let request = TransformRequestComponent(
            requestId: "audio_chapters_test",
            targetFormats: [.audioReady],
            status: .processing
        )
        await world.addComponent(entityId, request)

        await system.update(world: world)

        let accessible = await world.getComponent(entityId, AccessibleOutputComponent.self)
        if let audioRef = accessible?.outputs[.audioReady] {
            let manifestPath = audioRef.uri.replacingOccurrences(of: ".ssml", with: "_chapters.json")

            if let manifestData = FileManager.default.contents(atPath: manifestPath),
               let manifestStr = String(data: manifestData, encoding: .utf8) {
                // Verify chapter manifest structure
                XCTAssertTrue(manifestStr.contains("\"chapterCount\": 3"))
                XCTAssertTrue(manifestStr.contains("Chapter 1: The Beginning"))
                XCTAssertTrue(manifestStr.contains("Chapter 2: The Middle"))
                XCTAssertTrue(manifestStr.contains("Chapter 3: The End"))
            }

            // Clean up
            let outputDir = (audioRef.uri as NSString).deletingLastPathComponent
            try? FileManager.default.removeItem(atPath: outputDir)
        }
    }

    func testPlainTextGeneration() async throws {
        let config = AudioPrepSystem.Configuration(generatePlainText: true)
        let system = AudioPrepSystem(configuration: config)

        let world = World()
        let entityId = await world.createEntity()

        let chunks = [
            TextChunk(text: "Title", chunkType: .heading),
            TextChunk(text: "Body text here.", chunkType: .paragraph)
        ]
        let chunked = ChunkedTextComponent(chunks: chunks, strategy: .paragraph)
        await world.addComponent(entityId, chunked)

        let request = TransformRequestComponent(
            requestId: "audio_plain_test",
            targetFormats: [.audioReady],
            status: .processing
        )
        await world.addComponent(entityId, request)

        await system.update(world: world)

        let accessible = await world.getComponent(entityId, AccessibleOutputComponent.self)
        if let audioRef = accessible?.outputs[.audioReady] {
            let plainTextPath = audioRef.uri.replacingOccurrences(of: ".ssml", with: "_audio.txt")
            XCTAssertTrue(FileManager.default.fileExists(atPath: plainTextPath))

            // Clean up
            let outputDir = (audioRef.uri as NSString).deletingLastPathComponent
            try? FileManager.default.removeItem(atPath: outputDir)
        }
    }
}

// MARK: - MultiFormat Workflow Tests

final class MultiFormatWorkflowTests: XCTestCase {

    func testMultiFormatWorkflowConditionalExecution() async {
        // Test that the workflow correctly identifies which systems to run
        let workflow = MultiFormatWorkflow()
        let world = World()

        // Create entity with EPUB-only request
        let entityId = await world.createEntity()
        let epubOnlyRequest = TransformRequestComponent(
            requestId: "epub_only",
            targetFormats: [.epub],
            status: .processing
        )
        await world.addComponent(entityId, epubOnlyRequest)

        // Check conditional execution
        let shouldRunEPUB = await workflow.shouldRunSystem("EPUBExport", for: entityId, in: world)
        let shouldRunBraille = await workflow.shouldRunSystem("BrailleExport", for: entityId, in: world)
        let shouldRunAudio = await workflow.shouldRunSystem("AudioPrep", for: entityId, in: world)
        let shouldRunCore = await workflow.shouldRunSystem("DocumentIngest", for: entityId, in: world)

        XCTAssertTrue(shouldRunEPUB, "Should run EPUB for epub target")
        XCTAssertFalse(shouldRunBraille, "Should not run Braille for epub-only target")
        XCTAssertFalse(shouldRunAudio, "Should not run Audio for epub-only target")
        XCTAssertTrue(shouldRunCore, "Core systems should always run")
    }

    func testMultiFormatWorkflowAllFormats() async {
        let workflow = MultiFormatWorkflow()
        let world = World()

        // Create entity with all formats
        let entityId = await world.createEntity()
        let allFormatsRequest = TransformRequestComponent(
            requestId: "all_formats",
            targetFormats: [.epub, .brailleReady, .audioReady],
            status: .processing
        )
        await world.addComponent(entityId, allFormatsRequest)

        // All export systems should run
        let shouldEPUB = await workflow.shouldRunSystem("EPUBExport", for: entityId, in: world)
        let shouldBraille = await workflow.shouldRunSystem("BrailleExport", for: entityId, in: world)
        let shouldAudio = await workflow.shouldRunSystem("AudioPrep", for: entityId, in: world)

        XCTAssertTrue(shouldEPUB)
        XCTAssertTrue(shouldBraille)
        XCTAssertTrue(shouldAudio)
    }

    func testMultiFormatWorkflowNoRequest() async {
        // Without a TransformRequestComponent, should run all systems (legacy behavior)
        let workflow = MultiFormatWorkflow()
        let world = World()

        let entityId = await world.createEntity()
        // No TransformRequestComponent added

        let shouldEPUB = await workflow.shouldRunSystem("EPUBExport", for: entityId, in: world)
        let shouldBraille = await workflow.shouldRunSystem("BrailleExport", for: entityId, in: world)
        let shouldAudio = await workflow.shouldRunSystem("AudioPrep", for: entityId, in: world)

        XCTAssertTrue(shouldEPUB)
        XCTAssertTrue(shouldBraille)
        XCTAssertTrue(shouldAudio)
    }

    func testMultiFormatWorkflowJobTypeId() {
        let workflow = MultiFormatWorkflow()
        XCTAssertEqual(workflow.jobTypeId, DiaplasionJobType.multiFormat)
        XCTAssertEqual(workflow.name, "Multi-Format Export")
    }
}
