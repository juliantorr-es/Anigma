//
//  ASTAuthority.swift
//  AnigmaDaemonCore
//
//  Protocol for AST analysis authorities.
//

import Foundation
import AnigmaASTServices

/// Protocol for AST analysis authorities
public protocol ASTAuthority: Actor, Sendable {
    /// Parse a Swift file
    /// - Parameter filePath: Path to Swift file
    /// - Returns: Parse result
    func parseFile(_ filePath: String) async throws -> ASTResult
    
    /// Analyze a Swift file with specific visitors
    /// - Parameters:
    ///   - filePath: Path to Swift file
    ///   - visitors: Visitors to run (security, quality, concurrency, architecture)
    /// - Returns: Analysis result
    func analyzeFile(_ filePath: String, visitors: [String]) async throws -> ASTResult
    
    /// Analyze a directory of Swift files
    /// - Parameters:
    ///   - directoryPath: Path to directory
    ///   - visitors: Visitors to run
    /// - Returns: Array of analysis results
    func analyzeDirectory(_ directoryPath: String, visitors: [String]) async throws -> [ASTResult]
    
    /// Get service status
    /// - Returns: Status information
    func getStatus() async -> ASTServiceStatus
}

/// AST service status
public struct ASTServiceStatus: Sendable {
    /// Whether AST service is available
    public let isAvailable: Bool
    /// Current load (0.0 to 1.0)
    public let currentLoad: Double
    /// Cache statistics
    public let cacheStats: ASTCacheStats?
    /// Engine information
    public let engineInfo: ASTEngineInfo?
    
    public init(
        isAvailable: Bool,
        currentLoad: Double = 0.0,
        cacheStats: ASTCacheStats? = nil,
        engineInfo: ASTEngineInfo? = nil
    ) {
        self.isAvailable = isAvailable
        self.currentLoad = currentLoad
        self.cacheStats = cacheStats
        self.engineInfo = engineInfo
    }
}

/// AST cache statistics
public struct ASTCacheStats: Sendable {
    /// Number of cache entries
    public let entries: Int
    /// Cache size in bytes
    public let sizeBytes: Int
    /// Cache hit rate (0.0 to 1.0)
    public let hitRate: Double
    
    public init(entries: Int, sizeBytes: Int, hitRate: Double) {
        self.entries = entries
        self.sizeBytes = sizeBytes
        self.hitRate = hitRate
    }
}

/// AST engine information
public struct ASTEngineInfo: Sendable {
    /// Engine identifier
    public let engineId: String
    /// Engine version
    public let version: String
    /// SwiftSyntax version
    public let swiftSyntaxVersion: String
    
    public init(engineId: String, version: String, swiftSyntaxVersion: String) {
        self.engineId = engineId
        self.version = version
        self.swiftSyntaxVersion = swiftSyntaxVersion
    }
}

/// AST authority errors
public enum ASTAuthorityError: Error, LocalizedError, Sendable {
    case serviceUnavailable
    case fileNotFound(String)
    case parseError(String)
    case analysisError(String)
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "AST service unavailable"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .parseError(let reason):
            return "Parse error: \(reason)"
        case .analysisError(let reason):
            return "Analysis error: \(reason)"
        case .timeout:
            return "Operation timed out"
        }
    }
}