import XCTest
import CapsuleCore
import TelemetryCore
@testable import DocumentIRKit

final class DocumentIRKitGoldenTests: XCTestCase {
    
    override func setUp() async throws {
        // Any setup needed for golden tests
    }
    
    func testGoldenDocumentSerialization() async throws {
        let document = DocumentIRBuilder.document(
            id: "golden-doc",
            title: "Golden Test Document",
            author: "Agent M"
        )
        .addChild(
            DocumentIRBuilder.section(id: "section-1", level: 1, title: "Introduction")
            .addChild(
                DocumentIRBuilder.paragraph(id: "para-1")
                .addChild(DocumentIRBuilder.text("This is a test document with "))
                .addChild(DocumentIRBuilder.emphasis(id: "em-1", children: [DocumentIRBuilder.text("emphasis")]))
                .addChild(DocumentIRBuilder.text(" and "))
                .addChild(DocumentIRBuilder.strong(id: "strong-1", children: [DocumentIRBuilder.text("strong")]))
                .addChild(DocumentIRBuilder.text(" text."))
                .build()
            )
            .addChild(
                DocumentIRBuilder.list(id: "list-1", type: .unordered)
                .addItem(
                    DocumentIRBuilder.listItem(id: "item-1")
                    .addChild(DocumentIRBuilder.text("First item"))
                    .build()
                )
                .addItem(
                    DocumentIRBuilder.listItem(id: "item-2")
                    .addChild(DocumentIRBuilder.text("Second item with "))
                    .addChild(DocumentIRBuilder.link(id: "link-1", url: "https://example.com", title: "Example"))
                    .build()
                )
                .build()
            )
            .build()
        )
        .addChild(
            DocumentIRBuilder.section(id: "section-2", level: 2, title: "Code Example")
            .addChild(
                DocumentIRBuilder.codeBlock(id: "code-1", language: "swift", code: """
                func greet(name: String) -> String {
                    return "Hello, \\(name)!"
                }
                """)
            )
            .build()
        )
        .build()
        
        let jsonString = try DocumentIRSerialization.encodeToJSONString(document)
        XCTAssertFalse(jsonString.isEmpty)
        
        // TODO: Implement actual golden comparison
        // Example using GoldenKit:
        /*
        try await GoldenKit.assertMatches(
            jsonString,
            named: "document_serialization",
            in: Bundle.module
        )
        */
        
        // Fallback for now: Check basic structure
        XCTAssertTrue(jsonString.contains("\"document\""))
        XCTAssertTrue(jsonString.contains("Golden Test Document"))
        XCTAssertTrue(jsonString.contains("emphasis"))
        XCTAssertTrue(jsonString.contains("https://example.com"))
        XCTAssertTrue(jsonString.contains("func greet"))
    }
    
    func testGoldenTextExtraction() async throws {
        let document = DocumentIRBuilder.document(id: "text-doc")
            .addChild(
                DocumentIRBuilder.paragraph(id: "para-1")
                .addChild(DocumentIRBuilder.text("Simple "))
                .addChild(DocumentIRBuilder.emphasis(id: "em-1", children: [DocumentIRBuilder.text("text")]))
                .addChild(DocumentIRBuilder.text(" extraction."))
                .build()
            )
            .build()
        
        let extractedText = DocumentIRSerialization.extractText(document)
        
        // TODO: Implement actual golden comparison
        // Example using GoldenKit:
        /*
        try await GoldenKit.assertMatches(
            extractedText,
            named: "text_extraction",
            in: Bundle.module
        )
        */
        
        // Fallback for now: Manual check
        XCTAssertEqual(extractedText, "Simple text extraction.")
    }
    
    func testGoldenComplexDocumentStructure() async throws {
        // Test a complex document with all major node types
        let document = DocumentIRBuilder.document(id: "complex-doc", title: "Complex Document")
            .addChild(DocumentIRBuilder.section(id: "header", level: 1, title: "Header").build())
            .addChild(
                DocumentIRBuilder.paragraph(id: "para-with-image")
                .addChild(DocumentIRBuilder.text("Here's an image: "))
                .addChild(DocumentIRBuilder.image(id: "img-1", source: "test.png", altText: "Test Image"))
                .addChild(DocumentIRBuilder.text(" inline."))
                .build()
            )
            .addChild(
                DocumentIRBuilder.blockQuote(id: "quote-1", citation: "Source")
                .addChild(DocumentIRBuilder.text("This is a quote."))
                .build()
            )
            .addChild(
                DocumentIRBuilder.table(id: "table-1", columns: 2)
                .addChild(
                    DocumentIRBuilder.tableRow(id: "row-1", isHeaderRow: true)
                    .addChild(
                        DocumentIRBuilder.tableCell(id: "cell-1")
                        .addChild(DocumentIRBuilder.text("Header 1"))
                        .build()
                    )
                    .addChild(
                        DocumentIRBuilder.tableCell(id: "cell-2")
                        .addChild(DocumentIRBuilder.text("Header 2"))
                        .build()
                    )
                    .build()
                )
                .addChild(
                    DocumentIRBuilder.tableRow(id: "row-2")
                    .addChild(
                        DocumentIRBuilder.tableCell(id: "cell-3")
                        .addChild(DocumentIRBuilder.text("Data 1"))
                        .build()
                    )
                    .addChild(
                        DocumentIRBuilder.tableCell(id: "cell-4")
                        .addChild(DocumentIRBuilder.text("Data 2"))
                        .build()
                    )
                    .build()
                )
                .build()
            )
            .build()
        
        let jsonString = try DocumentIRSerialization.encodeToJSONString(document)
        let extractedText = DocumentIRSerialization.extractText(document)
        let images = DocumentIRSerialization.extractImages(document)
        let links = DocumentIRSerialization.extractLinks(document)
        
        // Golden checks
        XCTAssertTrue(jsonString.contains("Complex Document"))
        XCTAssertTrue(extractedText.contains("This is a quote."))
        XCTAssertEqual(images.count, 1)
        XCTAssertEqual(images[0].source, "test.png")
        XCTAssertEqual(links.count, 0) // No links in this document
        
        // TODO: Add GoldenKit assertions for output consistency
    }
}