import XCTest
@testable import TextPipelineCapsule

final class TextPipelineCapsuleTests: XCTestCase {
    
/*
    func testTextPipelineCapsuleIdentity() throws {
        let identity = TextPipelineCapsuleWrapper.identity
        XCTAssertNotNil(identity)
        // Additional identity tests would go here
    }
*/
    
/*
    func testTokenization() throws {
        let text = "Hello, world! This is a test."
        let wrapper = try TextPipelineCapsuleWrapper(config: TextPipelineConfig())
        
        let tokens = try wrapper.tokenize(text, tokenizer: .word)
        XCTAssertGreaterThan(tokens.count, 0)
        
        // Check that tokens contain expected content
        let tokenTexts = tokens.map { $0.text }
        XCTAssertTrue(tokenTexts.contains("Hello"))
        XCTAssertTrue(tokenTexts.contains("world"))
        XCTAssertTrue(tokenTexts.contains("test"))
    }
    
    func testLanguageDetection() throws {
        let englishText = "Hello, how are you today?"
        let wrapper = try TextPipelineCapsuleWrapper(config: TextPipelineConfig())
        
        let detection = try wrapper.detectLanguage(englishText)
        XCTAssertFalse(detection.language.isEmpty)
        XCTAssertGreaterThan(detection.confidence, 0.0)
        XCTAssertTrue(detection.isReliable)
    }
    
    func testSentimentAnalysis() throws {
        let positiveText = "This is a wonderful and amazing product!"
        let wrapper = try TextPipelineCapsuleWrapper(config: TextPipelineConfig())
        
        let sentiment = try wrapper.analyzeSentiment(positiveText)
        XCTAssertEqual(sentiment.sentiment, .positive)
        XCTAssertGreaterThan(sentiment.positiveScore, 0.5)
        XCTAssertLessThan(sentiment.negativeScore, 0.3)
    }
    
    func testNamedEntityRecognition() throws {
        let text = "Apple Inc. is based in Cupertino, California."
        let wrapper = try TextPipelineCapsuleWrapper(config: TextPipelineConfig())
        
        let entities = try wrapper.extractNamedEntities(text)
        XCTAssertGreaterThan(entities.count, 0)
        
        let entityTexts = entities.map { $0.text }
        XCTAssertTrue(entityTexts.contains("Apple"))
        XCTAssertTrue(entityTexts.contains("Cupertino"))
        XCTAssertTrue(entityTexts.contains("California"))
    }
    
    func testTextClassification() throws {
        let newsText = "The government announced new economic policies today."
        let wrapper = try TextPipelineCapsuleWrapper(config: TextPipelineConfig())
        
        let classification = try wrapper.classifyText(newsText)
        XCTAssertFalse(classification.category.isEmpty)
        XCTAssertGreaterThan(classification.confidence, 0.0)
    }
    
    func testCompletePipeline() throws {
        let text = "Apple Inc. announced great earnings today in Cupertino."
        let wrapper = try TextPipelineCapsuleWrapper(config: TextPipelineConfig())
        
        let result = try wrapper.processText(text)
        
        XCTAssertFalse(result.tokens.isEmpty)
        XCTAssertFalse(result.language.language.isEmpty)
        XCTAssertNotNil(result.sentiment)
        XCTAssertGreaterThanOrEqual(result.entities.count, 0)
    }
    
    func testConvenienceMethod() throws {
        let text = "This is a simple test text."
        let result = try TextPipelineCapsuleWrapper.process(text)
        
        XCTAssertFalse(result.tokens.isEmpty)
        XCTAssertFalse(result.language.language.isEmpty)
    }
*/
}