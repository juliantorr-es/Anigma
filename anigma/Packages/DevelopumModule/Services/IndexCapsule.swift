//
//  IndexCapsule.swift
//  DevelopumModule
//
//  Fast file/text search without LSP dependencies.
//  Uses index artifacts from the database for efficient searching.
//
//  Key capabilities:
//  - Regex, case-sensitive, and whole-word matching
//  - Multi-file repository search
//  - Returns structured search results with line/column info
//

import AnigmaCore
import AnigmaPrimitives
import Foundation
import TelemetryCore
import CryptoKit
import DatabaseCore

/// Search options configuration.
public struct SearchOptions: Codable, Sendable, Hashable {
    /// Whether to interpret query as regex.
    public var isRegex: Bool

    /// Whether to match case sensitively.
    public var matchCase: Bool

    /// Whether to match whole words only.
    public var matchWholeWord: Bool

    /// Maximum number of results to return.
    public var maxResults: Int

    /// Optional glob pattern to filter files.
    public var filePattern: String?

    /// Maximum file size in bytes to search (0 = unlimited).
    public var maxFileSizeBytes: Int64

    public init(
        isRegex: Bool = false,
        matchCase: Bool = false,
        matchWholeWord: Bool = false,
        maxResults: Int = 1000,
        filePattern: String? = nil,
        maxFileSizeBytes: Int64 = 10_000_000
    ) {
        self.isRegex = isRegex
        self.matchCase = matchCase
        self.matchWholeWord = matchWholeWord
        self.maxResults = maxResults
        self.filePattern = filePattern
        self.maxFileSizeBytes = maxFileSizeBytes
    }

    public static let `default` = SearchOptions()
}

/// Actor for fast file/text search operations.
public actor IndexCapsule {
    private let databaseService: DevelopumDatabaseService
    private let telemetryClient: TelemetryClient?

    private var searchCache: [String: CacheEntry] = [:]
    private let cacheTTLSeconds: TimeInterval = 300
    private let maxCacheEntries: Int = 100

    public init(
        databaseService: DevelopumDatabaseService,
        telemetryClient: TelemetryClient? = nil
    ) {
        self.databaseService = databaseService
        self.telemetryClient = telemetryClient
    }

    // MARK: - Public API

    /// Search across files in a repository using indexed content.
    /// - Parameters:
    ///   - repoId: Repository session ID.
    ///   - query: Search query string.
    ///   - options: Search options configuration.
    /// - Returns: Array of search results.
    public func searchFiles(
        repoId: UUID,
        query: String,
        options: SearchOptions = .default
    ) async throws -> [SearchResult] {
        let startTime = Date()
        let queryKey = "\(repoId.uuidString):\(query):\(options.hashValue)"

        if let cached = searchCache[queryKey], !cached.isExpired {
            await telemetryClient?.emit(
                category: .tool,
                name: "developum.search.cache_hit",
                values: ["query": .limitedTag(try! TelemetryTag(query))]
            )
            return cached.results
        }

        var results: [SearchResult] = []

        let artifacts = try await databaseService.getIndexArtifacts(repoId: repoId)

        let filteredArtifacts = applyFilePatternFilter(artifacts, pattern: options.filePattern)
            .filter { $0.fileSize <= options.maxFileSizeBytes || options.maxFileSizeBytes == 0 }

        for artifact in filteredArtifacts {
            let artifactResults = searchInArtifact(artifact, query: query, options: options)
            results.append(contentsOf: artifactResults)

            if results.count >= options.maxResults {
                break
            }
        }

        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
        let truncated = results.count >= options.maxResults

        let cacheEntry = CacheEntry(results: results, createdAt: Date())
        searchCache[queryKey] = cacheEntry
        evictCacheIfNeeded()

        await telemetryClient?.emit(
            category: .tool,
            name: "developum.search.completed",
            values: [
                "query": .limitedTag(try! TelemetryTag(query)),
                "resultCount": .integer(results.count),
                "durationMs": .integer(Int(durationMs)),
                "truncated": .boolean(truncated)
            ]
        )

        return results
    }

    /// Search within a single index content blob.
    /// - Parameters:
    ///   - indexContent: Pre-loaded index content data.
    ///   - query: Search query string.
    ///   - options: Search options configuration.
    /// - Returns: Array of search results.
    public func searchInContent(
        indexContent: Data,
        query: String,
        options: SearchOptions
    ) -> [SearchResult] {
        guard let content = try? JSONSerialization.jsonObject(with: indexContent) as? [String: Any],
              let lines = content["lines"] as? [[String: Any]] else {
            return []
        }

        return performLineSearch(lines: lines, query: query, options: options, fileUri: "")
    }

    /// Build and save search index for given file paths.
    /// - Parameters:
    ///   - repoId: Repository session ID.
    ///   - filePaths: Array of file paths to index.
    ///   - contentLoader: Closure to load file content.
    public func buildSearchIndex(
        repoId: UUID,
        filePaths: [String],
        contentLoader: ((String) async throws -> String)? = nil
    ) async throws {
        for filePath in filePaths {
            try await indexFile(repoId: repoId, filePath: filePath, contentLoader: contentLoader)
        }
    }

    /// Invalidate cache for a repository.
    public func invalidateCache(repoId: UUID? = nil) {
        if let repoId = repoId {
            let keysToRemove = searchCache.keys.filter { $0.hasPrefix(repoId.uuidString + ":") }
            for key in keysToRemove {
                searchCache.removeValue(forKey: key)
            }
        } else {
            searchCache.removeAll()
        }
    }

    /// Get cache statistics.
    public func getCacheStats() -> CacheStats {
        let now = Date()
        var activeCount = 0
        var expiredCount = 0

        for entry in searchCache.values {
            if entry.isExpired {
                expiredCount += 1
            } else {
                activeCount += 1
            }
        }

        return CacheStats(
            totalEntries: searchCache.count,
            activeEntries: activeCount,
            expiredEntries: expiredCount,
            ttlSeconds: cacheTTLSeconds
        )
    }

    // MARK: - Private Methods

    private func indexFile(
        repoId: UUID,
        filePath: String,
        contentLoader: ((String) async throws -> String)?
    ) async throws {
        let fullPath: String

        if let loader = contentLoader {
            _ = try await loader(filePath)
        } else {
            let repoRecord = try await databaseService.getRepoRecord(id: repoId)
            guard let repo = repoRecord else {
                throw IndexCapsuleError.repoNotFound
            }
            fullPath = "\(repo.repoPath)/\(filePath)"

            let fileURL = URL(fileURLWithPath: fullPath)
            let content = try String(contentsOf: fileURL, encoding: .utf8)

            try await saveIndexArtifact(
                repoId: repoId,
                filePath: filePath,
                content: content
            )
        }
    }

    private func saveIndexArtifact(
        repoId: UUID,
        filePath: String,
        content: String
    ) async throws {
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: content)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        let fileModifiedAt = fileAttributes[.modificationDate] as? Date ?? Date()

        let hash = computeHash(content: content)
        let indexContent = try buildIndexContent(content: content, filePath: filePath)
        let mimeType = detectMimeType(for: filePath)
        let languageId = detectLanguageId(for: filePath)

        let artifact = IndexArtifactRecord(
            repoId: repoId,
            artifactHash: hash,
            filePath: filePath,
            mimeType: mimeType,
            languageId: languageId,
            fileSize: fileSize,
            fileModifiedAt: fileModifiedAt,
            indexedAt: Date(),
            indexContent: indexContent,
            isCurrent: true
        )

        try await databaseService.markIndexArtifactsStale(repoId: repoId, filePath: filePath)
        try await databaseService.saveIndexArtifact(artifact)
    }

    private func searchInArtifact(
        _ artifact: IndexArtifactRecord,
        query: String,
        options: SearchOptions
    ) -> [SearchResult] {
        guard !artifact.indexContent.isEmpty else { return [] }

        guard let content = try? JSONSerialization.jsonObject(with: artifact.indexContent) as? [String: Any],
              let lines = content["lines"] as? [[String: Any]] else {
            return []
        }

        let fileUri = "anigma://\(artifact.filePath)"
        return performLineSearch(lines: lines, query: query, options: options, fileUri: fileUri)
    }

    private func performLineSearch(
        lines: [[String: Any]],
        query: String,
        options: SearchOptions,
        fileUri: String
    ) -> [SearchResult] {
        var results: [SearchResult] = []
        let matchingOptions: NSString.CompareOptions = options.matchCase ? [] : .caseInsensitive

        let pattern: String
        if options.matchWholeWord && !options.isRegex {
            pattern = "\\b\(NSRegularExpression.escapedPattern(for: query))\\b"
        } else if options.matchWholeWord && options.isRegex {
            pattern = "\\b\(query)\\b"
        } else {
            pattern = options.isRegex ? query : NSRegularExpression.escapedPattern(for: query)
        }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: options.matchCase ? [] : .caseInsensitive) else {
            return []
        }

        for lineData in lines {
            guard let lineNumber = lineData["lineNumber"] as? Int,
                  let lineText = lineData["text"] as? String else {
                continue
            }

            let range = NSRange(location: 0, length: lineText.utf16.count)
            let matches = regex.matches(in: lineText, options: [], range: range)

            for match in matches {
                let matchStart = lineText.index(lineText.startIndex, offsetBy: match.range.location)
                let matchEnd = lineText.index(matchStart, offsetBy: match.range.length)
                let matchRange = matchStart..<matchEnd
                if matchRange != nil {
                    let matchText = String(lineText[matchRange])

                    let column = matchRange.lowerBound.utf16Offset(in: lineText) ?? lineText.distance(from: lineText.startIndex, to: matchRange.lowerBound)

                    let result = SearchResult(
                        fileUri: fileUri,
                        line: lineNumber,
                        column: column,
                        match: matchText,
                        lineText: lineText
                    )
                    results.append(result)
                }

                if results.count >= options.maxResults {
                    return results
                }
            }
        }

        return results
    }

    private func buildIndexContent(content: String, filePath: String) throws -> Data {
        let lines = content.components(separatedBy: .newlines)

        var indexData: [String: Any] = [:]
        indexData["version"] = "1.0"
        indexData["filePath"] = filePath
        indexData["lineCount"] = lines.count
        indexData["indexedAt"] = ISO8601DateFormatter().string(from: Date())

        let indexedLines = lines.enumerated().map { index, line in
            [
                "lineNumber": index + 1,
                "text": line,
                "length": line.utf8.count
            ]
        }

        indexData["lines"] = indexedLines

        return try JSONSerialization.data(withJSONObject: indexData, options: [.sortedKeys])
    }

    private func applyFilePatternFilter(_ artifacts: [IndexArtifactRecord], pattern: String?) -> [IndexArtifactRecord] {
        guard let pattern = pattern, !pattern.isEmpty else {
            return artifacts
        }

        let normalizedPattern = pattern.replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")

        guard let regex = try? NSRegularExpression(pattern: "^\(normalizedPattern)$", options: .caseInsensitive) else {
            return artifacts
        }

        return artifacts.filter { artifact in
            let range = NSRange(artifact.filePath.startIndex..., in: artifact.filePath)
            return regex.firstMatch(in: artifact.filePath, options: [], range: range) != nil
        }
    }

    private func computeHash(content: String) -> String {
        let data = Data(content.utf8)
        var hash = SHA256()
        hash.update(data: data)
        let digest = hash.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func detectMimeType(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()

        let mimeTypes: [String: String] = [
            "swift": "text/x-swift",
            "js": "text/javascript",
            "ts": "text/typescript",
            "tsx": "text/typescript",
            "jsx": "text/javascript",
            "py": "text/x-python",
            "rs": "text/x-rust",
            "go": "text/x-go",
            "java": "text/x-java",
            "kt": "text/x-kotlin",
            "rb": "text/x-ruby",
            "php": "text/x-php",
            "c": "text/x-c",
            "cpp": "text/x-c++",
            "h": "text/x-c",
            "hpp": "text/x-c++",
            "m": "text/x-objc",
            "mm": "text/x-objc++",
            "sh": "text/x-shellscript",
            "json": "application/json",
            "yaml": "text/yaml",
            "yml": "text/yaml",
            "xml": "text/xml",
            "html": "text/html",
            "css": "text/css",
            "md": "text/markdown",
            "txt": "text/plain"
        ]

        return mimeTypes[ext] ?? "text/plain"
    }

    private func detectLanguageId(for path: String) -> String? {
        let ext = (path as NSString).pathExtension.lowercased()

        let languageIds: [String: String] = [
            "swift": "swift",
            "js": "javascript",
            "ts": "typescript",
            "tsx": "typescript",
            "jsx": "javascript",
            "py": "python",
            "rs": "rust",
            "go": "go",
            "java": "java",
            "kt": "kotlin",
            "rb": "ruby",
            "php": "php",
            "c": "c",
            "cpp": "cpp",
            "h": "c",
            "hpp": "cpp",
            "m": "objective-c",
            "mm": "objective-c",
            "sh": "shell",
            "json": "json",
            "yaml": "yaml",
            "yml": "yaml",
            "xml": "xml",
            "html": "html",
            "css": "css",
            "md": "markdown"
        ]

        return languageIds[ext]
    }

    private func evictCacheIfNeeded() {
        while searchCache.count > maxCacheEntries {
            var oldestKey: String?
            var oldestDate = Date.distantFuture

            for (key, entry) in searchCache {
                if entry.createdAt < oldestDate {
                    oldestDate = entry.createdAt
                    oldestKey = key
                }
            }

            if let key = oldestKey {
                searchCache.removeValue(forKey: key)
            } else {
                break
            }
        }
    }
}

// MARK: - Supporting Types

private struct CacheEntry {
    let results: [SearchResult]
    let createdAt: Date

    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > 300
    }
}

public struct CacheStats: Sendable {
    public let totalEntries: Int
    public let activeEntries: Int
    public let expiredEntries: Int
    public let ttlSeconds: TimeInterval
}

public enum IndexCapsuleError: LocalizedError {
    case repoNotFound
    case fileNotFound
    case invalidIndexContent
    case searchPatternInvalid(String)

    public var errorDescription: String? {
        switch self {
        case .repoNotFound:
            return "Repository not found"
        case .fileNotFound:
            return "File not found"
        case .invalidIndexContent:
            return "Invalid index content format"
        case .searchPatternInvalid(let pattern):
            return "Invalid search pattern: \(pattern)"
        }
    }
}
