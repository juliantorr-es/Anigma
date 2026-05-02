//
//  CodeSearchWorker.swift
//  AnigmaDaemonCore
//
//  Worker for heuristic code search using AgSearchService.
//

import Foundation
import AnigmaCore
import AnigmaASTServicesCore
import ContractsCore

/// Configuration for code search job.
public struct CodeSearchConfig: Codable, Sendable {
    public let pattern: String
    public let directory: String
    public let fileExtensions: [String]
    public let ignorePatterns: [String]
    public let caseSensitive: Bool
    public let contextLines: Int
    
    public init(
        pattern: String,
        directory: String = ".",
        fileExtensions: [String] = ["swift"],
        ignorePatterns: [String] = [],
        caseSensitive: Bool = true,
        contextLines: Int = 2
    ) {
        self.pattern = pattern
        self.directory = directory
        self.fileExtensions = fileExtensions
        self.ignorePatterns = ignorePatterns
        self.caseSensitive = caseSensitive
        self.contextLines = contextLines
    }
}

/// Worker that executes code search.
public struct CodeSearchWorker: JobWorker {
    public static let kind = "code.search"
    
    private let searchService: AgSearchService
    
    public init() {
        self.searchService = AgSearchService()
    }
    
    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        // 1. Decode Configuration
        let searchConfig = try JSONDecoder().decode(CodeSearchConfig.self, from: config)
        
        // 2. Prepare AgSearchService Config
        let agConfig = SearchConfig(
            pattern: searchConfig.pattern,
            directory: searchConfig.directory,
            fileExtensions: searchConfig.fileExtensions,
            ignorePatterns: searchConfig.ignorePatterns,
            caseSensitive: searchConfig.caseSensitive,
            contextLines: searchConfig.contextLines
        )
        
        // 3. Execute Search
        let results = try await searchService.search(config: agConfig)
        
        // 4. Package Results
        let resultData = try JSONEncoder().encode(results)
        return [
            JobOutputPayload(
                data: resultData,
                mediaType: "application/json",
                kind: "code.search.result"
            )
        ]
    }
}
