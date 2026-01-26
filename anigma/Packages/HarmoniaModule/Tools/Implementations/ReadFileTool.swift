//
//  ReadFileTool.swift
//  HarmoniaModule
//
//  Governed read_file tool that delegates to the enhanced reader with caching and analytics.
//

import AnigmaPrimitives
@preconcurrency import Foundation

public struct ReadFileTool: ToolHandlerProtocol, Sendable {
    private let repoRoot: String

    public init(repoRoot: String = FileManager.default.currentDirectoryPath) {
        self.repoRoot = repoRoot
    }

    public func handle(request: ToolRequest) async throws -> ToolResponse {
        let enhanced = EnhancedReadFileTool(repoRoot: repoRoot)
        return try await enhanced.handle(request: request)
    }

    public func execute(_ request: ToolCallRequest, session: SessionContext) async
        -> ToolCallResponse {
        let enhanced = EnhancedReadFileTool(repoRoot: repoRoot)
        let toolRequest = ToolRequest(
            arguments: ["path": request.filePath ?? "", "cache": "true"],
            sessionId: request.sessionId
        )
        do {
            let response = try await enhanced.handle(request: toolRequest)
            return ToolCallResponse(from: response, toolName: "read_file")
        } catch {
            return ToolCallResponse(status: .failed, toolName: "read_file", diagnosis: error.localizedDescription)
        }
    }
}
