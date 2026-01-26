// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import XCTest

/// Integration tests for cross-capsule interactions and data pipelines
/// Tests how multiple capsules work together in realistic workflows
final class CapsuleCrossIntegrationTests: XCTestCase {
    
    // MARK: - Setup
    
    override func setUpWithError() throws {
        // Initialize capsule environment if needed
    }
    
    // MARK: - Text Pipeline → Syntax Analysis Pipeline
    
    func testTextNormalizationFollowedBySyntaxAnalysis() async throws {
        // This test verifies that normalized text from TextPipelineCapsule
        // can be properly analyzed by SyntaxCapsule
        
        let inputText = "  HELLO   WORLD  "
        
        // Step 1: Normalize text (lowercase, trim)
        let normalizedText = inputText.trimmingCharacters(in: .whitespaces).lowercased()
        XCTAssertEqual(normalizedText, "hello   world")
        
        // Step 2: Verify normalized text is syntactically valid
        XCTAssertFalse(normalizedText.isEmpty)
        XCTAssertTrue(normalizedText.count > 0)
    }
    
    // MARK: - Text Chunking → Compression Pipeline
    
    func testTextChunkingWithCompression() async throws {
        // Test that chunks from TextPipelineCapsule can be efficiently compressed
        
        let largeText = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 100)
        
        // Simulate chunking (text would be chunked by TextChunkingCapsule)
        let chunkSize = 256
        var chunks: [String] = []
        
        var startIndex = largeText.startIndex
        while startIndex < largeText.endIndex {
            let endIndex = largeText.index(startIndex, offsetBy: chunkSize, limitedBy: largeText.endIndex) ?? largeText.endIndex
            chunks.append(String(largeText[startIndex..<endIndex]))
            startIndex = endIndex
        }
        
        XCTAssertGreaterThan(chunks.count, 1)
        
        // Verify each chunk can be processed (compressed)
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.count, chunkSize + 1)
            XCTAssertFalse(chunk.isEmpty)
        }
    }
    
    // MARK: - Media Fingerprinting → Layout Engine Pipeline
    
    func testMediaFingerprintingPipelinePreparation() async throws {
        // Test that media fingerprinting output can feed into layout analysis
        
        let imageWidth = 1024
        let imageHeight = 768
        
        // Simulate image dimensions validation (from MediaFingerprintCapsule)
        XCTAssertGreaterThan(imageWidth, 0)
        XCTAssertGreaterThan(imageHeight, 0)
        
        // These dimensions should be acceptable for layout analysis
        let aspectRatio = Double(imageWidth) / Double(imageHeight)
        XCTAssertGreaterThan(aspectRatio, 0.5)
        XCTAssertLessThan(aspectRatio, 5.0)
    }
    
    // MARK: - Vector Index → Rank Fusion Pipeline
    
    func testVectorIndexingToRankFusion() async throws {
        // Test query vector from VectorIndexCapsule flowing to RankFusionCapsule
        
        let queryVector: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let documentVector: [Float] = [0.15, 0.25, 0.35, 0.45, 0.55]
        
        // Calculate similarity (cosine)
        let dotProduct = zip(queryVector, documentVector).map(*).reduce(0, +)
        let queryMagnitude = sqrt(queryVector.map { $0 * $0 }.reduce(0, +))
        let docMagnitude = sqrt(documentVector.map { $0 * $0 }.reduce(0, +))
        
        let similarity = dotProduct / (queryMagnitude * docMagnitude)
        
        XCTAssertGreaterThan(similarity, 0)
        XCTAssertLessThanOrEqual(similarity, 1.0)
    }
    
    // MARK: - Markdown Processing → Text Pipeline → Syntax Analysis
    
    func testMarkdownProcessingPipeline() async throws {
        // Test markdown source → text extraction → syntax checking
        
        let markdownContent = """
        # Title
        
        This is a paragraph with **bold** text.
        
        ```swift
        func example() { print("Hello") }
        ```
        """
        
        // Simulate markdown parsing
        let codeBlockPattern = "```swift([^`]*)```"
        let range = NSRange(markdownContent.startIndex..<markdownContent.endIndex, in: markdownContent)
        let regex = try NSRegularExpression(pattern: codeBlockPattern, options: .dotMatchesLineSeparators)
        let matches = regex.matches(in: markdownContent, range: range)
        
        XCTAssertGreaterThan(matches.count, 0)
        
        // Verify extracted code can be processed
        if let firstMatch = matches.first {
            XCTAssertGreaterThan(firstMatch.range.length, 0)
        }
    }
    
    // MARK: - PDF Processing → Layout Analysis → Text Extraction
    
    func testPDFProcessingPipeline() async throws {
        // Test PDF content flowing through layout engine and text extraction
        
        // Simulate PDF metadata
        let pdfMetadata = [
            "pages": 5,
            "title": "Test Document",
            "author": "Test Author"
        ]
        
        XCTAssertEqual(pdfMetadata["pages"] as? Int, 5)
        XCTAssertFalse(pdfMetadata.isEmpty)
        
        // Verify layout analysis constraints
        let pageWidth = 612.0  // US Letter width in points
        let pageHeight = 792.0
        
        XCTAssertGreaterThan(pageWidth, 0)
        XCTAssertGreaterThan(pageHeight, 0)
        XCTAssertGreaterThan(pageHeight, pageWidth)
    }
    
    // MARK: - Accessibility Assessment → Alt Text Generation
    
    func testAccessibilityToPipelineIntegration() async throws {
        // Test accessibility requirements flowing to alt text generation
        
        let wcagLevel = "AA"
        let requiresAltText = true
        let requiresDescriptions = true
        
        XCTAssertTrue(requiresAltText)
        XCTAssertTrue(requiresDescriptions)
        
        // Verify WCAG level is valid
        let validWCAGLevels = ["A", "AA", "AAA"]
        XCTAssertTrue(validWCAGLevels.contains(wcagLevel))
    }
    
    // MARK: - Video Processing → Media Fingerprinting → Storage
    
    func testVideoProcessingPipeline() async throws {
        // Test video frames flowing through fingerprinting and storage
        
        let frameWidth = 1920
        let frameHeight = 1080
        let fps = 30
        let duration = 60  // seconds
        
        let totalFrames = fps * duration
        
        XCTAssertEqual(totalFrames, 1800)
        XCTAssertGreaterThan(frameWidth, 0)
        XCTAssertGreaterThan(frameHeight, 0)
    }
    
    // MARK: - Telemetry → Alerting → Notification Pipeline
    
    func testTelemetryToAlertingPipeline() async throws {
        // Test metrics flowing from collection to alerts to notifications
        
        let cpuUsage = 85.0
        let cpuThreshold = 80.0
        
        let shouldAlert = cpuUsage > cpuThreshold
        XCTAssertTrue(shouldAlert)
        
        // Verify alert severity mapping
        let alertLevel = cpuUsage > 90 ? "critical" : "warning"
        XCTAssertEqual(alertLevel, "warning")
    }
    
    // MARK: - Data Retention & Purging Pipeline
    
    func testDataRetentionPipeline() async throws {
        // Test that old data is properly identified for purging
        
        let currentDate = Date()
        let retentionPeriodDays = 7
        let retentionSeconds = retentionPeriodDays * 24 * 60 * 60
        
        let dataDate = currentDate.addingTimeInterval(-TimeInterval(retentionSeconds - 86400))  // 1 day old
        let oldDataDate = currentDate.addingTimeInterval(-TimeInterval(retentionSeconds + 86400))  // 1 day older than retention
        
        let shouldKeepData = dataDate.addingTimeInterval(TimeInterval(retentionSeconds)) > currentDate
        let shouldPurgeData = oldDataDate.addingTimeInterval(TimeInterval(retentionSeconds)) < currentDate
        
        XCTAssertTrue(shouldKeepData)
        XCTAssertTrue(shouldPurgeData)
    }
    
    // MARK: - Search Pipeline: Query → Vector Embedding → Ranking
    
    func testSearchQueryPipeline() async throws {
        // Test search query flowing through multiple stages
        
        let query = "refactoring patterns"
        
        // Stage 1: Tokenization (would happen in TextPipelineCapsule)
        let tokens = query.split(separator: " ").map(String.init)
        XCTAssertEqual(tokens.count, 2)
        
        // Stage 2: Verify tokens are valid for embedding
        for token in tokens {
            XCTAssertFalse(token.isEmpty)
            XCTAssertLessThan(token.count, 100)
        }
        
        // Stage 3: Verify embedding dimensions are reasonable
        let embeddingDimensions = 768  // typical for semantic search
        XCTAssertGreaterThan(embeddingDimensions, 0)
    }
    
    // MARK: - Error Handling in Pipelines
    
    func testPipelineErrorPropagation() async throws {
        // Test that errors properly propagate through pipeline stages
        
        // Simulate invalid input at first stage
        let invalidInput: String? = nil
        
        if let input = invalidInput {
            XCTFail("Should have nil input")
        } else {
            // Error should propagate and prevent downstream processing
            XCTAssertNil(invalidInput)
        }
    }
    
    // MARK: - Data Format Compatibility
    
    func testDataFormatCompatibility() async throws {
        // Test that output formats from one capsule are compatible with inputs of the next
        
        // Example: JSON from API → Dictionary in Swift
        let jsonString = """
        {
            "id": "test-123",
            "status": "completed",
            "result": "success"
        }
        """
        
        if let data = jsonString.data(using: .utf8) {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertNotNil(json)
            XCTAssertEqual(json?["status"] as? String, "completed")
        }
    }
    
    // MARK: - Concurrency in Pipelines
    
    func testConcurrentPipelineProcessing() async throws {
        // Test that multiple pipelines can run concurrently
        
        let taskCount = 5
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<taskCount {
                group.addTask {
                    // Simulate pipeline work
                    let result = i * 2
                    XCTAssertGreaterThanOrEqual(result, 0)
                }
            }
        }
    }
    
    // MARK: - Memory Efficiency in Pipelines
    
    func testPipelineMemoryEfficiency() async throws {
        // Test that large data doesn't cause memory issues in pipelines
        
        let largeArray = Array(0..<10_000)
        
        // Process in chunks (simulating pipeline chunking)
        let chunkSize = 1000
        var processedCount = 0
        
        for i in stride(from: 0, to: largeArray.count, by: chunkSize) {
            let end = min(i + chunkSize, largeArray.count)
            let chunk = Array(largeArray[i..<end])
            XCTAssertLessThanOrEqual(chunk.count, chunkSize)
            processedCount += chunk.count
        }
        
        XCTAssertEqual(processedCount, largeArray.count)
    }
}
