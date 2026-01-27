import XCTest
import CapsuleCore
import TelemetryCore
@testable import DocumentIRKit

final class DocumentIRKitContractTests: XCTestCase {
    
    override func setUp() async throws {
        // Any setup needed for contract tests
    }
    
    /// Contract: DocumentIR must be Codable and round-trip correctly
    func testCodableContract() throws {
        let document = DocumentIRBuilder.document(
            id: "test-doc",
            title: "Test Document"
        )
        .addChild(
            DocumentIRBuilder.paragraph(id: "para-1")
            .addChild(DocumentIRBuilder.text("Hello world"))
            .build()
        )
        .build()
        
        // Test encoding
        let jsonData = try DocumentIRSerialization.encodeToJSON(document)
        XCTAssertFalse(jsonData.isEmpty)
        
        // Test decoding
        let decodedDocument = try DocumentIRSerialization.decodeFromJSON(jsonData)
        XCTAssertEqual(document, decodedDocument)
    }
    
    /// Contract: Serialization must handle errors gracefully
    func testSerializationErrorHandling() async throws {
        let invalidJSON = Data("{ invalid json }".utf8)
        
        do {
            _ = try DocumentIRSerialization.decodeFromJSON(invalidJSON)
            XCTFail("Should have thrown decoding error")
        } catch let error as SerializationError {
            switch error {
            case .decodingFailed(let message):
                XCTAssertFalse(message.isEmpty)
            default:
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Should have been SerializationError")
        }
    }
    
    /// Contract: All node types must be Sendable and Equatable
    func testNodeContracts() throws {
        let text = DocumentIRBuilder.text("test")
        let emphasis = DocumentIRBuilder.emphasis(id: "em-1", children: [text])
        
        // Test equality
        let identicalText = DocumentIRBuilder.text("test")
        XCTAssertEqual(text, identicalText)
        
        // Test Sendable (compiler will enforce)
        let sendableText: any Sendable = text
        XCTAssertNotNil(sendableText)
    }
    
    /// Contract: Visitor pattern must visit all node types
    func testVisitorContract() throws {
        let document = DocumentIRBuilder.document(id: "test-doc")
            .addChild(DocumentIRBuilder.text("Hello"))
            .addChild(DocumentIRBuilder.emphasis(id: "em-1", children: [DocumentIRBuilder.text("world")]))
            .build()
        
        let countingVisitor = NodeCountingVisitor()
        let traversal = DocumentIRTraversal(visitor: countingVisitor)
        traversal.traverseDepthFirst(document)
        
        let counts = countingVisitor.getCounts()
        XCTAssertEqual(counts["document"], 1)
        XCTAssertEqual(counts["text"], 2)
        XCTAssertEqual(counts["emphasis"], 1)
    }
    
    /// Contract: Text extraction must handle nested nodes
    func testTextExtractionContract() throws {
        let document = DocumentIRBuilder.document(id: "test-doc")
            .addChild(
                DocumentIRBuilder.paragraph(id: "para-1")
                .addChild(DocumentIRBuilder.text("Hello "))
                .addChild(DocumentIRBuilder.emphasis(id: "em-1", children: [DocumentIRBuilder.text("world")]))
                .addChild(DocumentIRBuilder.text("!"))
                .build()
            )
            .build()
        
        let extractedText = DocumentIRSerialization.extractText(document)
        XCTAssertEqual(extractedText, "Hello world!")
    }
    
    /// Contract: Image collection must find all images
    func testImageCollectionContract() throws {
        let image1 = DocumentIRBuilder.image(id: "img-1", source: "test1.jpg", altText: "Test 1")
        let image2 = DocumentIRBuilder.image(id: "img-2", source: "test2.jpg", altText: "Test 2")
        
        let document = DocumentIRBuilder.document(id: "test-doc")
            .addChild(image1)
            .addChild(image2)
            .build()
        
        let images = DocumentIRSerialization.extractImages(document)
        XCTAssertEqual(images.count, 2)
        XCTAssertEqual(images[0].id, "img-1")
        XCTAssertEqual(images[1].id, "img-2")
    }
    
    /// Contract: Link collection must find all links
    func testLinkCollectionContract() throws {
        let link1 = DocumentIRBuilder.link(id: "link-1", url: "https://example.com")
        let link2 = DocumentIRBuilder.link(id: "link-2", url: "https://test.com", title: "Test")
        
        let document = DocumentIRBuilder.document(id: "test-doc")
            .addChild(link1)
            .addChild(link2)
            .build()
        
        let links = DocumentIRSerialization.extractLinks(document)
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(links[0].url, "https://example.com")
        XCTAssertEqual(links[1].title, "Test")
    }
    
    /// Contract: Code block collection must find all code blocks
    func testCodeBlockCollectionContract() throws {
        let codeBlock1 = DocumentIRBuilder.codeBlock(id: "code-1", language: "swift", code: "let x = 1")
        let codeBlock2 = DocumentIRBuilder.codeBlock(id: "code-2", language: "python", code: "x = 1")
        
        let document = DocumentIRBuilder.document(id: "test-doc")
            .addChild(codeBlock1)
            .addChild(codeBlock2)
            .build()
        
        let codeBlocks = DocumentIRSerialization.extractCodeBlocks(document)
        XCTAssertEqual(codeBlocks.count, 2)
        XCTAssertEqual(codeBlocks[0].language, "swift")
        XCTAssertEqual(codeBlocks[1].language, "python")
    }
}