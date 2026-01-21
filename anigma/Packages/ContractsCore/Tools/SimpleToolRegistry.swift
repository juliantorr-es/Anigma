//
//  SimpleToolRegistry.swift
//  ContractsCore
//
//  Simplified tool registry surface.
//

import Foundation

// MARK: - Type-Erased Tool Handler

public protocol ToolHandlerProtocol: Sendable {
    func handle(request: ToolRequest) async throws -> ToolResponse
}

public struct AnyToolHandler: ToolHandlerProtocol {
    private let _handle: @Sendable (ToolRequest) async throws -> ToolResponse

    public init<T: ToolHandlerProtocol>(_ base: T) {
        _handle = { request in
            try await base.handle(request: request)
        }
    }

    public func handle(request: ToolRequest) async throws -> ToolResponse {
        try await _handle(request)
    }
}

// MARK: - Simple Request/Response Types

public struct ToolRequest: Sendable {
    public let name: String
    public let arguments: [String: String]
    public let sessionId: String
    public let projectId: String?

    public init(name: String, arguments: [String: String], sessionId: String, projectId: String? = nil) {
        self.name = name
        self.arguments = arguments
        self.sessionId = sessionId
        self.projectId = projectId
    }
}

public struct ToolResponse: Sendable {
    public let success: Bool
    public let output: String
    public let error: String?

    public init(success: Bool, output: String, error: String? = nil) {
        self.success = success
        self.output = output
        self.error = error
    }

    public static func success(_ output: String) -> ToolResponse {
        ToolResponse(success: true, output: output, error: nil)
    }

    public static func failure(_ error: String, output: String = "") -> ToolResponse {
        ToolResponse(success: false, output: output, error: error)
    }
}

// MARK: - Simple Tool Registry

/// Simplified tool registry that avoids complex generics.
public actor SimpleToolRegistry {
    private var tools: [String: AnyToolHandler] = [:]

    public init() {}

    /// Registers a tool handler.
    public func register(name: String, handler: AnyToolHandler) {
        tools[name] = handler
    }

    /// Gets a tool handler by name.
    public func handler(for name: String) -> AnyToolHandler? {
        tools[name]
    }

    /// Executes a tool.
    public func execute(request: ToolRequest) async throws -> ToolResponse {
        guard let handler = tools[request.name] else {
            throw SimpleToolError.toolNotFound(name: request.name)
        }

        return try await handler.handle(request: request)
    }

    /// Lists all registered tool names.
    public func allToolNames() -> [String] {
        Array(tools.keys)
    }

    /// Gets the number of registered tools.
    public var toolCount: Int {
        tools.count
    }
}

// MARK: - Errors

public enum SimpleToolError: Error, Sendable {
    case toolNotFound(name: String)
    case executionFailed(error: String)
}

// MARK: - Simple Tool Result

public enum SimpleToolResult {
    case success(String)
    case failure(String)
}

// MARK: - Adapter for Simple Tools

/// Adapter for simple tool handlers
public struct SimpleToolAdapter {
    public static func adapt(
        name: String,
        handler: @escaping @Sendable (ToolRequest) async -> SimpleToolResult
    ) -> AnyToolHandler {
        AnyToolHandler(AdaptedHandler(name: name, handler: handler))
    }

    private struct AdaptedHandler: ToolHandlerProtocol {
        let name: String
        let handler: @Sendable (ToolRequest) async -> SimpleToolResult

        func handle(request: ToolRequest) async throws -> ToolResponse {
            let result = await handler(request)

            switch result {
            case .success(let output):
                return .success(output)
            case .failure(let error):
                return .failure(error, output: "")
            }
        }
    }
}
