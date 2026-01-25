//
//  ReadFileTool.swift
//  HarmoniaModule
//
//  Governed read_file tool that delegates to the enhanced reader with caching and analytics.
//

import AnigmaPrimitives
@preconcurrency import Foundation

public struct ReadFileTool: Sendable {
    private let repoRoot: String

    public init(repoRoot: String = FileManager.default.currentDirectoryPath) {
        self.repoRoot = repoRoot
    }

    public func execute(_ request: ToolCallRequest, session: SessionContext) async
        -> ToolCallResponse {
        let enhanced = EnhancedReadFileTool(repoRoot: repoRoot)
        return await enhanced.execute(request, session: session)
    }
}
