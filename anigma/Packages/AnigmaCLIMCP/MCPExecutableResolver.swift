//
//  MCPExecutableResolver.swift
//  AnigmaCLIMCP
//
//  Resolves the anigma-mcp executable path for local MCP connections.
//

import AnigmaCLIProviders
import Foundation

public struct MCPExecutableResolver: Sendable {
    private let environment: [String: String]
    private let locator: ExecutableLocator

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        locator: ExecutableLocator? = nil
    ) {
        self.environment = environment
        self.locator = locator ?? ExecutableLocator(environment: environment)
    }

    public func resolve(repoRoot: URL) -> URL? {
        if let override = environment["ANIGMA_MCP_PATH"],
           let resolved = locator.resolveExecutable(override) {
            return resolved
        }

        let localCandidates = [
            repoRoot.appendingPathComponent(".build/arm64-apple-macosx/debug/anigma-mcp"),
            repoRoot.appendingPathComponent(".build/arm64-apple-macosx/release/anigma-mcp"),
            repoRoot.appendingPathComponent(".build/x86_64-apple-macosx/debug/anigma-mcp"),
            repoRoot.appendingPathComponent(".build/x86_64-apple-macosx/release/anigma-mcp"),
            repoRoot.appendingPathComponent(".build/debug/anigma-mcp"),
            repoRoot.appendingPathComponent(".build/release/anigma-mcp")
        ]

        let fileManager = FileManager.default
        for candidate in localCandidates {
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        return locator.resolveExecutable("anigma-mcp")
    }
}
