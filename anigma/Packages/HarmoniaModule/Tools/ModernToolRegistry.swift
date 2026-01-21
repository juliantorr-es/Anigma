//
//  ModernToolRegistry.swift
//  HarmoniaModule
//
//  Registry for modern, type-safe tools.
//

import AnigmaPrimitives
import Foundation

/// Registry for modern tools that provides type-erased access for the router.
public actor ModernToolRegistry {
    public static let shared = ModernToolRegistry()

    private var tools: [String: AnyTool] = [:]

    public init() {}

    /// Registers a type-safe tool.
    public func register<T: Tool>(_ tool: T) {
        let anyTool = AnyTool(tool)
        tools[T.id] = anyTool
    }

    /// Gets a type-erased tool by ID.
    public func tool(for id: String) -> AnyTool? {
        tools[id]
    }

    /// Lists all registered tool IDs.
    public func allToolIds() -> [String] {
        Array(tools.keys)
    }
}

// MARK: - Default Tool Context

/// Concrete implementation of ToolContext for use in Harmonia.
public struct HarmoniaToolContext: ToolContext {
    public let sessionId: String
    public let agentName: String
    private let metadataHandler: @Sendable ([String: Sendable]) async -> Void
    private let permissionHandler: @Sendable (String, String) async throws -> Void

    public init(
        sessionId: String,
        agentName: String,
        metadataHandler: @escaping @Sendable ([String: Sendable]) async -> Void,
        permissionHandler: @escaping @Sendable (String, String) async throws -> Void
    ) {
        self.sessionId = sessionId
        self.agentName = agentName
        self.metadataHandler = metadataHandler
        self.permissionHandler = permissionHandler
    }

    public func updateMetadata(_ metadata: [String: Sendable]) async {
        // Log to console for now, but in a real app this would go to an event stream
        print("[\(sessionId)] [METADATA] \(metadata)")
        await metadataHandler(metadata)
    }

    public func ask(permission: String, pattern: String) async throws {
        // This will suspend the tool until the handler resumes it
        print("[\(sessionId)] [PERMISSION_REQUIRED] \(permission) for \(pattern)")
        try await permissionHandler(permission, pattern)
    }
}
