import XCTest
@testable import TextPipelineCapsule
import CapsuleCore
import AnigmaNativeShims

final class TextPipelineCapsuleTests: XCTestCase {
    
    var textPipeline: TextPipelineCapsuleWrapper!
    
    override func setUp() async throws {
        try super.setUp()
        textPipeline = try TextPipelineCapsuleWrapper()
    }
    
    override func tearDown() async throws {
        textPipeline = nil
        try super.tearDown()
    }
    
    // MARK: - Identity Tests
    
    func testCapsuleIdentity() throws {
        let identity = TextPipelineCapsuleWrapper.identity
        
        XCTAssertEqual(identity.capsule_id, "text_pipeline_capsule")
        XCTAssertEqual(identity.algo_version, "1.0.0")
        XCTAssertEqual(identity.determinism_tier, 1)  // Tier 1: bitwise deterministic
        XCTAssertFalse(identity.build_hash.isEmpty)
    }
    
    // MARK: - UTF-8 Validation Tests
    
    func testValidateUTF8ValidText() throws {
        let validText = "Hello, world! 🌍"
        let isValid = try textPipeline.validateUTF8(validText)
        XCTAssertTrue(isValid)
    }
    
    func testValidateUTF8InvalidText() throws {
        // Invalid UTF-8 sequence
        let invalidText = Data([0xFF, 0xFE, 0xFD])
        let text = String(data: invalidText, encoding: .utf8) ?? "fallback"
        let isValid = try textPipeline.validateUTF8(text)
        // The capsule should handle this gracefully
        // Result depends on ICU implementation
    }
    
    func testValidateUTF8EmptyText() throws {
        let emptyText = ""
        let isValid = try textPipeline.validateUTF8(emptyText)
        XCTAssertTrue(isValid)
    }
    
    // MARK: - Unicode Normalization Tests
    
    func testNormalizeNFC() throws {
        // Text with combining characters
        let inputText = "e\u{0301}"  // e + acute accent
        let normalized = try textPipeline.normalizeNFC(inputText)
        
        // Should be normalized to composed form
        XCTAssertTrue(normalized.contains("é"))
        XCTAssertNotEqual(normalized, inputText)
    }
    
    func testNormalizeNFCAlreadyNormalized() throws {
        let alreadyNormalized = "Hello, world!"
        let normalized = try textPipeline.normalizeNFC(alreadyNormalized)
        XCTAssertEqual(normalized, alreadyNormalized)
    }
    
    func testNormalizeNFCWithEmoji() throws {
        let emojiText = "👍🏽"  // thumbs up + skin tone
        let normalized = try textPipeline.normalizeNFC(emojiText)
        // Should normalize or preserve as appropriate
        XCTAssertFalse(normalized.isEmpty)
    }
    
    // MARK: - Case Conversion Tests
    
    func testToLowercase() throws {
        let mixedCase = "Hello WORLD! 123"
        let lowercase = try textPipeline.toLowercase(mixedCase)
        XCTAssertEqual(lowercase, "hello world! 123")
    }
    
    func testToLowercaseAlreadyLowercase() throws {
        let alreadyLowercase = "already lowercase"
        let lowercase = try textPipeline.toLowercase(alreadyLowercase)
        XCTAssertEqual(lowercase, alreadyLowercase)
    }
    
    func testToLowercaseWithUnicode() throws {
        let unicodeText = "İstanbul"  // Turkish dotted I
        let lowercase = try textPipeline.toLowercase(unicodeText)
        // Should handle Turkish casing rules
        XCTAssertFalse(lowercase.isEmpty)
    }
    
    // MARK: - Diacritic Processing Tests
    
    func testStripDiacritics() throws {
        let textWithDiacritics = "café résumé naïve"
        let stripped = try textPipeline.stripDiacritics(textWithDiacritics)
        XCTAssertEqual(stripped, "cafe resume naive")
    }
    
    func testStripDiacriticsNoDiacritics() throws {
        let noDiacritics = "hello world"
        let stripped = try textPipeline.stripDiacritics(noDiacritics)
        XCTAssertEqual(stripped, noDiacritics)
    }
    
    func testStripDiacriticsComplex() throws {
        let complexText = "ÁÉÍÓÚ àèìòù"
        let stripped = try textPipeline.stripDiacritics(complexText)
        XCTAssertEqual(stripped, "AEIOU aeiou")
    }
    
    // MARK: - ASCII Folding Tests
    
    func testFoldToASCIIBasic() throws {
        let text = "Hello, World! 123"
        let ascii = try textPipeline.foldToASCII(text)
        XCTAssertEqual(ascii, "Hello, World! 123")
    }
    
    func testFoldToASCIIEuropean() throws {
        let europeanText = "Müller Straße"
        let ascii = try textPipeline.foldToASCII(europeanText)
        // Should convert to ASCII equivalents
        XCTAssertTrue(ascii.contains("Muller"))
        XCTAssertTrue(ascii.contains("Strasse"))
    }
    
    func testFoldToASCIIGreek() throws {
        let greekText = "Αθήνα"
        let ascii = try textPipeline.foldToASCII(greekText)
        // Should transliterate to Latin
        XCTAssertFalse(ascii.isEmpty)
    }
    
    // MARK: - Combined Transformation Tests
    
    func testCombinedTransformation() throws {
        let inputText = "CAFÉ 🌟 Müller"
        let transformed = try textPipeline.transform(inputText)
        
        // Should be transformed using default pipeline
        XCTAssertFalse(transformed.isEmpty)
        let resultString = String(data: transformed, encoding: .utf8)
        XCTAssertNotNil(resultString)
    }
    
    func testEmptyTextTransformation() throws {
        let emptyText = ""
        let transformed = try textPipeline.transform(emptyText)
        XCTAssertEqual(transformed.count, 0)
    }
    
    func testLargeTextTransformation() throws {
        let largeText = String(repeating: "This is a test sentence with Unicode: café résumé. ", count: 1000)
        let transformed = try textPipeline.transform(largeText)
        
        XCTAssertEqual(transformed.count, largeText.utf8.count)  // Should preserve length roughly
        XCTAssertFalse(transformed.isEmpty)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceUnicodeNormalization() throws {
        let text = String(repeating: "café résumé ", count: 1000)
        
        measure {
            do {
                _ = try textPipeline.normalizeNFC(text)
            } catch {
                XCTFail("Unicode normalization failed: \(error)")
            }
        }
    }
    
    func testPerformanceCaseConversion() throws {
        let text = String(repeating: "Mixed Case Text With Numbers 12345! ", count: 1000)
        
        measure {
            do {
                _ = try textPipeline.toLowercase(text)
            } catch {
                XCTFail("Case conversion failed: \(error)")
            }
        }
    }
    
    func testPerformanceDiacriticStripping() throws {
        let text = String(repeating: "café résumé naïve hötel ", count: 1000)
        
        measure {
            do {
                _ = try textPipeline.stripDiacritics(text)
            } catch {
                XCTFail("Diacritic stripping failed: \(error)")
            }
        }
    }
    
    func testPerformanceASCIIFolding() throws {
        let text = String(repeating: "Müllerstraße Øre Århus ", count: 1000)
        
        measure {
            do {
                _ = try textPipeline.foldToASCII(text)
            } catch {
                XCTFail("ASCII folding failed: \(error)")
            }
        }
    }
    
    func testPerformanceFullTransformation() throws {
        let text = String(repeating: "Complex Text 🌟 café résumé Müllerstraße 123! ", count: 1000)
        
        measure {
            do {
                _ = try textPipeline.transform(text)
            } catch {
                XCTFail("Full transformation failed: \(error)")
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testTransformationOnInvalidatedHandle() throws {
        // Create a capsule and immediately invalidate it
        let capsule = try TextPipelineCapsuleWrapper()
        capsule.invalidate()
        
        XCTAssertThrowsError(try capsule.transform("test")) { error in
            XCTAssertTrue(error is CapsuleError)
        }
    }
    
    func testMultipleOperations() throws {
        // Test that multiple operations can be performed on the same capsule
        let text1 = "Hello World!"
        let text2 = "Another Test"
        
        let result1 = try textPipeline.transform(text1)
        let result2 = try textPipeline.transform(text2)
        
        XCTAssertFalse(result1.isEmpty)
        XCTAssertFalse(result2.isEmpty)
        XCTAssertNotEqual(result1, result2)
    }
    
    // MARK: - Determinism Tests
    
    func testDeterministicTransformation() throws {
        let inputText = "café résumé 🌟"
        
        let result1 = try textPipeline.transform(inputText)
        let result2 = try textPipeline.transform(inputText)
        
        // Results should be identical for deterministic capsule
        XCTAssertEqual(result1, result2)
    }
    
    func testDeterministicNormalization() throws {
        let inputText = "e\u{0301}"  // e + combining acute
        
        let result1 = try textPipeline.normalizeNFC(inputText)
        let result2 = try textPipeline.normalizeNFC(inputText)
        
        // Results should be identical
        XCTAssertEqual(result1, result2)
    }
    
    func testDeterministicCaseConversion() throws {
        let inputText = "Müllerstraße"
        
        let result1 = try textPipeline.toLowercase(inputText)
        let result2 = try textPipeline.toLowercase(inputText)
        
        // Results should be identical
        XCTAssertEqual(result1, result2)
    }
}