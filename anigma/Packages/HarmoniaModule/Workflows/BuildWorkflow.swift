//
//  BuildWorkflow.swift
//  HarmoniaModule
//
//  Governance-integrated workflow for Swift builds.
//  Wraps SwiftBuildTool with proper evidence recording and policy enforcement.
//

import AnigmaPrimitives
@preconcurrency import Foundation

/// Swift build workflow with governance integration
public struct BuildWorkflow: Sendable {
    /// Target to build
    public let target: String

    /// Build configuration (debug or release)
    public let configuration: String

    /// Additional compiler flags (optional)
    public let additionalFlags: [String]

    public init(
        target: String,
        configuration: String = "debug",
        additionalFlags: [String] = []
    ) {
        self.target = target
        self.configuration = configuration
        self.additionalFlags = additionalFlags
    }

    /// Execute the build workflow with governance
    /// - Parameters:
    ///   - tool: The SwiftBuildTool instance to execute
    ///   - request: The tool call request
    ///   - session: The session context with governance
    /// - Returns: Enhanced build result
    /// - Throws: Execution errors
    public func execute(
        tool: SwiftBuildTool,
        request: ToolCallRequest,
        session: SessionContext
    ) async throws -> ToolCallResponse {
        // Execute the build tool
        let response = await tool.execute(request, session: session)

        // The ExecutionAuthority (which would call this) automatically records evidence
        // based on the response status. Our role is just to execute and return the result.

        return response
    }
}

// ============================================================================
// MARK: - Workflow Protocol Conformance (Future Enhancement)
// ============================================================================
// When HarmoniaModule defines a Workflow protocol, BuildWorkflow can conform:
//
// public struct BuildWorkflow: Workflow, Sendable {
//     public typealias Input = BuildRequest
//     public typealias Output = ToolCallResponse
//
//     public var id: String { "build_workflow_\(target)_\(configuration)" }
//     public var requiredCapabilities: Set<String> { ["build", "compilation"] }
//
//     public func execute(
//         input: Input,
//         context: ExecutionContext
//     ) async throws -> WorkflowReceipt {
//         // Implementation with full governance
//     }
// }
