import XCTest
@testable import TextChunkingCapsule
import CapsuleCore
import AnigmaNativeShims

final class EnhancedTextChunkingCapsuleTests: XCTestCase {
    
    var chunkingCapsule: EnhancedTextChunkingCapsuleWrapper!
    
    override func setUp() async throws {
        try super.setUp()
        chunkingCapsule = try EnhancedTextChunkingCapsuleWrapper()
    }
    
    override func tearDown() async throws {
        chunkingCapsule = nil
        try super.tearDown()
    }
    
    // MARK: - Identity Tests
    
    func testCapsuleIdentity() throws {
        let identity = EnhancedTextChunkingCapsuleWrapper.identity
        
        XCTAssertEqual(identity.capsule_id, "text_chunking_capsule")
        XCTAssertEqual(identity.algo_version, "1.0.0")
        XCTAssertEqual(identity.determinism_tier, 1)  // Tier 1: bitwise deterministic
        XCTAssertFalse(identity.build_hash.isEmpty)
    }
    
    // MARK: - Configuration Tests
    
    func testDefaultConfiguration() throws {
        let config = EnhancedTextChunkingCapsuleWrapper.configuration
        
        XCTAssertEqual(config.targetChunkSize, 2048)
        XCTAssertEqual(config.minChunkSize, 512)
        XCTAssertEqual(config.maxChunkSize, 8192)
        XCTAssertEqual(config.windowSize, 48)
        XCTAssertEqual(config.polynomial, 0x3DA3358B4DC173)
        XCTAssertEqual(config.determinismTier, 1)
        XCTAssertTrue(config.enableTextNormalization)
        XCTAssertTrue(config.enableBoundaryHinting)
        XCTAssertTrue(config.enableStableIds)
        XCTAssertEqual(config.documentIdPrefix, "doc")
    }
    
    func testCustomConfiguration() throws {
        let customConfig = EnhancedTextChunkingCapsuleConfig(
            targetChunkSize: 1024,
            minChunkSize: 256,
            maxChunkSize: 4096,
            windowSize: 64,
            polynomial: 0x7CB42689E697,
            determinismTier: 2,  // Epsilon-stable for testing
            enableTextNormalization: false,
            unicodeForm: .nfd,
            enableBoundaryHinting: false,
            enableStableIds: true,
            documentIdPrefix: "test"
        )
        
        let capsule = try EnhancedTextChunkingCapsuleWrapper(config: customConfig)
        
        XCTAssertEqual(capsule.configuration.targetChunkSize, 1024)
        XCTAssertEqual(capsule.configuration.minChunkSize, 256)
        XCTAssertEqual(capsule.configuration.maxChunkSize, 4096)
        XCTAssertEqual(capsule.configuration.windowSize, 64)
        XCTAssertEqual(capsule.configuration.polynomial, 0x7CB42689E697)
        XCTAssertEqual(capsule.configuration.determinismTier, 2)
        XCTAssertFalse(capsule.configuration.enableTextNormalization)
        XCTAssertEqual(capsule.configuration.unicodeForm, .nfd)
        XCTAssertFalse(capsule.configuration.enableBoundaryHinting)
        XCTAssertTrue(capsule.configuration.enableStableIds)
        XCTAssertEqual(capsule.configuration.documentIdPrefix, "test")
    }
    
    // MARK: - Basic Chunking Tests
    
    func testProcessEmptyData() throws {
        let emptyData = Data()
        try chunkingCapsule.processBytes(emptyData)
        
        XCTAssertEqual(chunkingCapsule.bytesProcessed, 0)
    }
    
    func testProcessSimpleText() throws {
        let textData = "Hello, world! This is a test of the enhanced text chunking system."
        try chunkingCapsule.processBytes(textData)
        
        XCTAssertEqual(chunkingCapsule.bytesProcessed, UInt64(textData.utf8.count))
    }
    
    func testChunkingNotFinalizedError() throws {
        let textData = "Some test data"
        try chunkingCapsule.processBytes(textData)
        
        XCTAssertThrowsError(try chunkingCapsule.boundaries()) { error in
            XCTAssertTrue(error is CapsuleError)
        }
    }
    
    func testFinalizeAndGetBoundaries() throws {
        let textData = "This is sentence one. This is sentence two. This is sentence three."
        try chunkingCapsule.processBytes(textData)
        try chunkingCapsule.finalize()
        
        let boundaries = try chunkingCapsule.enhancedBoundaries()
        
        XCTAssertGreaterThanOrEqual(boundaries.count, 3)
        
        // Check stable IDs format
        for boundary in boundaries {
            XCTAssertTrue(boundary.stableId.starts(with: "doc_"))
            XCTAssertTrue(boundary.stableId.contains("_"))
            
            let components = boundary.stableId.split(separator: "_")
            XCTAssertGreaterThanOrEqual(components.count, 3)
        }
    }
    
    func testExtractChunks() throws {
        let textData = "First sentence. Second sentence. Third sentence with more text here."
        try chunkingCapsule.processBytes(textData)
        try chunkingCapsule.finalize()
        
        let chunks = try chunkingCapsule.extractChunks(from: textData)
        
        XCTAssertEqual(chunks.count, 3)
        
        let firstChunk = chunks[0]
        let secondChunk = chunks[1]  
        let thirdChunk = chunks[2]
        
        XCTAssertEqual(String(data: firstChunk), "First sentence.")
        XCTAssertEqual(String(data: secondChunk), " Second sentence.")
        XCTAssertTrue(String(data: thirdChunk).hasPrefix("Third sentence"))
    }
    
    func testOneShotChunking() throws {
        let textData = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
        let chunks = try EnhancedTextChunkingCapsuleWrapper.chunkEnhanced(textData)
        
        XCTAssertGreaterThan(chunks.count, 0)
        XCTAssertLessThanOrEqual(chunks.count, 20)  // Reasonable limit for most text
        
        // Verify stable IDs
        for (index, chunk) in chunks.enumerated() {
            XCTAssertTrue(chunk.stableId.starts(with: "doc_"))
            let chunkText = String(data: chunk.slice(from: chunk.offset, length: chunk.length))
            XCTAssertEqual(chunk.stableId, "doc_\(index)_\(chunk.length)_\(chunkText.hash)")
        }
    }
    
    // MARK: - TextPipeline Integration Tests
    
    func testTextNormalization() throws {
        let config = EnhancedTextChunkingCapsuleConfig(
            targetChunkSize: 512,
            enableTextNormalization: true,
            unicodeForm: .nfc,
            documentIdPrefix: "norm_test"
        )
        
        let capsule = try EnhancedTextChunkingCapsuleWrapper(config: config)
        
        let textData = "café résumé naïve"
        try capsule.processBytes(textData)
        try capsule.finalize()
        
        let boundaries = try capsule.enhancedBoundaries()
        
        XCTAssertGreaterThan(boundaries.count, 0)
        
        // Verify normalization was applied (chunks should be normalized NFC)
        for boundary in boundaries {
            let chunkText = String(data: try capsule.extractChunks(from: textData)[boundary.offset])
            // Normalized text should have composed characters where possible
            XCTAssertTrue(chunkText.contains("résumé"))
            XCTAssertTrue(chunkText.contains("naïve"))
        }
    }
    
    func testBoundaryHinting() throws {
        let config = EnhancedTextChunkingCapsuleConfig(
            targetChunkSize: 256,
            enableBoundaryHinting: true,
            documentIdPrefix: "boundary_test"
        )
        
        let capsule = try EnhancedTextChunkingCapsuleWrapper(config: config)
        
        // Text with clear sentence boundaries
        let textData = "First sentence. Second sentence! Third sentence? Fourth sentence."
        try capsule.processBytes(textData)
        try capsule.finalize()
        
        let boundaries = try capsule.enhancedBoundaries()
        
        // Should get more boundaries with sentence hints
        XCTAssertGreaterThan(boundaries.count, 2)
        
        // Check for sentence boundaries in boundary types
        let hasSentenceBoundaries = boundaries.contains { $0.type.lowercased().contains("sentence") }
        XCTAssertTrue(hasSentenceBoundaries)
    }
    
    // MARK: - Stable ID Tests
    
    func testStableIdGeneration() throws {
        let config = EnhancedTextChunkingCapsuleConfig(
            targetChunkSize: 100,
            enableStableIds: true,
            documentIdPrefix: "id_test"
        )
        
        let capsule = try EnhancedTextChunkingCapsuleWrapper(config: config)
        
        let textData = "Test chunk one. Test chunk two. Test chunk three."
        try capsule.processBytes(textData, documentId: "doc123")
        try capsule.finalize()
        
        let chunks = try capsule.enhancedBoundaries()
        
        XCTAssertEqual(chunks.count, 3)
        
        // Verify deterministic ID generation
        let firstChunkId = chunks[0].stableId
        let secondChunkId = chunks[1].stableId
        let thirdChunkId = chunks[2].stableId
        
        // IDs should include the custom document ID
        XCTAssertTrue(firstChunkId.contains("doc123"))
        XCTAssertTrue(secondChunkId.contains("doc123"))
        XCTAssertTrue(thirdChunkId.contains("doc123"))
        
        // IDs should be reproducible
        let chunkText1 = String(data: try capsule.extractChunks(from: textData)[0])
        let chunkText2 = String(data: try capsule.extractChunks(from: textData)[1])
        let chunkText3 = String(data: try capsule.extractChunks(from: textData)[2])
        
        XCTAssertEqual(firstChunkId, "doc123_17_\"Test chunk one\"_\(chunkText1.hash)")
        XCTAssertEqual(secondChunkId, "doc123_23_\"Test chunk two\"_\(chunkText2.hash)")
        XCTAssertEqual(thirdChunkId, "doc123_33_\"Test chunk three\"_\(chunkText3.hash)")
    }
    
    func testDeterminism() throws {
        let textData = "Test text for determinism checking."
        let config = EnhancedTextChunkingCapsuleConfig(
            targetChunkSize: 100,
            determinismTier: 1,  // Bitwise deterministic
            enableStableIds: true
        )
        
        let capsule1 = try EnhancedTextChunkingCapsuleWrapper(config: config)
        let capsule2 = try EnhancedTextChunkingCapsuleWrapper(config: config)
        
        try capsule1.processBytes(textData, documentId: "det_test")
        try capsule1.finalize()
        try capsule2.processBytes(textData, documentId: "det_test")
        try capsule2.finalize()
        
        let chunks1 = try capsule1.enhancedBoundaries()
        let chunks2 = try capsule2.enhancedBoundaries()
        
        // Results should be identical for deterministic capsule
        XCTAssertEqual(chunks1.count, chunks2.count)
        
        for (index, chunk1) in chunks1.enumerated() {
            let chunk2 = chunks2[index]
            XCTAssertEqual(chunk1.stableId, chunk2.stableId)
            XCTAssertEqual(chunk1.type, chunk2.type)
            XCTAssertEqual(chunk1.confidence, chunk2.confidence)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testProcessDataAfterReset() throws {
        let textData1 = "First data"
        let textData2 = "Second data"
        
        try chunkingCapsule.processBytes(textData1)
        try chunkingCapsule.reset()
        try chunkingCapsule.processBytes(textData2)
        
        XCTAssertEqual(chunkingCapsule.bytesProcessed, UInt64(textData2.utf8.count))
        
        let boundaries = try chunkingCapsule.boundaries()
        XCTAssertEqual(boundaries.count, 1)
        
        // Should only contain chunking for second data
        let chunkText = String(data: try chunkingCapsule.extractChunks(from: textData2)[0])
        XCTAssertTrue(chunkText.contains("Second data"))
        XCTAssertFalse(chunkText.contains("First data"))
    }
    
    func testExtractChunksWithoutFinalize() throws {
        let textData = "Should not be able to extract without finalization"
        let capsule = try EnhancedTextChunkingCapsuleWrapper()
        
        try capsule.processBytes(textData)
        
        XCTAssertThrowsError(try capsule.extractChunks(from: textData)) { error in
            XCTAssertTrue(error is CapsuleError)
        }
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceTextProcessing() throws {
        let textData = String(repeating: "This is a test sentence with Unicode: café résumé naïve. ", count: 1000)
        
        measure {
            do {
                let capsule = try EnhancedTextChunkingCapsuleWrapper(
                    config: EnhancedTextChunkingConfig(
                        targetChunkSize: 1024,
                        enableTextNormalization: true
                    )
                )
                try capsule.processBytes(textData)
                try capsule.finalize()
                _ = try capsule.enhancedBoundaries()
            } catch {
                XCTFail("Text processing failed: \(error)")
            }
        }
    }
    
    func testPerformanceStableIdGeneration() throws {
        let textData = String(repeating: "Test chunk content. ", count: 1000)
        
        measure {
            do {
                let capsule = try EnhancedTextChunkingCapsuleWrapper(
                    config: EnhancedTextChunkingConfig(
                        targetChunkSize: 256,
                        enableStableIds: true,
                        documentIdPrefix: "perf_test"
                    )
                )
                
                for i in 0..<100 {
                    let chunkText = "Test chunk content \(i). "
                    try capsule.processBytes(chunkText, documentId: "perf_test")
                    try capsule.finalize()
                    _ = try capsule.enhancedBoundaries()
                }
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
}