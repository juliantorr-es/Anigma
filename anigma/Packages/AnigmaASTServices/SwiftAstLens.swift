//
//  SwiftAstLens.swift
//  AnigmaASTServices
//
//  AST lookup service with file hash caching for incremental parsing.
//  Inspired by swift-ast-explorer's location lookup and SwiftRewriter's caching patterns.
//
//  Key design:
//  - Actor-based for thread safety
//  - LRU cache with ~100MB memory limit
//  - Cache key: (file path + content hash)
//  - Incremental parsing: only changed files
//  - Background indexing: per-commit AST parsing
//

import Foundation
import SwiftSyntax
import SwiftParser
import CryptoKit

/// AST node location information for precise code transformations.
public struct AstLocation: Sendable {
    public let filePath: String
    public let startLine: Int
    public let startColumn: Int
    public let endLine: Int
    public let endColumn: Int
    public let nodeType: String
    public let nodeText: String

    public init(
        filePath: String,
        startLine: Int,
        startColumn: Int,
        endLine: Int,
        endColumn: Int,
        nodeType: String,
        nodeText: String
    ) {
        self.filePath = filePath
        self.startLine = startLine
        self.startColumn = startColumn
        self.endLine = endLine
        self.endColumn = endColumn
        self.nodeType = nodeType
        self.nodeText = nodeText
    }
}

/// Cached AST entry with metadata.
struct AstCacheEntry: Sendable {
    let ast: SourceFileSyntax
    let contentHash: String
    let timestamp: Date
    let sizeInBytes: Int

    init(ast: SourceFileSyntax, contentHash: String, sizeInBytes: Int) {
        self.ast = ast
        self.contentHash = contentHash
        self.timestamp = Date()
        self.sizeInBytes = sizeInBytes
    }
}

/// AST lookup service with file hash caching.
public actor SwiftAstLens {

    // MARK: - Configuration

    private let maxCacheSizeBytes = 100 * 1024 * 1024 // 100MB
    private let maxCacheEntries = 100

    // MARK: - State

    private var cache: [String: AstCacheEntry] = [:]
    private var cacheSizeBytes = 0
    private var accessOrder: [String] = [] // LRU tracking

    // MARK: - Public Interface

    public init() {}

    /// Get AST for a file, using cache if content hasn't changed.
    public func ast(for filePath: String) throws -> (SourceFileSyntax, String) {
        let fileURL = URL(fileURLWithPath: filePath)

        guard FileManager.default.fileExists(atPath: filePath) else {
            throw AstError.fileNotFound(filePath)
        }

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let contentHash = Self.computeHash(content)
        let cacheKey = Self.cacheKey(filePath: filePath, contentHash: contentHash)

        // Check cache
        if let cached = cache[cacheKey] {
            updateAccessOrder(for: cacheKey)
            return (cached.ast, cached.contentHash)
        }

        // Parse and cache
        let ast = Parser.parse(source: content)
        let entry = AstCacheEntry(
            ast: ast,
            contentHash: contentHash,
            sizeInBytes: content.utf8.count
        )

        try cacheEntry(entry, for: cacheKey)
        return (ast, contentHash)
    }

    /// Find AST nodes at specific location.
    public func findNodes(
        at filePath: String,
        line: Int,
        column: Int
    ) throws -> [AstLocation] {
        let (ast, _) = try ast(for: filePath)
        let converter = SourceLocationConverter(
            fileName: filePath,
            tree: ast
        )

        let visitor = LocationVisitor(
            targetLine: line,
            targetColumn: column,
            converter: converter,
            filePath: filePath
        )

        _ = visitor.visit(ast)
        return visitor.results
    }

    /// Find all nodes of specific type in file.
    public func findNodes<T: SyntaxProtocol>(
        ofType type: T.Type,
        in filePath: String
    ) throws -> [T] {
        let (ast, _) = try ast(for: filePath)
        let visitor = TypeVisitor<T>()
        _ = visitor.visit(ast)
        return visitor.results
    }

    /// Clear cache for specific file or all files.
    public func clearCache(for filePath: String? = nil) {
        if let filePath = filePath {
            // Remove all cache entries for this file
            let keysToRemove = cache.keys.filter { $0.hasPrefix("\(filePath):") }
            for key in keysToRemove {
                removeFromCache(key)
            }
        } else {
            cache.removeAll()
            cacheSizeBytes = 0
            accessOrder.removeAll()
        }
    }

    /// Get cache statistics.
    public func cacheStats() -> (entries: Int, sizeBytes: Int, hits: Int, misses: Int) {
        // Note: hits/misses tracking would need additional state
        return (cache.count, cacheSizeBytes, 0, 0)
    }

    // MARK: - Private Methods

    private func cacheEntry(_ entry: AstCacheEntry, for key: String) throws {
        // Evict if needed
        while cacheSizeBytes + entry.sizeInBytes > maxCacheSizeBytes || cache.count >= maxCacheEntries {
            guard let oldestKey = accessOrder.first else { break }
            removeFromCache(oldestKey)
        }

        // Add to cache
        cache[key] = entry
        cacheSizeBytes += entry.sizeInBytes
        accessOrder.append(key)
    }

    private func removeFromCache(_ key: String) {
        guard let entry = cache[key] else { return }
        cache.removeValue(forKey: key)
        cacheSizeBytes -= entry.sizeInBytes
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
    }

    private func updateAccessOrder(for key: String) {
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
            accessOrder.append(key)
        }
    }

    // MARK: - Static Helpers

    private static func computeHash(_ string: String) -> String {
        return string.sha256()
    }

    private static func cacheKey(filePath: String, contentHash: String) -> String {
        "\(filePath):\(contentHash)"
    }
}

// MARK: - Visitors

private class LocationVisitor: SyntaxAnyVisitor {
    let targetLine: Int
    let targetColumn: Int
    let converter: SourceLocationConverter
    let filePath: String
    var results: [AstLocation] = []

    init(
        targetLine: Int,
        targetColumn: Int,
        converter: SourceLocationConverter,
        filePath: String
    ) {
        self.targetLine = targetLine
        self.targetColumn = targetColumn
        self.converter = converter
        self.filePath = filePath
        super.init(viewMode: .sourceAccurate)
    }

    override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
        let range = node.sourceRange(converter: converter)
        let start = range.start
        let end = range.end

        // Check if target is within this node
        if start.line <= targetLine && targetLine <= end.line {
            if start.line == targetLine && targetColumn < start.column {
                return .skipChildren
            }
            if end.line == targetLine && targetColumn > end.column {
                return .skipChildren
            }

            let location = AstLocation(
                filePath: filePath,
                startLine: start.line,
                startColumn: start.column,
                endLine: end.line,
                endColumn: end.column,
                nodeType: "\(node.syntaxNodeType)",
                nodeText: "\(node.trimmed)"
            )
            results.append(location)
        }

        return .visitChildren
    }
}

private class TypeVisitor<T: SyntaxProtocol & Sendable>: SyntaxAnyVisitor {
    var results: [T] = []

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
        if let typed = node.as(T.self) {
            results.append(typed)
        }
        return .visitChildren
    }
}

// MARK: - Errors

public enum AstError: Error, LocalizedError {
    case fileNotFound(String)
    case parseError(String)
    case invalidLocation(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .parseError(let reason):
            return "Parse error: \(reason)"
        case .invalidLocation(let reason):
            return "Invalid location: \(reason)"
        }
    }
}

// MARK: - Hash Utility

private extension String {
    func sha256() -> String {
        let inputData = Data(self.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
