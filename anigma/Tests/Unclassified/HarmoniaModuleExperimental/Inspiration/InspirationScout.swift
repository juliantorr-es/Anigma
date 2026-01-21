//
//  InspirationScout.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Inspiration
//
//  Base class and specific scouts for mining patterns from inspiration repositories.
//  These scouts only write to InspirationIndex, never to main codebase.
//

import Foundation
import AnigmaASTServices
import AnigmaCore
import HarmoniaModule
import CryptoKit
import SwiftSyntax

/// Base protocol for inspiration scouts.
/// These scouts only operate on inspiration/ directory and write to InspirationIndex.
public protocol InspirationScout: Sendable {
    /// Unique identifier for this scout.
    var id: String { get }

    /// Human-readable name.
    var displayName: String { get }

    /// Scan an inspiration repository for patterns.
    /// - Parameters:
    ///   - repo: The inspiration repository to scan
    ///   - projectRoot: Root directory of the main project
    ///   - indexStore: InspirationIndexStore to write patterns to
    /// - Returns: Array of discovered patterns
    func scan(repo: InspirationRepo, projectRoot: String, indexStore: InspirationIndexStore) async throws -> [InspirationPattern]
}

/// Base implementation with common utilities.
open class BaseInspirationScout: InspirationScout {
    public let id: String
    public let displayName: String
    public let searchService: AgSearchService

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
        self.searchService = AgSearchService()
    }

    open func scan(repo: InspirationRepo, projectRoot: String, indexStore: InspirationIndexStore) async throws -> [InspirationPattern] {
        // Base implementation returns empty array
        return []
    }

    // MARK: - Common Utilities

    /// Get absolute path to inspiration repository.
    public func absolutePath(for repo: InspirationRepo, projectRoot: String) -> String {
        return URL(fileURLWithPath: projectRoot).appendingPathComponent(repo.path).path
    }

    /// Search for files matching pattern in inspiration repo.
    public func searchInRepo(
        _ repo: InspirationRepo,
        projectRoot: String,
        pattern: String,
        fileExtensions: [String] = ["swift"],
        excludePatterns: [String] = []
    ) async throws -> [String] {
        let repoPath = absolutePath(for: repo, projectRoot: projectRoot)
        let config = SearchConfig(
            pattern: pattern,
            directory: repoPath,
            fileExtensions: fileExtensions,
            ignorePatterns: excludePatterns
        )
        let results = try await searchService.search(config: config)
        let repoURL = URL(fileURLWithPath: repoPath).standardizedFileURL
        let repoPrefix = repoURL.path.hasSuffix("/") ? repoURL.path : "\(repoURL.path)/"
        let uniquePaths = Set(results.map { $0.filePath })
        return uniquePaths
            .map { path in
                let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
                if normalized.hasPrefix(repoPrefix) {
                    return String(normalized.dropFirst(repoPrefix.count))
                }
                return normalized
            }
            .sorted()
    }

    /// Read file content from inspiration repo.
    public func readFile(in repo: InspirationRepo, projectRoot: String, relativePath: String) throws -> String? {
        let repoPath = absolutePath(for: repo, projectRoot: projectRoot)
        let filePath = URL(fileURLWithPath: repoPath).appendingPathComponent(relativePath).path

        guard FileManager.default.fileExists(atPath: filePath) else {
            return nil
        }

        return try String(contentsOfFile: filePath, encoding: .utf8)
    }

    /// Extract a small, illustrative snippet from code (max 10 lines).
    public func extractExampleSnippet(from code: String, aroundLine: Int? = nil, maxLines: Int = 10) -> String {
        let lines = code.components(separatedBy: .newlines)

        guard !lines.isEmpty else {
            return "// No code available"
        }

        let startLine: Int
        if let aroundLine = aroundLine, aroundLine > 0 && aroundLine <= lines.count {
            // Try to center around the interesting line
            startLine = max(0, aroundLine - maxLines / 2)
        } else {
            startLine = 0
        }

        let endLine = min(lines.count, startLine + maxLines)
        let snippetLines = Array(lines[startLine..<endLine])

        // Trim empty lines from start and end
        let trimmed = snippetLines
            .drop { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            .reversed()
            .drop { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            .reversed()

        return trimmed.joined(separator: "\n")
    }

    /// Create AST fingerprint for code snippet.
    public func createASTFingerprint(for code: String) -> String? {
        do {
            let parsed = try ASTParser.parse(source: code, filePath: "inspiration.swift")
            let visitor = FingerprintVisitor()
            visitor.walk(parsed.ast)
            let payload = visitor.parts.joined(separator: "|")
            let digest = SHA256.hash(data: Data(payload.utf8))
            return digest.map { String(format: "%02x", $0) }.joined()
        } catch {
            return nil
        }
    }
}

private final class FingerprintVisitor: SyntaxAnyVisitor {
    var parts: [String] = []

    override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
        parts.append(String(describing: node.syntaxNodeType))
        return .visitChildren
    }
}

// MARK: - Specific Inspiration Scouts

/// Scouts for architecture patterns in inspiration repos.
public final class InspirationArchitectureScout: BaseInspirationScout {
    public init() {
        super.init(id: "inspiration-architecture", displayName: "Inspiration Architecture Scout")
    }

    public override func scan(repo: InspirationRepo, projectRoot: String, indexStore: InspirationIndexStore) async throws -> [InspirationPattern] {
        var patterns: [InspirationPattern] = []
        let repoPath = absolutePath(for: repo, projectRoot: projectRoot)

        logInfo("InspirationArchitectureScout scanning \(repo.name) at \(repoPath)", category: "InspirationScout")

        // Look for common architecture patterns
        let architectureFiles = try await searchInRepo(
            repo,
            projectRoot: projectRoot,
            pattern: "struct.*System|class.*System|protocol.*System|enum.*System",
            fileExtensions: ["swift"]
        )

        for file in architectureFiles.prefix(5) { // Limit to first 5 files
            if let content = try readFile(in: repo, projectRoot: projectRoot, relativePath: file) {
                // Look for ECS patterns
                if content.contains("Component") && content.contains("System") && content.contains("Entity") {
                    patterns.append(InspirationPattern(
                        repoId: repo.id,
                        patternId: "ecs-architecture-\(file)",
                        kind: .architecture,
                        language: "swift",
                        astFingerprint: createASTFingerprint(for: content),
                        description: "ECS (Entity-Component-System) architecture pattern",
                        exampleSnippet: extractExampleSnippet(from: content),
                        metadata: [
                            "file": file,
                            "pattern": "ecs",
                            "components": "Component, System, Entity"
                        ]
                    ))
                }

                // Look for pipeline patterns
                if content.contains("Pipeline") || content.contains("pipeline") {
                    patterns.append(InspirationPattern(
                        repoId: repo.id,
                        patternId: "pipeline-architecture-\(file)",
                        kind: .architecture,
                        language: "swift",
                        astFingerprint: createASTFingerprint(for: content),
                        description: "Pipeline/processing architecture pattern",
                        exampleSnippet: extractExampleSnippet(from: content),
                        metadata: [
                            "file": file,
                            "pattern": "pipeline"
                        ]
                    ))
                }

                // Look for rule-based systems
                if content.contains("Rule") && (content.contains("apply") || content.contains("transform")) {
                    patterns.append(InspirationPattern(
                        repoId: repo.id,
                        patternId: "rule-based-architecture-\(file)",
                        kind: .architecture,
                        language: "swift",
                        astFingerprint: createASTFingerprint(for: content),
                        description: "Rule-based transformation system",
                        exampleSnippet: extractExampleSnippet(from: content),
                        metadata: [
                            "file": file,
                            "pattern": "rule_based"
                        ]
                    ))
                }
            }
        }

        logInfo("InspirationArchitectureScout found \(patterns.count) architecture patterns in \(repo.name)", category: "InspirationScout")
        return patterns
    }
}

/// Scouts for AST traversal and manipulation patterns.
public final class InspirationASTScout: BaseInspirationScout {
    public init() {
        super.init(id: "inspiration-ast", displayName: "Inspiration AST Scout")
    }

    public override func scan(repo: InspirationRepo, projectRoot: String, indexStore: InspirationIndexStore) async throws -> [InspirationPattern] {
        var patterns: [InspirationPattern] = []

        logInfo("InspirationASTScout scanning \(repo.name) for AST patterns", category: "InspirationScout")

        // Look for SwiftSyntax usage
        let swiftSyntaxFiles = try await searchInRepo(
            repo,
            projectRoot: projectRoot,
            pattern: "SwiftSyntax|SyntaxRewriter|SyntaxVisitor",
            fileExtensions: ["swift"]
        )

        for file in swiftSyntaxFiles.prefix(5) {
            if let content = try readFile(in: repo, projectRoot: projectRoot, relativePath: file) {
                // Look for SyntaxRewriter patterns
                if content.contains("SyntaxRewriter") {
                    patterns.append(InspirationPattern(
                        repoId: repo.id,
                        patternId: "syntax-rewriter-\(file)",
                        kind: .astTraversal,
                        language: "swift",
                        astFingerprint: createASTFingerprint(for: content),
                        description: "SwiftSyntax SyntaxRewriter implementation pattern",
                        exampleSnippet: extractExampleSnippet(from: content),
                        metadata: [
                            "file": file,
                            "library": "SwiftSyntax",
                            "pattern": "syntax_rewriter"
                        ]
                    ))
                }

                // Look for SyntaxVisitor patterns
                if content.contains("SyntaxVisitor") {
                    patterns.append(InspirationPattern(
                        repoId: repo.id,
                        patternId: "syntax-visitor-\(file)",
                        kind: .astTraversal,
                        language: "swift",
                        astFingerprint: createASTFingerprint(for: content),
                        description: "SwiftSyntax SyntaxVisitor implementation pattern",
                        exampleSnippet: extractExampleSnippet(from: content),
                        metadata: [
                            "file": file,
                            "library": "SwiftSyntax",
                            "pattern": "syntax_visitor"
                        ]
                    ))
                }

                // Look for rewrite rule patterns
                if content.contains("RewriteRule") || content.contains("rewrite") {
                    patterns.append(InspirationPattern(
                        repoId: repo.id,
                        patternId: "rewrite-rule-\(file)",
                        kind: .ruleDesign,
                        language: "swift",
                        astFingerprint: createASTFingerprint(for: content),
                        description: "AST rewrite rule design pattern",
                        exampleSnippet: extractExampleSnippet(from: content),
                        metadata: [
                            "file": file,
                            "pattern": "rewrite_rule"
                        ]
                    ))
                }
            }
        }

        logInfo("InspirationASTScout found \(patterns.count) AST patterns in \(repo.name)", category: "InspirationScout")
        return patterns
    }
}

/// Scouts for CLI and tooling patterns.
public final class InspirationToolingScout: BaseInspirationScout {
    public init() {
        super.init(id: "inspiration-tooling", displayName: "Inspiration Tooling Scout")
    }

    public override func scan(repo: InspirationRepo, projectRoot: String, indexStore: InspirationIndexStore) async throws -> [InspirationPattern] {
        var patterns: [InspirationPattern] = []

        logInfo("InspirationToolingScout scanning \(repo.name) for tooling patterns", category: "InspirationScout")

        // Look for CLI patterns (ArgumentParser, CommandLine, etc.)
        let cliFiles = try await searchInRepo(
            repo,
            projectRoot: projectRoot,
            pattern: "ArgumentParser|CommandLine|main\\(|@main",
            fileExtensions: ["swift"]
        )

        for file in cliFiles.prefix(3) {
            if let content = try readFile(in: repo, projectRoot: projectRoot, relativePath: file) {
                if content.contains("ArgumentParser") {
                    patterns.append(InspirationPattern(
                        repoId: repo.id,
                        patternId: "argument-parser-\(file)",
                        kind: .cli,
                        language: "swift",
                        astFingerprint: createASTFingerprint(for: content),
                        description: "Swift ArgumentParser CLI pattern",
                        exampleSnippet: extractExampleSnippet(from: content),
                        metadata: [
                            "file": file,
                            "library": "ArgumentParser",
                            "pattern": "cli"
                        ]
                    ))
                }
            }
        }

        // Look for configuration files
        let configFiles = [
            ".swiftlint.yml",
            ".swiftformat",
            "Package.swift",
            "Makefile",
            "Dockerfile"
        ]

        for configFile in configFiles {
            if let content = try readFile(in: repo, projectRoot: projectRoot, relativePath: configFile) {
                patterns.append(InspirationPattern(
                    repoId: repo.id,
                    patternId: "config-\(configFile)",
                    kind: .config,
                    language: configFile.hasSuffix(".swift") ? "swift" : "config",
                    astFingerprint: nil,
                    description: "\(configFile) configuration pattern",
                    exampleSnippet: extractExampleSnippet(from: content, maxLines: 8),
                    metadata: [
                        "file": configFile,
                        "pattern": "configuration"
                    ]
                ))
            }
        }

        logInfo("InspirationToolingScout found \(patterns.count) tooling patterns in \(repo.name)", category: "InspirationScout")
        return patterns
    }
}

/// Scouts for caching and performance patterns.
public final class InspirationCachingScout: BaseInspirationScout {
    public init() {
        super.init(id: "inspiration-caching", displayName: "Inspiration Caching Scout")
    }

    public override func scan(repo: InspirationRepo, projectRoot: String, indexStore: InspirationIndexStore) async throws -> [InspirationPattern] {
        var patterns: [InspirationPattern] = []

        logInfo("InspirationCachingScout scanning \(repo.name) for caching patterns", category: "InspirationScout")

        // Look for caching patterns
        let cachingFiles = try await searchInRepo(
            repo,
            projectRoot: projectRoot,
            pattern: "cache|Cache|LRU|memoiz|Memoiz",
            fileExtensions: ["swift"]
        )

        for file in cachingFiles.prefix(3) {
            if let content = try readFile(in: repo, projectRoot: projectRoot, relativePath: file) {
                // Look for LRU cache patterns
                if content.contains("LRU") || content.contains("least recently used") {
                    patterns.append(InspirationPattern(
                        repoId: repo.id,
                        patternId: "lru-cache-\(file)",
                        kind: .caching,
                        language: "swift",
                        astFingerprint: createASTFingerprint(for: content),
                        description: "LRU (Least Recently Used) cache implementation",
                        exampleSnippet: extractExampleSnippet(from: content),
                        metadata: [
                            "file": file,
                            "pattern": "lru_cache"
                        ]
                    ))
                }

                // Look for memoization patterns
                if content.contains("memoiz") || content.contains("Memoiz") {
                    patterns.append(InspirationPattern(
                        repoId: repo.id,
                        patternId: "memoization-\(file)",
                        kind: .caching,
                        language: "swift",
                        astFingerprint: createASTFingerprint(for: content),
                        description: "Function memoization pattern",
                        exampleSnippet: extractExampleSnippet(from: content),
                        metadata: [
                            "file": file,
                            "pattern": "memoization"
                        ]
                    ))
                }
            }
        }

        logInfo("InspirationCachingScout found \(patterns.count) caching patterns in \(repo.name)", category: "InspirationScout")
        return patterns
    }
}
