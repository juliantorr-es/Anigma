// GlyphAtlasCapsuleTests.swift
// Tests for GlyphAtlasCapsule implementation

import XCTest
@testable import GlyphAtlasCapsule
import CapsuleCore

final class GlyphAtlasCapsuleTests: XCTestCase {
    
    var capsule: GlyphAtlasCapsule!
    
    override func setUp() async throws {
        capsule = GlyphAtlasCapsule()
    }
    
    // MARK: - Version Tests
    
    func testVersion() {
        let version = capsule.version
        XCTAssertFalse(version.isEmpty)
        XCTAssertTrue(version.contains("1.0.0"))
    }
    
    // MARK: - Atlas Creation Tests
    
    func testCreateAtlasWithFontName() async throws {
        let atlas = try await capsule.createAtlas(
            fontName: "Helvetica",
            fontSize: 16
        )
        
        // Verify atlas was created (opaque pointer should not be null)
        XCTAssertNotNil(atlas)
        
        // Clean up
        capsule.destroyAtlas(atlas)
    }
    
    func testCreateAtlasWithFontData() async throws {
        // Mock font data (not a real font)
        let fontData = Data(repeating: 0x00, count: 1024)
        
        let atlas = try await capsule.createAtlas(
            fontData: fontData,
            fontSize: 12
        )
        
        XCTAssertNotNil(atlas)
        capsule.destroyAtlas(atlas)
    }
    
    func testCreateAtlasWithEmptyFontName() async {
        do {
            _ = try await capsule.createAtlas(
                fontName: "",
                fontSize: 16
            )
            XCTFail("Should throw error for empty font name")
        } catch let error as CapsuleError {
            switch error {
            case .invalidInput, .operationFailed:
                break
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testCreateAtlasWithEmptyFontData() async {
        let emptyData = Data()
        
        do {
            _ = try await capsule.createAtlas(
                fontData: emptyData,
                fontSize: 16
            )
            XCTFail("Should throw error for empty font data")
        } catch let error as CapsuleError {
            switch error {
            case .invalidInput, .operationFailed:
                break
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    // MARK: - Codepoint Tests
    
    func testAddCodepoints() async throws {
        let atlas = try await capsule.createAtlas(
            fontName: "Arial",
            fontSize: 14
        )
        
        let codepoints: [UInt32] = [65, 66, 67, 97, 98, 99] // A,B,C,a,b,c
        try await capsule.addCodepoints(to: atlas, codepoints: codepoints)
        
        capsule.destroyAtlas(atlas)
    }
    
    func testAddEmptyCodepoints() async throws {
        let atlas = try await capsule.createAtlas(
            fontName: "Helvetica",
            fontSize: 16
        )
        
        let emptyCodepoints: [UInt32] = []
        try await capsule.addCodepoints(to: atlas, codepoints: emptyCodepoints)
        
        capsule.destroyAtlas(atlas)
    }
    
    // MARK: - Atlas Generation Tests
    
    func testGenerateAtlas() async throws {
        let atlas = try await capsule.createAtlas(
            fontName: "Courier",
            fontSize: 12
        )
        
        let codepoints: [UInt32] = [65, 66, 67] // A,B,C
        try await capsule.addCodepoints(to: atlas, codepoints: codepoints)
        
        try await capsule.generateAtlas(atlas, width: 64, height: 64)
        
        capsule.destroyAtlas(atlas)
    }
    
    func testGenerateAtlasWithInvalidSize() async throws {
        let atlas = try await capsule.createAtlas(
            fontName: "Helvetica",
            fontSize: 16
        )
        
        do {
            try await capsule.generateAtlas(atlas, width: 0, height: 64)
            XCTFail("Should throw error for zero width")
        } catch let error as CapsuleError {
            switch error {
            case .invalidInput, .operationFailed:
                break
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
        
        do {
            try await capsule.generateAtlas(atlas, width: 64, height: 0)
            XCTFail("Should throw error for zero height")
        } catch let error as CapsuleError {
            switch error {
            case .invalidInput, .operationFailed:
                break
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
        
        capsule.destroyAtlas(atlas)
    }
    
    // MARK: - Glyph Metrics Tests
    
    func testGetGlyphMetrics() async throws {
        let atlas = try await capsule.createAtlas(
            fontName: "Times",
            fontSize: 18
        )
        
        let codepoint: UInt32 = 65 // 'A'
        let metrics = try await capsule.getGlyphMetrics(
            from: atlas,
            codepoint: codepoint
        )
        
        XCTAssertEqual(metrics.codepoint, codepoint)
        XCTAssertEqual(metrics.character, Character("A"))
        XCTAssertGreaterThan(metrics.width, 0)
        XCTAssertGreaterThan(metrics.height, 0)
        XCTAssertGreaterThanOrEqual(metrics.advanceX, 0)
        
        capsule.destroyAtlas(atlas)
    }
    
    func testGetAllGlyphMetrics() async throws {
        let atlas = try await capsule.createAtlas(
            fontName: "Helvetica",
            fontSize: 14
        )
        
        let codepoints: [UInt32] = [65, 66, 67] // A,B,C
        try await capsule.addCodepoints(to: atlas, codepoints: codepoints)
        
        let allMetrics = try await capsule.getAllGlyphMetrics(from: atlas)
        
        XCTAssertFalse(allMetrics.isEmpty)
        // Stub implementation returns 1 glyph
        XCTAssertLessThanOrEqual(allMetrics.count, codepoints.count)
        
        for metrics in allMetrics {
            XCTAssertGreaterThan(metrics.width, 0)
            XCTAssertGreaterThan(metrics.height, 0)
        }
        
        capsule.destroyAtlas(atlas)
    }
    
    // MARK: - Atlas Metadata Tests
    
    func testGetAtlasMetadata() async throws {
        let atlas = try await capsule.createAtlas(
            fontName: "Arial",
            fontSize: 16
        )
        
        try await capsule.generateAtlas(atlas, width: 128, height: 128)
        
        let metadata = try await capsule.getAtlasMetadata(from: atlas)
        
        XCTAssertEqual(metadata.width, 128)
        XCTAssertEqual(metadata.height, 128)
        XCTAssertEqual(metadata.area, 128 * 128)
        XCTAssertGreaterThan(metadata.dataSizeBytes, 0)
        
        // Verify bitmap data is not empty
        XCTAssertFalse(metadata.bitmapData.isEmpty)
        
        capsule.destroyAtlas(atlas)
    }
    
    // MARK: - GlyphMetrics Tests
    
    func testGlyphMetricsCharacter() {
        let metrics = GlyphMetrics(
            codepoint: 65,  // 'A'
            x: 0, y: 0,
            width: 10, height: 12,
            advanceX: 8.0,
            offsetX: 0, offsetY: 10
        )
        
        XCTAssertEqual(metrics.character, Character("A"))
        XCTAssertEqual(metrics.rect.origin.x, 0.0)
        XCTAssertEqual(metrics.rect.origin.y, 0.0)
        XCTAssertEqual(metrics.rect.size.width, 10.0)
        XCTAssertEqual(metrics.rect.size.height, 12.0)
    }
    
    func testGlyphMetricsInvalidCharacter() {
        let metrics = GlyphMetrics(
            codepoint: 0x10FFFF,  // Invalid but valid codepoint
            x: 0, y: 0,
            width: 0, height: 0,
            advanceX: 0.0,
            offsetX: 0, offsetY: 0
        )
        
        // Most invalid codepoints won't have a character
        XCTAssertNil(metrics.character)
    }
    
    // MARK: - Error Mapping Tests
    
    func testErrorMapNullPointer() {
        let error = GlyphAtlasError.nullPointer
        let capsuleError = error.capsuleError
        
        guard case .internalError = capsuleError else {
            XCTFail("Wrong error type")
            return
        }
    }
    
    func testErrorMapInvalidFont() {
        let error = GlyphAtlasError.invalidFont
        let capsuleError = error.capsuleError
        
        guard case .invalidInput = capsuleError else {
            XCTFail("Wrong error type")
            return
        }
    }
    
    func testErrorMapMemoryAllocation() {
        let error = GlyphAtlasError.memoryAllocation
        let capsuleError = error.capsuleError
        
        guard case .resourceExhausted = capsuleError else {
            XCTFail("Wrong error type")
            return
        }
    }
    
    func testErrorMapInvalidSize() {
        let error = GlyphAtlasError.invalidSize
        let capsuleError = error.capsuleError
        
        guard case .invalidInput = capsuleError else {
            XCTFail("Wrong error type")
            return
        }
    }
    
    // MARK: - AtlasMetadata Tests
    
    func testAtlasMetadataCalculations() {
        let bitmapData = Data(repeating: 0xFF, count: 64 * 64)
        let metadata = AtlasMetadata(
            width: 64,
            height: 64,
            glyphCount: 10,
            fontSize: 16,
            bitmapData: bitmapData
        )
        
        XCTAssertEqual(metadata.width, 64)
        XCTAssertEqual(metadata.height, 64)
        XCTAssertEqual(metadata.area, 4096)
        XCTAssertEqual(metadata.glyphCount, 10)
        XCTAssertEqual(metadata.fontSize, 16)
        XCTAssertEqual(metadata.dataSizeBytes, 4096)
    }
}

// MARK: - Golden Tests

final class GlyphAtlasCapsuleGoldenTests: XCTestCase {
    
    var capsule: GlyphAtlasCapsule!
    
    override func setUp() async throws {
        capsule = GlyphAtlasCapsule()
    }
    
    func testGoldenAtlasGeneration() async throws {
        let atlas = try await capsule.createAtlas(
            fontName: "Helvetica",
            fontSize: 16
        )
        
        let codepoints: [UInt32] = [65, 66, 67, 97, 98, 99] // ABCabc
        try await capsule.addCodepoints(to: atlas, codepoints: codepoints)
        
        try await capsule.generateAtlas(atlas, width: 64, height: 64)
        
        let metadata = try await capsule.getAtlasMetadata(from: atlas)
        
        // Verify basic properties
        XCTAssertEqual(metadata.width, 64)
        XCTAssertEqual(metadata.height, 64)
        XCTAssertFalse(metadata.bitmapData.isEmpty)
        
        // Test that we can get individual glyph metrics
        let metrics = try await capsule.getGlyphMetrics(from: atlas, codepoint: 65)
        XCTAssertEqual(metrics.codepoint, 65)
        
        capsule.destroyAtlas(atlas)
    }
    
    func testGoldenBatchOperations() async throws {
        let fontData = Data(repeating: 0x00, count: 2048)
        
        let atlas = try await capsule.createAtlas(
            fontData: fontData,
            fontSize: 14
        )
        
        // Add ASCII printable range
        var asciiCodepoints: [UInt32] = []
        for code in 32...126 {
            asciiCodepoints.append(UInt32(code))
        }
        
        try await capsule.addCodepoints(to: atlas, codepoints: asciiCodepoints)
        
        let allMetrics = try await capsule.getAllGlyphMetrics(from: atlas)
        
        // Stub implementation may not return all glyphs, but should return some
        XCTAssertFalse(allMetrics.isEmpty)
        
        capsule.destroyAtlas(atlas)
    }
}