//
//  DaemonServer+AST.swift
//  AnigmaDaemonCore
//
//  AST analysis service handlers for daemon-owned in-process AST operations.
//

import Foundation
import AnigmaASTServicesCore

extension DaemonServer {
    /// Parse a Swift file and return AST structure
    /// - Parameter filePath: Path to the Swift file
    /// - Returns: AST parse result
    public func parseSwiftFile(_ filePath: String) async throws -> ASTResult {
        return try await astAuthority.parseFile(filePath)
    }
    
    /// Analyze a Swift file with specified visitors
    /// - Parameters:
    ///   - filePath: Path to the Swift file
    ///   - visitors: Array of visitor names (security, quality, concurrency, architecture)
    /// - Returns: AST analysis result
    public func analyzeSwiftFile(_ filePath: String, visitors: [String]) async throws -> ASTResult {
        return try await astAuthority.analyzeFile(filePath, visitors: visitors)
    }
    
    /// Analyze a directory of Swift files
    /// - Parameters:
    ///   - directoryPath: Path to the directory
    ///   - visitors: Array of visitor names
    /// - Returns: Array of AST analysis results
    public func analyzeSwiftDirectory(_ directoryPath: String, visitors: [String]) async throws -> [ASTResult] {
        return try await astAuthority.analyzeDirectory(directoryPath, visitors: visitors)
    }
    
    /// Get AST service status
    /// - Returns: Current AST service status
    public func getASTServiceStatus() async -> ASTServiceStatus {
        return await astAuthority.getStatus()
    }
    
    /// Clear AST cache
    /// - Parameter filePath: Optional file path to clear specific cache entry, or nil to clear all
    public func clearASTCache(for filePath: String? = nil) async {
        await astAuthority.clearCache(for: filePath)
    }
}
