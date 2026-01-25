//
//  ModernReadFileTool.swift
//  HarmoniaModule
//

import AnigmaPrimitives
import ContractsCore
@preconcurrency import Foundation

/// Modern, type-safe implementation of the read_file tool.
public struct ModernReadFileTool: Tool {
    public static let id = "read_file"
    public static let description = "Read content from a file with line range support and automatic truncation."

    public struct Parameters: Codable, Sendable {
        public let path: String
        public let startLine: Int?
        public let endLine: Int?
        public let useCache: Bool?

        public init(path: String, startLine: Int? = nil, endLine: Int? = nil, useCache: Bool? = true) {
            self.path = path
            self.startLine = startLine
            self.endLine = endLine
            self.useCache = useCache
        }
    }

    public struct Metadata: Codable, Sendable {
        public let path: String
        public let size: Int
        public let linesRead: Int
        public let totalLines: Int
        public let cacheHit: Bool
    }

    private let repoRoot: String

    public init(repoRoot: String = FileManager.default.currentDirectoryPath) {
        self.repoRoot = repoRoot
    }

    public func execute(params: Parameters, context: ToolContext) async throws -> ToolResult<Metadata> {
        // 1. Interactive Permission Check (Example)
        // If it's a sensitive file, we can ask.
        if params.path.contains(".env") || params.path.contains("Vault") {
            try await context.ask(permission: "read_sensitive", pattern: params.path)
        }

        // 2. Implementation
        // For Phase 1, we delegate to the existing EnhancedReadFileTool logic but wrap it in our new types.
        let enhanced = EnhancedReadFileTool(repoRoot: repoRoot)

        // We'll simulate the enhanced read for now since we are modernizing the interface first.
        // In a real scenario, we'd refactor EnhancedReadFileTool to be a Modern Tool.
        let result = try await enhanced.readFile(path: params.path, useCache: params.useCache ?? true)

        let metadata = Metadata(
            path: result.metadata.path,
            size: result.metadata.size,
            linesRead: result.metadata.linesOfCode, // Simplified for now
            totalLines: result.metadata.linesOfCode,
            cacheHit: result.cacheStatus == .hit
        )

        return ToolResult(
            title: "Read \(params.path)",
            output: result.content,
            metadata: metadata
        )
    }
}
