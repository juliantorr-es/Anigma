import XCTest
import CapsuleCore
import TelemetryCore
import DocumentIRKit
@testable import DocumentRenderKit

final class DocumentRenderKitTests: XCTestCase {
    
    var renderer: DocumentRenderKit!
    var diagnostics: DefaultDiagnostics!
    
    override func setUp() async throws {
        diagnostics = DefaultDiagnostics()
        renderer = try DocumentRenderKit(id: "test-renderer", diagnostics: diagnostics)
    }
    
    func testSimpleDocumentConversion() async throws {
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
        
        let renderPlan = try await renderer.createRenderPlan(
            from: document,
            renderType: .pdf
        )
        
        XCTAssertEqual(renderPlan.documentID, "test-doc")
        XCTAssertEqual(renderPlan.renderType, .pdf)
        XCTAssertGreaterThan(renderPlan.elements.count, 0)
        
        if case .text(let textElement) = renderPlan.elements.first {
            XCTAssertEqual(textElement.content, "Hello world")
        } else {
            XCTFail("Expected text element")
        }
    }
    
    func testComplexDocumentConversion() async throws {
        let document = DocumentIRBuilder.document(id: "complex-doc", title: "Complex")
            .addChild(
                DocumentIRBuilder.section(id: "section-1", level: 1, title: "Introduction")
                .addChild(
                    DocumentIRBuilder.paragraph(id: "para-1")
                    .addChild(DocumentIRBuilder.text("This document has "))
                    .addChild(DocumentIRBuilder.emphasis(id: "em-1", children: [DocumentIRBuilder.text("emphasis")]))
                    .addChild(DocumentIRBuilder.text(" and "))
                    .addChild(DocumentIRBuilder.strong(id: "strong-1", children: [DocumentIRBuilder.text("strong")]))
                    .addChild(DocumentIRBuilder.text(" text."))
                    .build()
                )
                .build()
            )
            .addChild(
                DocumentIRBuilder.codeBlock(id: "code-1", language: "swift", code: "let x = 1")
            )
            .build()
        
        let renderPlan = try await renderer.createRenderPlan(
            from: document,
            renderType: .html
        )
        
        XCTAssertEqual(renderPlan.renderType, .html)
        XCTAssertGreaterThanOrEqual(renderPlan.elements.count, 3) // Section, paragraph, code block
        
        // Check for text elements
        let textElements = renderPlan.elements.compactMap { element in
            if case .text(let textElement) = element {
                return textElement.content
            }
            return nil
        }
        
        XCTAssertTrue(textElements.contains(where: { $0.contains("Introduction") }))
        XCTAssertTrue(textElements.contains(where: { $0.contains("emphasis") }))
        XCTAssertTrue(textElements.contains(where: { $0.contains("strong") }))
    }
    
    func testImageConversion() async throws {
        let document = DocumentIRBuilder.document(id: "image-doc")
            .addChild(
                DocumentIRBuilder.image(
                    id: "img-1",
                    source: "test.png",
                    altText: "Test Image",
                    width: 300,
                    height: 200
                )
            )
            .build()
        
        let renderPlan = try await renderer.createRenderPlan(
            from: document,
            renderType: .pdf
        )
        
        if case .image(let imageElement) = renderPlan.elements.first {
            XCTAssertEqual(imageElement.source, "test.png")
            XCTAssertEqual(imageElement.altText, "Test Image")
            XCTAssertEqual(imageElement.frame.width, 300)
            XCTAssertEqual(imageElement.frame.height, 200)
        } else {
            XCTFail("Expected image element")
        }
    }
    
    func testListConversion() async throws {
        let document = DocumentIRBuilder.document(id: "list-doc")
            .addChild(
                DocumentIRBuilder.list(id: "list-1", type: .unordered)
                .addItem(
                    DocumentIRBuilder.listItem(id: "item-1")
                    .addChild(DocumentIRBuilder.text("First item"))
                    .build()
                )
                .addItem(
                    DocumentIRBuilder.listItem(id: "item-2")
                    .addChild(DocumentIRBuilder.text("Second item"))
                    .build()
                )
                .build()
            )
            .build()
        
        let renderPlan = try await renderer.createRenderPlan(
            from: document,
            renderType: .markdown
        )
        
        // Should contain list bullet points and item text
        let textElements = renderPlan.elements.compactMap { element in
            if case .text(let textElement) = element {
                return textElement.content
            }
            return nil
        }
        
        XCTAssertTrue(textElements.contains("•"))
        XCTAssertTrue(textElements.contains("First item"))
        XCTAssertTrue(textElements.contains("Second item"))
    }
    
    func testLinkConversion() async throws {
        let document = DocumentIRBuilder.document(id: "link-doc")
            .addChild(
                DocumentIRBuilder.link(id: "link-1", url: "https://example.com", title: "Example")
            )
            .build()
        
        let renderPlan = try await renderer.createRenderPlan(
            from: document,
            renderType: .html
        )
        
        if case .text(let textElement) = renderPlan.elements.first {
            XCTAssertEqual(textElement.content, "Example")
            XCTAssertEqual(textElement.style.color, Color(red: 0.0, green: 0.0, blue: 1.0))
        } else {
            XCTFail("Expected text element for link")
        }
    }
    
    func testInvalidDocumentRoot() async {
        let invalidDocument = DocumentIRBuilder.text("Not a document root")
        
        do {
            _ = try await renderer.createRenderPlan(
                from: invalidDocument,
                renderType: .pdf
            )
            XCTFail("Should have thrown invalidInput error")
        } catch let error as CapsuleError {
            if case .invalidInput(let field, _) = error {
                XCTAssertEqual(field, "document")
            } else {
                XCTFail("Wrong CapsuleError: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testSupportedRenderTypes() {
        let supportedTypes = renderer.getSupportedRenderTypes()
        
        XCTAssertTrue(supportedTypes.contains(.pdf))
        XCTAssertTrue(supportedTypes.contains(.html))
        XCTAssertTrue(supportedTypes.contains(.markdown))
        XCTAssertTrue(supportedTypes.contains(.plainText))
        
        // Canvas and print should be stubbed for Tier 2
        XCTAssertFalse(supportedTypes.contains(.canvas))
        XCTAssertFalse(supportedTypes.contains(.print))
    }
    
    func testDefaultLayouts() {
        let pdfLayout = renderer.getDefaultLayout(for: .pdf)
        XCTAssertEqual(pdfLayout.pageSize, .a4)
        XCTAssertEqual(pdfLayout.orientation, .portrait)
        XCTAssertEqual(pdfLayout.columns, 1)
        
        let htmlLayout = renderer.getDefaultLayout(for: .html)
        XCTAssertEqual(htmlLayout.margins, Margins.narrow)
        
        let printLayout = renderer.getDefaultLayout(for: .print)
        XCTAssertEqual(printLayout.columns, 2)
    }
    
    func testRenderPlanValidation() async throws {
        let document = DocumentIRBuilder.document(id: "validation-doc")
            .addChild(DocumentIRBuilder.text("Valid content"))
            .build()
        
        let renderPlan = try await renderer.createRenderPlan(
            from: document,
            renderType: .pdf
        )
        
        let validationResult = await renderer.validateRenderPlan(renderPlan)
        
        // Basic render plan should be valid
        XCTAssertTrue(validationResult.isValid)
        XCTAssertEqual(validationResult.issues.count, 0)
    }
    
    func testHealthStatus() {
        let health = renderer.healthStatus()
        
        XCTAssertEqual(health["renderer_id"], "test-renderer")
        XCTAssertEqual(health["status"], "healthy")
        XCTAssertTrue(health["timestamp"]?.isEmpty == false)
        XCTAssertTrue(health["supported_types"]?.contains("pdf") == true)
    }
    
    func testDifferentRenderTypes() async throws {
        let document = DocumentIRBuilder.document(id: "multi-doc")
            .addChild(DocumentIRBuilder.text("Test content"))
            .build()
        
        let types: [RenderType] = [.pdf, .html, .markdown, .plainText]
        
        for renderType in types {
            let renderPlan = try await renderer.createRenderPlan(
                from: document,
                renderType: renderType
            )
            
            XCTAssertEqual(renderPlan.renderType, renderType)
            XCTAssertGreaterThan(renderPlan.elements.count, 0)
        }
    }
}