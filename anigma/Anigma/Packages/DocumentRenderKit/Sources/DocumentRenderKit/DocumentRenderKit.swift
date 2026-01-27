import Foundation
import CapsuleCore
import TelemetryCore
import DocumentIRKit

/// DocumentRenderKit: Converts DocumentIR to render plans
/// Provides stub-first implementation following Tier 1 patterns
public final class DocumentRenderKit: Sendable {
    
    /// Unique identifier for this renderer instance
    public let id: String
    
    /// Diagnostics for observability
    private let diagnostics: CapsuleDiagnostics
    
    /// Internal implementation
    private nonisolated let impl: DocumentRenderKitInternal
    
    /// Initialize DocumentRenderKit instance
    /// - Parameters:
    ///   - id: Unique identifier for this renderer (UUID recommended)
    ///   - diagnostics: Diagnostics collector for observability
    /// - Throws: `CapsuleError.invalidConfiguration` if id is empty or invalid
    public init(
        id: String = UUID().uuidString,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        guard !id.isEmpty else {
            throw CapsuleError.invalidConfiguration(reason: "Renderer ID cannot be empty")
        }
        
        self.id = id
        self.diagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        self.impl = DocumentRenderKitInternal()
        
        let span = self.diagnostics.beginSpan(
            name: "DocumentRenderKit.init",
            category: "initialization",
            correlationID: nil,
            tags: ["renderer_id": id]
        )
        span.end(status: .ok)
    }
    
    /// Convert DocumentIR to render plan for specified type
    /// - Parameters:
    ///   - document: DocumentIR to convert
    ///   - renderType: Target render type (PDF, HTML, etc.)
    ///   - layout: Layout configuration
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Render plan for the document
    /// - Throws: `CapsuleError` variants:
    ///   - `.invalidInput` if document is malformed
    ///   - `.unsupportedOperation` if render type is not supported
    ///   - `.timeout` if conversion exceeds deadline
    ///   - `.internalError` if bug detected
    public func createRenderPlan(
        from document: DocumentIRNode,
        renderType: RenderType,
        layout: Layout = Layout(),
        correlationID: String? = nil
    ) async throws -> RenderPlan {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "DocumentRenderKit.createRenderPlan",
            category: "conversion",
            correlationID: corrID,
            tags: [
                "render_type": renderType.rawValue,
                "document_type": "\(type(of: document))"
            ]
        )
        
        // Validation: Contract 1 - return CapsuleError for invalid inputs
        guard case .document = document else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "document",
                constraint: "DocumentIR document root required"
            )
        }
        
        // Emit diagnostic event (Contract 2)
        diagnostics.event(
            level: .debug,
            category: "documentrenderkit.conversion",
            message: "Starting conversion to \(renderType.rawValue)",
            correlationID: corrID,
            metadata: [
                "layout_columns": "\(layout.columns)",
                "layout_orientation": layout.orientation.rawValue
            ]
        )
        
        do {
            let result = try await impl.convert(
                document: document,
                renderType: renderType,
                layout: layout,
                diagnostics: diagnostics,
                correlationID: corrID
            )
            
            diagnostics.event(
                level: .info,
                category: "documentrenderkit.conversion",
                message: "Conversion completed successfully",
                correlationID: corrID,
                metadata: [
                    "elements_count": "\(result.elements.count)",
                    "render_plan_id": result.id
                ]
            )
            
            span.end(status: .ok)
            return result
        } catch {
            diagnostics.event(
                level: .error,
                category: "documentrenderkit.conversion",
                message: "Conversion failed: \(error)",
                correlationID: corrID,
                metadata: [:]
            )
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Get supported render types
    /// - Returns: Array of supported render types
    /// - Throws: Never (informational method)
    public func getSupportedRenderTypes() -> [RenderType] {
        return impl.getSupportedRenderTypes()
    }
    
    /// Get default layout for render type
    /// - Parameter renderType: Render type to get layout for
    /// - Returns: Default layout for the render type
    public func getDefaultLayout(for renderType: RenderType) -> Layout {
        return impl.getDefaultLayout(for: renderType)
    }
    
    /// Validate render plan
    /// - Parameters:
    ///   - renderPlan: Render plan to validate
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Validation result with any issues found
    public func validateRenderPlan(
        _ renderPlan: RenderPlan,
        correlationID: String? = nil
    ) async -> ValidationResult {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "DocumentRenderKit.validateRenderPlan",
            category: "validation",
            correlationID: corrID,
            tags: ["render_plan_id": renderPlan.id]
        )
        
        defer { span.end(status: .ok) }
        
        return impl.validate(renderPlan: renderPlan)
    }
    
    /// Get renderer health status
    /// - Returns: A dictionary with health metrics (sendable-safe)
    /// - Throws: Never (diagnostic-only method)
    public func healthStatus() -> [String: String] {
        return [
            "renderer_id": id,
            "status": "healthy",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "supported_types": getSupportedRenderTypes().map(\.rawValue).joined(separator: ",")
        ]
    }
}

/// Validation result for render plans
public struct ValidationResult: Codable, Sendable, Equatable {
    public let isValid: Bool
    public let issues: [ValidationIssue]
    public let warnings: [ValidationIssue]
    
    public init(
        isValid: Bool,
        issues: [ValidationIssue] = [],
        warnings: [ValidationIssue] = []
    ) {
        self.isValid = isValid
        self.issues = issues
        self.warnings = warnings
    }
}

/// Validation issue
public struct ValidationIssue: Codable, Sendable, Equatable {
    public let id: String
    public let severity: Severity
    public let message: String
    public let elementID: String?
    
    public init(id: String, severity: Severity, message: String, elementID: String? = nil) {
        self.id = id
        self.severity = severity
        self.message = message
        self.elementID = elementID
    }
    
    public enum Severity: String, Codable, Sendable {
        case error
        case warning
        case info
    }
}

// MARK: - Helper for Diagnostics Integration

/// Mock diagnostics implementation for testing
internal final class DefaultDiagnostics: CapsuleDiagnostics {
    public func beginSpan(
        name: String,
        category: String,
        correlationID: String? = nil,
        tags: [String: String] = [:]
    ) -> DiagnosticSpan {
        MockDiagnosticSpan()
    }
    
    public func event(
        level: DiagnosticLevel,
        category: String,
        message: String,
        correlationID: String? = nil,
        metadata: [String: String] = [:]
    ) {
        // In tests, diagnostics are collected for assertions
    }
    
    public func getEvents(since: Date) -> [DiagnosticEvent] {
        []
    }
    
    public func getAllEvents() -> [DiagnosticEvent] {
        []
    }
    
    public func clearEvents() {
        // noop
    }
}

internal final class MockDiagnosticSpan: DiagnosticSpan {
    let spanID = UUID().uuidString
    let name = "mock"
    let category = "mock"
    let correlationID = UUID().uuidString
    let startTime = Date()
    
    var endTime: Date? { nil }
    var duration: TimeInterval? { nil }
    var status: SpanStatus? { nil }
    var tags: [String: String] { [:] }
    
    func end(status: SpanStatus) { }
    func addTag(key: String, value: String) { }
    func recordEvent(level: DiagnosticLevel, message: String) { }
}

/// Context for correlation IDs
internal enum CorrelationIDContext {
    static var current: String {
        // In a real implementation, this would come from async context or thread locals
        return UUID().uuidString
    }
}