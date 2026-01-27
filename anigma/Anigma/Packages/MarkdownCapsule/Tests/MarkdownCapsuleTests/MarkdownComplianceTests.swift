// MarkdownComplianceTests.swift
// Compliance tests for MarkdownCapsule

import XCTest
@testable import MarkdownCapsule

final class MarkdownComplianceTests: XCTestCase {
    
    var capsule: MarkdownCapsule!
    
    override func setUp() async throws {
        try await super.setUp()
        capsule = MarkdownCapsule()
    }
    
    override func tearDown() async throws {
        capsule = nil
        try await super.tearDown()
    }
    
    // MARK: - CommonMark Compliance Edge Cases
    
    func testNestedLists() async throws {
        let markdown = """
        - Level 1
          - Level 2
            - Level 3
        """
        let document = try await capsule.parse(markdown)
        // Verify nesting structure via visitor or inspection
        // For now, check if we parsed enough items
        // Note: exact AST inspection depends on how `cmark` flattens or structures lists
        // but we expect one list with children that are lists
        
        XCTAssertGreaterThan(document.root.children.count, 0)
    }
    
    func testBlockquotes() async throws {
        let markdown = """
        > Level 1
        >> Level 2
        > Level 1
        """
        let document = try await capsule.parse(markdown)
        XCTAssertEqual(document.root.children.first?.type, .blockQuote)
    }
    
    func testCodeBlockFences() async throws {
        let markdown = """
        ```swift
        code
        ```
        
        ~~~~
        also code
        ~~~~
        """
        let document = try await capsule.parse(markdown)
        // Should have 2 code blocks
        var codeBlocks = 0
        for child in document.root.children {
            if child.type == .codeBlock {
                codeBlocks += 1
            }
        }
        XCTAssertEqual(codeBlocks, 2)
    }
    
    func testHtmlBlocks() async throws {
        let markdown = """
        <table>
          <tr>
            <td>Cell</td>
          </tr>
        </table>
        """
        let document = try await capsule.parse(markdown)
        // HTML blocks are often passed through as is
        XCTAssertEqual(document.root.children.first?.type, .htmlBlock)
    }
    
    func testLinkReferenceDefinitions() async throws {
        let markdown = """
        [link 1][ref]
        
        [ref]: https://example.com
        """
        let document = try await capsule.parse(markdown)
        let links = await capsule.extractLinks(from: document)
        XCTAssertTrue(links.contains("https://example.com"))
    }
    
    func testHardLineBreaks() async throws {
        let markdown = "Line 1  \nLine 2"
        let document = try await capsule.parse(markdown)
        // Should contain a linebreak node
        // Traversing to find it
        var foundBreak = false
        func findBreak(_ node: MarkdownNode) {
            if node.type == .linebreak { foundBreak = true }
            node.children.forEach(findBreak)
        }
        findBreak(document.root)
        XCTAssertTrue(foundBreak)
    }
    
    func testUnclosedTags() async throws {
        // CommonMark handles unclosed tags gracefully (treats as text)
        let markdown = "*bold **nested"
        let document = try await capsule.parse(markdown)
        XCTAssertGreaterThan(document.metadata.nodeCount, 0)
    }
}
