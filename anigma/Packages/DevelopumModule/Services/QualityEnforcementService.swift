//
//  QualityEnforcementService.swift
//  DevelopumModule
//
//  Service for enforcing code quality and best practices on generated code.
//

import Foundation
import AnigmaASTServicesCore
import AnigmaCore

public actor QualityEnforcementService {
    private let rewritePipeline: RewritePipeline
    
    public init() {
        self.rewritePipeline = RewritePipeline(rules: [AddSendableToValueTypesRule()])
        // Add more rules as they become available
    }
    
    /// Enforces best practices on a code string.
    /// - Parameters:
    ///   - code: The source code to process.
    ///   - language: The language ID (e.g., "swift").
    /// - Returns: The processed code and a list of applied changes.
    public func enforceBestPractices(code: String, language: String) async throws -> (code: String, changes: [String]) {
        guard language == "swift" else {
            // Currently only Swift is supported for deep AST rewriting
            return (code, [])
        }
        
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".swift").path
        try code.write(toFile: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        let item = RewritePipeline.PipelineItem(filePath: tempFile, astAnchor: nil)
        let result = await rewritePipeline.execute(on: [item])
        
        let processedCode = try String(contentsOfFile: tempFile, encoding: .utf8)
        let changes = result.changes.map { "\($0.ruleName) at \($0.startLine):\($0.startColumn)" }
        return (processedCode, changes)
    }
    
    /// Validates a virtual document against quality rules.
    // STUB_TRACK: developum-doc-validation – Document validation not yet implemented
    public func validateDocument(_ doc: VirtualDocumentRecord) async throws -> [Violation] {
        // Placeholder for future validation logic
        print("⚠️  STUB INVOKED: QualityEnforcementService.validateDocument()")
        print("   Document validation not yet implemented - returning empty violations list")
        return []
    }
}

public struct Violation: Sendable {
    public let message: String
    public let severity: Severity
    
    public enum Severity: Sendable {
        case warning
        case error
    }
}
