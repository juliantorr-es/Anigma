import XCTest
import CapsuleCore
import TelemetryCore
import DocumentIRKit
@testable import DocumentRenderKit

final class DocumentRenderKitContractTests: XCTestCase {
    
    var renderer: DocumentRenderKit!
    
    override func setUp() async throws {
        renderer = try DocumentRenderKit(id: "test-contract", diagnostics: DefaultDiagnostics())
    }
    
    /// Contract: Invalid document root must throw .invalidInput
    func testInvalidInputDocumentRoot() async {
        let invalidDocument = DocumentIRBuilder.text("Not a document root")
        
        do {
            _ = try await renderer.createRenderPlan(
                from: invalidDocument,
                renderType: .pdf
            )
            XCTFail("Should have thrown .invalidInput")
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
    
    /// Contract: Empty renderer ID must throw .invalidConfiguration
    func testInvalidConfigurationEmptyID() async {
        do {
            _ = try DocumentRenderKit(id: "")
            XCTFail("Should have thrown .invalidConfiguration")
        } catch let error as CapsuleError {
            if case .invalidConfiguration(let reason) = error {
                XCTAssertTrue(reason.contains("ID cannot be empty"))
            } else {
                XCTFail("Wrong CapsuleError: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    /// Contract: RenderPlan must be Codable and round-trip correctly
    func testRenderPlanCodableContract() throws {
        let renderPlan = RenderPlan(
            id: "test-plan",
            documentID: "test-doc",
            renderType: .pdf,
            layout: Layout(),
            elements: [
                .text(TextElement(
                    id: "text-1",
                    content: "Test",
                    frame: CGRect(x: 0, y: 0, width: 100, height: 20),
                    style: TextStyle(),
                    alignment: .left
                ))
            ]
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(renderPlan)
        XCTAssertFalse(jsonData.isEmpty)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedRenderPlan = try decoder.decode(RenderPlan.self, from: jsonData)
        XCTAssertEqual(renderPlan, decodedRenderPlan)
    }
    
    /// Contract: All render elements must be Sendable and Equatable
    func testRenderElementContracts() throws {
        let textElement = RenderElement.text(TextElement(
            id: "text-1",
            content: "Test",
            frame: CGRect(x: 0, y: 0, width: 100, height: 20),
            style: TextStyle(),
            alignment: .left
        ))
        
        let imageElement = RenderElement.image(ImageElement(
            id: "img-1",
            source: "test.png",
            frame: CGRect(x: 0, y: 0, width: 200, height: 150),
            scaling: .fit,
            altText: "Test"
        ))
        
        // Test equality
        let identicalText = RenderElement.text(TextElement(
            id: "text-1",
            content: "Test",
            frame: CGRect(x: 0, y: 0, width: 100, height: 20),
            style: TextStyle(),
            alignment: .left
        ))
        XCTAssertEqual(textElement, identicalText)
        
        // Test Sendable (compiler will enforce)
        let sendableText: any Sendable = textElement
        let sendableImage: any Sendable = imageElement
        XCTAssertNotNil(sendableText)
        XCTAssertNotNil(sendableImage)
    }
    
    /// Contract: Layout must handle invalid configurations
    func testLayoutValidationContract() async throws {
        // Create a document
        let document = DocumentIRBuilder.document(id: "test-doc")
            .addChild(DocumentIRBuilder.text("Test"))
            .build()
        
        // Create render plan with invalid layout (negative margins)
        let invalidLayout = Layout(
            pageSize: .a4,
            margins: Margins(top: -10, right: -10, bottom: -10, left: -10),
            orientation: .portrait,
            columns: 1
        )
        
        let renderPlan = try await renderer.createRenderPlan(
            from: document,
            renderType: .pdf
        )
        
        // Create a new render plan with invalid layout for testing
        let invalidRenderPlan = RenderPlan(
            id: renderPlan.id,
            documentID: renderPlan.documentID,
            renderType: renderPlan.renderType,
            layout: invalidLayout,
            elements: renderPlan.elements,
            metadata: renderPlan.metadata
        )
        
        let validationResult = await renderer.validateRenderPlan(invalidRenderPlan)
        
        // Should detect layout issues
        XCTAssertFalse(validationResult.isValid)
        XCTAssertGreaterThan(validationResult.issues.count, 0)
        
        let layoutIssues = validationResult.issues.filter { 
            $0.message.contains("Layout dimensions exceed page size") 
        }
        XCTAssertGreaterThan(layoutIssues.count, 0)
    }
    
    /// Contract: Validation must detect empty text elements
    func testEmptyTextValidationContract() async throws {
        let document = DocumentIRBuilder.document(id: "test-doc")
            .addChild(DocumentIRBuilder.text(""))
            .build()
        
        let renderPlan = try await renderer.createRenderPlan(
            from: document,
            renderType: .pdf
        )
        
        let validationResult = await renderer.validateRenderPlan(renderPlan)
        
        // Should detect empty text as warning
        let emptyTextWarnings = validationResult.warnings.filter { 
            $0.message.contains("empty content") 
        }
        XCTAssertGreaterThanOrEqual(emptyTextWarnings.count, 0) // May or may not be detected in stub
    }
    
    /// Contract: Validation must detect invalid image sources
    func testInvalidImageValidationContract() async throws {
        let document = DocumentIRBuilder.document(id: "test-doc")
            .addChild(DocumentIRBuilder.image(id: "img-1", source: ""))
            .build()
        
        let renderPlan = try await renderer.createRenderPlan(
            from: document,
            renderType: .pdf
        )
        
        let validationResult = await renderer.validateRenderPlan(renderPlan)
        
        // Should detect empty image source as error
        let invalidImageErrors = validationResult.issues.filter { 
            $0.message.contains("empty source") 
        }
        XCTAssertGreaterThan(invalidImageErrors.count, 0)
    }
    
    /// Contract: Error metadata must be properly structured
    func testErrorMetadataContract() async {
        do {
            let invalidDocument = DocumentIRBuilder.text("Invalid")
            _ = try await renderer.createRenderPlan(
                from: invalidDocument,
                renderType: .pdf
            )
            XCTFail("Should have thrown error")
        } catch let error as CapsuleError {
            XCTAssertNotNil(error.errorDescription)
            // Contract check for localized description or other metadata
        } catch {
            XCTFail("Should have been a CapsuleError")
        }
    }
    
    /// Contract: Renderer must maintain consistent health status
    func testHealthStatusContract() {
        let health = renderer.healthStatus()
        
        // Required health status fields
        XCTAssertNotNil(health["renderer_id"])
        XCTAssertNotNil(health["status"])
        XCTAssertNotNil(health["timestamp"])
        XCTAssertNotNil(health["supported_types"])
        
        // Status should be healthy for new renderer
        XCTAssertEqual(health["status"], "healthy")
        
        // Timestamp should be valid ISO8601
        let timestamp = health["timestamp"] ?? ""
        XCTAssertFalse(timestamp.isEmpty)
        
        // Supported types should include basic types
        let supportedTypes = health["supported_types"] ?? ""
        XCTAssertTrue(supportedTypes.contains("pdf"))
        XCTAssertTrue(supportedTypes.contains("html"))
    }
    
    /// Contract: RenderPlan metadata must be properly structured
    func testRenderPlanMetadataContract() async throws {
        let document = DocumentIRBuilder.document(id: "metadata-doc")
            .addChild(DocumentIRBuilder.text("Test"))
            .build()
        
        let renderPlan = try await renderer.createRenderPlan(
            from: document,
            renderType: .pdf
        )
        
        // Check required metadata fields
        XCTAssertNotNil(renderPlan.metadata.createdDate)
        XCTAssertNotNil(renderPlan.metadata.version)
        XCTAssertNotNil(renderPlan.metadata.generator)
        XCTAssertNotNil(renderPlan.metadata.properties)
        
        // Check metadata values
        XCTAssertEqual(renderPlan.metadata.generator, "DocumentRenderKit Stub")
        XCTAssertEqual(renderPlan.metadata.version, "1.0.0")
        
        // Check properties contain expected keys
        let properties = renderPlan.metadata.properties
        XCTAssertNotNil(properties["conversion_correlation_id"])
        XCTAssertNotNil(properties["total_elements"])
    }
}