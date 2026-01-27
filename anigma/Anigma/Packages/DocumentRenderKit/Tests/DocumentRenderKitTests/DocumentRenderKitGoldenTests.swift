import XCTest
import CapsuleCore
import TelemetryCore
import DocumentIRKit
@testable import DocumentRenderKit

final class DocumentRenderKitGoldenTests: XCTestCase {
    
    var renderer: DocumentRenderKit!
    
    override func setUp() async throws {
        renderer = try DocumentRenderKit(id: "test-golden", diagnostics: DefaultDiagnostics())
    }
    
    func testGoldenSimpleDocumentRenderPlan() async throws {
        let document = DocumentIRBuilder.document(
            id: "golden-simple",
            title: "Golden Simple Document"
        )
        .addChild(
            DocumentIRBuilder.paragraph(id: "para-1")
            .addChild(DocumentIRBuilder.text("This is a simple test document."))
            .build()
        )
        .build()
        
        let renderPlan = try await renderer.createRenderPlan(
            from: document,
            renderType: .pdf
        )
        
        // TODO: Implement actual golden comparison
        // Example using GoldenKit:
        /*
        let renderPlanJSON = try String(data: JSONEncoder().encode(renderPlan), encoding: .utf8)
        try await GoldenKit.assertMatches(
            renderPlanJSON,
            named: "simple_document_render_plan",
            in: Bundle.module
        )
        */
        
        // Fallback for now: Check basic structure
        XCTAssertEqual(renderPlan.documentID, "golden-simple")
        XCTAssertEqual(renderPlan.renderType, .pdf)
        XCTAssertEqual(renderPlan.elements.count, 1)
        
        if case .text(let textElement) = renderPlan.elements.first {
            XCTAssertEqual(textElement.content, "This is a simple test document.")
            XCTAssertEqual(textElement.style.fontFamily, "Helvetica")
            XCTAssertEqual(textElement.style.fontSize, 12.0)
        } else {
            XCTFail("Expected text element")
        }
    }
    
    func testGoldenComplexDocumentRenderPlan() async throws {
        let document = DocumentIRBuilder.document(
            id: "golden-complex",
            title: "Golden Complex Document"
        )
        .addChild(
            DocumentIRBuilder.section(id: "section-1", level: 1, title: "Introduction")
            .addChild(
                DocumentIRBuilder.paragraph(id: "para-1")
                .addChild(DocumentIRBuilder.text("This document demonstrates "))
                .addChild(DocumentIRBuilder.emphasis(id: "em-1", children: [DocumentIRBuilder.text("emphasis")]))
                .addChild(DocumentIRBuilder.text(", "))
                .addChild(DocumentIRBuilder.strong(id: "strong-1", children: [DocumentIRBuilder.text("strong")]))
                .addChild(DocumentIRBuilder.text(", and "))
                .addChild(DocumentIRBuilder.code(id: "code-1", code: "code"))
                .addChild(DocumentIRBuilder.text(" formatting."))
                .build()
            )
            .build()
        )
        .addChild(
            DocumentIRBuilder.section(id: "section-2", level: 2, title: "Lists and Links")
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
                    .addChild(DocumentIRBuilder.link(id: "link-1", url: "https://example.com", title: "Example Link"))
                    .build()
                )
                .build()
            )
            .build()
        )
        .addChild(
            DocumentIRBuilder.codeBlock(id: "code-block-1", language: "swift", code: """
            func greet(name: String) -> String {
                return "Hello, \\(name)!"
            }
            """)
        )
        .build()
        
        let renderPlan = try await renderer.createRenderPlan(
            from: document,
            renderType: .html
        )
        
        // TODO: Implement actual golden comparison
        // Example using GoldenKit:
        /*
        let renderPlanJSON = try String(data: JSONEncoder().encode(renderPlan), encoding: .utf8)
        try await GoldenKit.assertMatches(
            renderPlanJSON,
            named: "complex_document_render_plan",
            in: Bundle.module
        )
        */
        
        // Fallback for now: Check structure and content
        XCTAssertEqual(renderPlan.documentID, "golden-complex")
        XCTAssertEqual(renderPlan.renderType, .html)
        XCTAssertGreaterThanOrEqual(renderPlan.elements.count, 5) // At least section, paragraph, list, code block
        
        // Check for various element types
        let textElements = renderPlan.elements.compactMap { element in
            if case .text(let textElement) = element {
                return textElement.content
            }
            return nil
        }
        
        let containerElements = renderPlan.elements.compactMap { element in
            if case .container(let containerElement) = element {
                return containerElement
            }
            return nil
        }
        
        // Should contain section titles
        XCTAssertTrue(textElements.contains(where: { $0.contains("Introduction") }))
        XCTAssertTrue(textElements.contains(where: { $0.contains("Lists and Links") }))
        
        // Should contain emphasis/strong styling
        XCTAssertTrue(textElements.contains(where: { $0.contains("emphasis") }))
        XCTAssertTrue(textElements.contains(where: { $0.contains("strong") }))
        
        // Should contain list bullets
        XCTAssertTrue(textElements.contains("•"))
        XCTAssertTrue(textElements.contains("First item"))
        XCTAssertTrue(textElements.contains("Second item"))
        
        // Should contain code block container
        XCTAssertGreaterThan(containerElements.count, 0)
        let codeContainers = containerElements.filter { container in
            container.children.contains { element in
                if case .text(let textElement) = element {
                    return textElement.content.contains("func greet")
                }
                return false
            }
        }
        XCTAssertGreaterThan(codeContainers.count, 0)
    }
    
    func testGoldenImageAndTableRenderPlan() async throws {
        let document = DocumentIRBuilder.document(id: "golden-media", title: "Media Test")
            .addChild(
                DocumentIRBuilder.paragraph(id: "para-image")
                .addChild(DocumentIRBuilder.text("Here's an image: "))
                .addChild(DocumentIRBuilder.image(
                    id: "img-1",
                    source: "golden-test.png",
                    altText: "Golden Test Image",
                    width: 400,
                    height: 300
                ))
                .addChild(DocumentIRBuilder.text(" inline with text."))
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
        
        let renderPlan = try await renderer.createRenderPlan(
            from: document,
            renderType: .pdf
        )
        
        // TODO: Implement actual golden comparison
        // Example using GoldenKit:
        /*
        let renderPlanJSON = try String(data: JSONEncoder().encode(renderPlan), encoding: .utf8)
        try await GoldenKit.assertMatches(
            renderPlanJSON,
            named: "image_table_render_plan",
            in: Bundle.module
        )
        */
        
        // Fallback for now: Check structure and content
        XCTAssertEqual(renderPlan.documentID, "golden-media")
        XCTAssertEqual(renderPlan.renderType, .pdf)
        
        // Check for image element
        let imageElements = renderPlan.elements.compactMap { element in
            if case .image(let imageElement) = element {
                return imageElement
            }
            return nil
        }
        XCTAssertEqual(imageElements.count, 1)
        XCTAssertEqual(imageElements.first?.source, "golden-test.png")
        XCTAssertEqual(imageElements.first?.altText, "Golden Test Image")
        XCTAssertEqual(imageElements.first?.frame.width, 400)
        XCTAssertEqual(imageElements.first?.frame.height, 300)
        
        // Check for table elements (should be stubbed in Tier 1)
        let containerElements = renderPlan.elements.compactMap { element in
            if case .container(let containerElement) = element {
                return containerElement
            }
            return nil
        }
        // Tables may not be fully implemented in Tier 1 stub
        
        // Check for text content
        let textElements = renderPlan.elements.compactMap { element in
            if case .text(let textElement) = element {
                return textElement.content
            }
            return nil
        }
        XCTAssertTrue(textElements.contains(where: { $0.contains("Header 1") }))
        XCTAssertTrue(textElements.contains(where: { $0.contains("Data 1") }))
    }
    
    func testGoldenRenderPlanStability() async throws {
        // Test that the same input produces the same output
        let document = DocumentIRBuilder.document(
            id: "stability-test",
            title: "Stability Test"
        )
        .addChild(
            DocumentIRBuilder.paragraph(id: "stable-para")
            .addChild(DocumentIRBuilder.text("Stable content for testing output consistency."))
            .build()
        )
        .build()
        
        // Generate render plan twice
        let renderPlan1 = try await renderer.createRenderPlan(
            from: document,
            renderType: .markdown
        )
        
        let renderPlan2 = try await renderer.createRenderPlan(
            from: document,
            renderType: .markdown
        )
        
        // Render plans should be equal (same content, different IDs is acceptable)
        XCTAssertEqual(renderPlan1.documentID, renderPlan2.documentID)
        XCTAssertEqual(renderPlan1.renderType, renderPlan2.renderType)
        XCTAssertEqual(renderPlan1.layout, renderPlan2.layout)
        XCTAssertEqual(renderPlan1.elements.count, renderPlan2.elements.count)
        
        // Elements should have same structure
        for (element1, element2) in zip(renderPlan1.elements, renderPlan2.elements) {
            switch (element1, element2) {
            case (.text(let text1), .text(let text2)):
                XCTAssertEqual(text1.content, text2.content)
                XCTAssertEqual(text1.style, text2.style)
                XCTAssertEqual(text1.alignment, text2.alignment)
            case (.image(let img1), .image(let img2)):
                XCTAssertEqual(img1.source, img2.source)
                XCTAssertEqual(img1.altText, img2.altText)
            default:
                XCTAssertEqual(element1, element2)
            }
        }
        
        // TODO: Add GoldenKit assertion for JSON stability
        /*
        let json1 = try JSONEncoder().encode(renderPlan1)
        let json2 = try JSONEncoder().encode(renderPlan2)
        try await GoldenKit.assertMatches(
            String(data: json1, encoding: .utf8) ?? "",
            named: "stable_render_plan",
            in: Bundle.module
        )
        */
    }
}