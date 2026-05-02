//
//  ModernTool.swift
//  AnigmaPrimitives
//
//  Modern, type-safe tool protocol with associated types.
//  Inspired by OpenCode architecture for agentic workflows.
//

import Foundation

// MARK: - Core Tool Protocol

/// A type-safe tool that can be executed by an agent.
/// Associated types ensure Parameters and Metadata are always handled correctly.
public protocol Tool: Sendable {
    associatedtype Parameters: Codable & Sendable
    associatedtype Metadata: Codable & Sendable

    /// Stable identifier for the tool (e.g., "read_file").
    static var id: String { get }

    /// Human-readable description of what the tool does.
    static var description: String { get }

    /// Executes the tool with the given parameters and context.
    func execute(params: Parameters, context: ToolContext) async throws -> ToolResult<Metadata>
}

// MARK: - Tool Result

/// Structured result from a tool execution.
public struct ToolResult<Metadata: Codable & Sendable>: Sendable, Codable {
    /// Brief title for the result (displayed in UI).
    public let title: String

    /// The main text output of the tool.
    public let output: String

    /// Machine-readable metadata about the execution.
    public let metadata: Metadata

    /// Optional attachments (e.g., file parts).
    public let attachments: [ToolAttachment]?

    public init(
        title: String,
        output: String,
        metadata: Metadata,
        attachments: [ToolAttachment]? = nil
    ) {
        self.title = title
        self.output = output
        self.metadata = metadata
        self.attachments = attachments
    }
}

public struct ToolAttachment: Sendable, Codable {
    public let name: String
    public let contentType: String
    public let data: Data

    public init(name: String, contentType: String, data: Data) {
        self.name = name
        self.contentType = contentType
        self.data = data
    }
}

// MARK: - Tool Context

/// Context passed to every tool execution, providing access to system services.
public protocol ToolContext: Sendable {
    var sessionId: String { get }
    var agentName: String { get }

    /// Updates the live metadata for this tool call (pushed to UI).
    func updateMetadata(_ metadata: [String: Sendable]) async

    /// Suspends execution and asks the user for permission.
    /// - Parameters:
    ///   - permission: The category or tool name requiring permission.
    ///   - pattern: A wildcard pattern (e.g., "Sources/*.swift").
    func ask(permission: String, pattern: String) async throws
}

// MARK: - Advanced Permissions

public enum PermissionAction: String, Codable, Sendable {
    case allow, deny, ask
}

public struct PermissionRule: Codable, Sendable {
    public let permission: String // e.g., "read_file" or "bash"
    public let pattern: String    // e.g., "Sources/*.swift" or "git *"
    public let action: PermissionAction

    public init(permission: String, pattern: String, action: PermissionAction) {
        self.permission = permission
        self.pattern = pattern
        self.action = action
    }
}

public enum WildcardMatcher {
    public static func match(_ input: String, with pattern: String) -> Bool {
        if pattern == "*" { return true }
        // Simple implementation for now: prefix match if it ends with *
        if pattern.hasSuffix("*") {
            let prefix = pattern.dropLast()
            return input.hasPrefix(prefix)
        }
        return input == pattern
    }
}

// MARK: - Tool Middleware

public protocol ToolMiddleware: Sendable {
    func beforeExecute(toolId: String, parameters: Data, context: ToolContext) async throws
    func afterExecute(toolId: String, result: ToolCallResponse, context: ToolContext) async throws -> ToolCallResponse
}

// MARK: - Type Erasure

/// Type-erased wrapper for any Tool implementation.
public struct AnyTool: Sendable {
    public let id: String
    public let description: String
    private let _execute: @Sendable (Data, ToolContext) async throws -> ToolCallResponse

    public init<T: Tool>(_ tool: T) {
        self.id = T.id
        self.description = T.description
        self._execute = { data, context in
            let params = try JSONDecoder().decode(T.Parameters.self, from: data)
            let result = try await tool.execute(params: params, context: context)

            let encodedMetadata = try JSONEncoder().encode(result.metadata)
            return ToolCallResponse(
                status: .success,
                result: encodedMetadata,
                toolName: T.id,
                diagnosis: result.title
            )
        }
    }

    public func execute(parametersData: Data, context: ToolContext) async throws -> ToolCallResponse {
        try await _execute(parametersData, context)
    }
}
