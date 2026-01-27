// MarkdownCapsuleTests.swift
// Tests for MarkdownCapsule functionality

import Foundation
import XCTest
@testable import MarkdownCapsule
import CapsuleCore
import TelemetryCore

final class MarkdownCapsuleTests: XCTestCase {
    
    var capsule: MarkdownCapsule!
    var diagnostics: MockDiagnostics!
    
    override func setUp() async throws {
        try await super.setUp()
        diagnostics = MockDiagnostics()
        capsule = MarkdownCapsule(diagnostics: diagnostics)
    }
    
    override func tearDown() async throws {
        capsule = nil
        diagnostics = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Parsing Tests
    
    func testParseSimpleParagraph() async throws {
        let markdown = "This is a simple paragraph."
        let document = try await capsule.parse(markdown)
        
        XCTAssertEqual(document.metadata.inputLength, markdown.count)
        XCTAssertEqual(document.root.type, .document)
        XCTAssertEqual(document.root.children.count, 1)
        XCTAssertEqual(document.root.children.first?.type, .paragraph)
        XCTAssertGreaterThan(document.statistics.paragraphCount, 0)
    }
    
    func testParseMultipleParagraphs() async throws {
        let markdown = """
        First paragraph.
        
        Second paragraph.
        
        Third paragraph.
        """
        let document = try await capsule.parse(markdown)
        
        XCTAssertEqual(document.statistics.paragraphCount, 3)
        XCTAssertEqual(document.root.children.count, 3)
        
        for child in document.root.children {
            XCTAssertEqual(child.type, .paragraph)
        }
    }
    
    func testParseHeaders() async throws {
        let markdown = """
        # Header 1
        ## Header 2
        ### Header 3
        """
        let document = try await capsule.parse(markdown)
        
        XCTAssertGreaterThan(document.statistics.headerCount, 0)
    }
    
    func testParseLinks() async throws {
        let markdown = """
        This is a [link](https://example.com) and another [link](https://test.com).
        """
        let document = try await capsule.parse(markdown)
        let links = await capsule.extractLinks(from: document)
        
        XCTAssertEqual(links.count, 2)
        XCTAssertTrue(links.contains("https://example.com"))
        XCTAssertTrue(links.contains("https://test.com"))
    }
    
    func testParseImages() async throws {
        let markdown = """
        ![Alt text](image.png)
        ![Another](https://example.com/image.jpg)
        """
        let document = try await capsule.parse(markdown)
        
        XCTAssertGreaterThan(document.statistics.imageCount, 0)
    }
    
    func testParseCodeBlocks() async throws {
        let markdown = """
        ```swift
        func hello() {
            print("Hello, World!")
        }
        ```
        """
        let document = try await capsule.parse(markdown)
        
        XCTAssertGreaterThan(document.statistics.codeBlockCount, 0)
    }
    
    // MARK: - Rendering Tests
    
    func testRenderToHTML() async throws {
        let markdown = "This is **bold** and *italic* text."
        let document = try await capsule.parse(markdown)
        let html = try await capsule.render(document: document, to: .html)
        
        XCTAssertTrue(html.contains("<p>"))
        XCTAssertTrue(html.contains("</p>"))
        XCTAssertTrue(html.contains("<strong>"))
        XCTAssertTrue(html.contains("</strong>"))
        XCTAssertTrue(html.contains("<em>"))
        XCTAssertTrue(html.contains("</em>"))
    }
    
    func testRenderToPlainText() async throws {
        let markdown = """
        # Title
        
        This is a paragraph with **bold** and *italic* text.
        """
        let document = try await capsule.parse(markdown)
        let plainText = try await capsule.render(document: document, to: .plainText)
        
        XCTAssertFalse(plainText.contains("<"))
        XCTAssertFalse(plainText.contains(">"))
        XCTAssertTrue(plainText.contains("Title"))
        XCTAssertTrue(plainText.contains("This is a paragraph"))
    }
    
    func testParseAndRender() async throws {
        let markdown = "## Test\n\nThis is a test."
        let html = try await capsule.parseAndRender(markdown, to: .html)
        
        XCTAssertTrue(html.contains("<h2>"))
        XCTAssertTrue(html.contains("</h2>"))
        XCTAssertTrue(html.contains("<p>"))
        XCTAssertTrue(html.contains("</p>"))
    }
    
    // MARK: - Validation Tests
    
    func testValidMarkdown() async throws {
        let markdown = "# Valid Markdown\n\nThis is valid."
        try await capsule.validate(markdown)
        
        // Should not throw
    }
    
    func testEmptyMarkdownValidation() async {
        let markdown = ""
        
        do {
            try await capsule.validate(markdown)
            XCTFail("Expected validation to fail for empty markdown")
        } catch {
            XCTAssertTrue(error is CapsuleError)
        }
    }
    
    // MARK: - Visitor Pattern Tests
    
    func testMarkdownVisitor() async throws {
        let markdown = """
        # Title
        
        This is a paragraph with a [link](https://example.com).
        
        ```swift
        let code = "test"
        ```
        """
        let document = try await capsule.parse(markdown)
        
        class CountingVisitor: MarkdownVisitor {
            var visitCount = 0
            var typesSeen: Set<MarkdownNodeType> = []
            
            func visit(node: MarkdownNode) -> MarkdownVisitResult {
                visitCount += 1
                typesSeen.insert(node.type)
                return .continueVisit
            }
            
            func enter(node: MarkdownNode) -> MarkdownVisitResult { .continueVisit }
            func leave(node: MarkdownNode) -> MarkdownVisitResult { .continueVisit }
        }
        
        let visitor = CountingVisitor()
        let completed = await capsule.visit(document: document, using: visitor)
        
        XCTAssertTrue(completed)
        XCTAssertGreaterThan(visitor.visitCount, 0)
        XCTAssertTrue(visitor.typesSeen.contains(.document))
        XCTAssertTrue(visitor.typesSeen.contains(.header))
        XCTAssertTrue(visitor.typesSeen.contains(.paragraph))
        XCTAssertTrue(visitor.typesSeen.contains(.link))
        XCTAssertTrue(visitor.typesSeen.contains(.codeBlock))
    }
    
    func testVisitorEarlyExit() async throws {
        let markdown = "# Title\nParagraph"
        let document = try await capsule.parse(markdown)
        
        class EarlyExitVisitor: MarkdownVisitor {
            var visitCount = 0
            
            func visit(node: MarkdownNode) -> MarkdownVisitResult {
                visitCount += 1
                if visitCount >= 2 {
                    return .stopVisit
                }
                return .continueVisit
            }
            
            func enter(node: MarkdownNode) -> MarkdownVisitResult { .continueVisit }
            func leave(node: MarkdownNode) -> MarkdownVisitResult { .continueVisit }
        }
        
        let visitor = EarlyExitVisitor()
        let completed = await capsule.visit(document: document, using: visitor)
        
        XCTAssertFalse(completed)
        XCTAssertEqual(visitor.visitCount, 2)
    }
    
    // MARK: - Error Handling Tests
    
    func testParseLargeInput() async throws {
        let largeText = String(repeating: "This is a long paragraph. ", count: 10000)
        let document = try await capsule.parse(largeText)
        
        XCTAssertGreaterThan(document.metadata.inputLength, 0)
        XCTAssertEqual(document.root.children.count, 1)
    }
    
    func testCapsuleProperties() {
        let version = capsule.version
        XCTAssertFalse(version.isEmpty)
    }
    
    func testDiagnosticsIntegration() async throws {
        let markdown = "# Test\n\nThis is a test."
        _ = try await capsule.parse(markdown)
        
        let spans = diagnostics.spans
        XCTAssertGreaterThan(spans.count, 0)
        
        let parseSpans = spans.filter { $0.name == "markdown.parse" }
        XCTAssertEqual(parseSpans.count, 1)
        
        let span = parseSpans.first!
        XCTAssertEqual(span.name, "markdown.parse")
        XCTAssertEqual(span.category, "MarkdownCapsule")
        XCTAssertEqual(span.status, .ok)
    }
    
    // MARK: - Edge Cases
    
    func testMarkdownWithSpecialCharacters() async throws {
        let markdown = """
        Special characters: !@#$%^&*()_+-={}[]|\\:";'<>?,./
        
        Unicode: 🚀 🎉 ✨
        
        Emojis in text: Hello world! 👋
        """
        let document = try await capsule.parse(markdown)
        
        XCTAssertGreaterThan(document.metadata.inputLength, 0)
        XCTAssertGreaterThan(document.statistics.paragraphCount, 0)
    }
    
    func testEmptyDocument() async throws {
        let markdown = ""
        let document = try await capsule.parse(markdown)
        
        XCTAssertEqual(document.metadata.inputLength, 0)
        XCTAssertEqual(document.root.children.count, 0)
    }
    
    func testWhitespaceOnly() async throws {
        let markdown = """
        
        
        \t\t  
        
        """
        let document = try await capsule.parse(markdown)
        
        XCTAssertGreaterThan(document.metadata.inputLength, 0)
    }
}

// MARK: - Mock Diagnostics

class MockDiagnostics: CapsuleDiagnostics {
    var spans: [MockDiagnosticSpan] = []
    
    func beginSpan(
        name: String,
        category: String,
        correlationID: String? = nil,
        tags: [String: String] = [:]
    ) -> DiagnosticSpan {
        let span = MockDiagnosticSpan(name: name, category: category, tags: tags)
        spans.append(span)
        return span
    }
    
    func event(
        level: DiagnosticLevel,
        category: String,
        message: String,
        correlationID: String? = nil,
        metadata: [String: String] = [:]
    ) {
        // Mock implementation
    }
    
    func getEvents(since: Date) -> [DiagnosticEvent] {
        return []
    }
    
    func getAllEvents() -> [DiagnosticEvent] {
        return []
    }
    
    func clearEvents() {
        // Mock implementation
    }
}

class MockDiagnosticSpan: DiagnosticSpan {
    let spanID: String
    let name: String
    let category: String
    let correlationID: String?
    let startTime: Date
    var endTime: Date?
    var status: SpanStatus?
    var tags: [String: String]
    
    init(name: String, category: String, tags: [String: String] = [:]) {
        self.spanID = UUID().uuidString
        self.name = name
        self.category = category
        self.correlationID = nil
        self.startTime = Date()
        self.tags = tags
    }
    
    func end(status: SpanStatus) {
        self.endTime = Date()
        self.status = status
    }
    
    func addTag(key: String, value: String) {
        tags[key] = value
    }
    
    func recordEvent(level: DiagnosticLevel, message: String) {
        // Mock implementation
    }
}

// MARK: - Golden Tests

final class MarkdownCapsuleGoldenTests: XCTestCase {
    
    func testGoldenParseHTML() async throws {
        let markdown = """
        # Sample Document
        
        This is a **bold** paragraph with *italic* text and a [link](https://example.com).
        
        ## Code Example
        
        ```swift
        func greet(name: String) {
            print("Hello, \\(name)!")
        }
        ```
        
        - Item 1
        - Item 2
        - Item 3
        """
        
        let capsule = MarkdownCapsule()
        let html = try await capsule.parseAndRender(markdown, to: .html)
        
        // Expected HTML structure
        XCTAssertTrue(html.contains("<h1>Sample Document</h1>"))
        XCTAssertTrue(html.contains("<p>This is a <strong>bold</strong> paragraph with <em>italic</em> text and a <a href=\"https://example.com\">link</a>.</p>"))
        XCTAssertTrue(html.contains("<h2>Code Example</h2>"))
        XCTAssertTrue(html.contains("<pre><code>"))
        XCTAssertTrue(html.contains("func greet(name: String) {"))
        XCTAssertTrue(html.contains("print(\"Hello, \\(name)!\")"))
        XCTAssertTrue(html.contains("</code></pre>"))
    }
    
    func testGoldenParsePlainText() async throws {
        let markdown = """
        # Title
        
        This document has:
        - **Bold text**
        - *Italic text*
        - `Code`
        - [Links](https://example.com)
        """
        
        let capsule = MarkdownCapsule()
        let plainText = try await capsule.parseAndRender(markdown, to: .plainText)
        
        // Expected plain text (no HTML tags)
        XCTAssertFalse(plainText.contains("<"))
        XCTAssertFalse(plainText.contains(">"))
        XCTAssertTrue(plainText.contains("Title"))
        XCTAssertTrue(plainText.contains("This document has:"))
        XCTAssertTrue(plainText.contains("Bold text"))
        XCTAssertTrue(plainText.contains("Italic text"))
        XCTAssertTrue(plainText.contains("Code"))
        XCTAssertTrue(plainText.contains("Links"))
    }
}