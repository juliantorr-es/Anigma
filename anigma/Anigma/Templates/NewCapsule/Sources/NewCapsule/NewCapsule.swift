/// NewCapsule.swift
/// Public API for the NewCapsule
/// Phase 0 Template: Ready to pass all governance gates
///
/// This file demonstrates:
/// - Contract 1: CapsuleError for all public failures
/// - Contract 2: CapsuleDiagnostics for observability
/// - Sendable compliance (Swift 6)
///
/// To use this template:
/// 1. Run: `./scripts/generate_capsule.sh MyNewCapsule Tier2`
/// 2. Replace TODO markers in NewCapsuleInternal.swift with your implementation
/// 3. Add tests in Tests/NewCapsuleTests.swift
/// 4. Update README.md with real documentation

import Foundation
import CapsuleCore
import TelemetryCore

/// The NewCapsule public API
/// All methods are thread-safe and return structured CapsuleError on failure
public final class NewCapsule: Sendable {
    /// Unique identifier for this capsule instance
    public let id: String
    
    /// Diagnostics for observability (correlation ID tracking, span timing)
    private let diagnostics: CapsuleDiagnostics
    
    /// Internal implementation (separated for clarity)
    private nonisolated let impl: NewCapsuleInternal
    
    /// Initialize a NewCapsule instance
    /// - Parameters:
    ///   - id: Unique identifier for this capsule (UUID recommended)
    ///   - diagnostics: Diagnostics collector for observability
    /// - Throws: `CapsuleError.invalidConfiguration` if id is empty or invalid
    public init(
        id: String = UUID().uuidString,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        // Validate configuration (Contract 1 gate)
        guard !id.isEmpty else {
            throw CapsuleError.invalidConfiguration(reason: "Capsule ID cannot be empty")
        }
        
        self.id = id
        self.diagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        self.impl = NewCapsuleInternal()
        
        // Emit initialization event
        let span = self.diagnostics.beginSpan(
            name: "NewCapsule.init",
            category: "initialization",
            correlationID: nil,
            tags: ["capsule_id": id]
        )
        span.end(status: .ok)
    }
    
    /// Perform a minimal operation on input data
    /// This is the template's example public API method.
    ///
    /// - Parameters:
    ///   - input: Input string (non-empty, max 1MB)
    ///   - correlationID: Request ID for tracing (optional)
    /// - Returns: Processed output string
    /// - Throws: `CapsuleError` variants matching Phase 0 spec:
    ///   - `.invalidInput` if input is empty or malformed
    ///   - `.resourceExhausted` if input exceeds max size
    ///   - `.timeout` if operation exceeds deadline
    ///   - `.internalError` if bug detected
    ///
    /// # Contract Tests (Phase 0)
    /// This method is covered by:
    /// 1. Contract test: Verify error cases match CapsuleError spec
    /// 2. Golden test: Verify deterministic output
    /// 3. Edge case tests: Empty, max size, malformed inputs
    public func process(
        _ input: String,
        correlationID: String? = nil
    ) async throws -> String {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "NewCapsule.process",
            category: "processing",
            correlationID: corrID,
            tags: ["input_length": "\(input.count)"]
        )
        
        // Validation: Contract 1 - return CapsuleError for invalid inputs
        guard !input.isEmpty else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "input",
                constraint: "Non-empty string required"
            )
        }
        
        let maxSize = 1024 * 1024  // 1MB
        guard input.utf8.count <= maxSize else {
            span.end(status: .error)
            throw CapsuleError.resourceExhausted(
                resource: "memory",
                limit: "\(maxSize) bytes"
            )
        }
        
        // Emit diagnostic event (Contract 2)
        diagnostics.event(
            level: .debug,
            category: "newcapsule.process",
            message: "Processing input of length \(input.count)",
            correlationID: corrID,
            metadata: ["phase": "0", "tier": "template"]
        )
        
        // Delegate to internal implementation
        do {
            let result = try impl.process(input)
            
            // Success event
            diagnostics.event(
                level: .info,
                category: "newcapsule.process",
                message: "Processing succeeded, output length: \(result.count)",
                correlationID: corrID,
                metadata: [:]
            )
            
            span.end(status: .ok)
            return result
        } catch {
            // Map implementation errors to canonical CapsuleError
            diagnostics.event(
                level: .error,
                category: "newcapsule.process",
                message: "Processing failed: \(error)",
                correlationID: corrID,
                metadata: [:]
            )
            span.end(status: .error)
            throw CapsuleError.internalError(details: "\(error)")
        }
    }
    
    /// Get capsule health status
    /// - Returns: A dictionary with health metrics (sendable-safe)
    /// - Throws: Never (diagnostic-only method)
    public func healthStatus() -> [String: String] {
        return [
            "capsule_id": id,
            "status": "healthy",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
    }
}

// MARK: - Helper for Diagnostics Integration

/// Mock diagnostics implementation for testing
/// Can be replaced with actual daemon diagnostics when integrated
internal final class MockDiagnostics: CapsuleDiagnostics {
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
