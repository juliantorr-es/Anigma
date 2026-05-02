//
//  AgSearchService.swift
//  AnigmaASTServices
//
//  Fast code search service inspired by The Silver Searcher (ag).
//  Used as prefilter before AST analysis to avoid parsing irrelevant files.
//
//  Key design:
//  - Boyer-Moore string search for fast pattern matching
//  - File extension filtering
//  - Ignore patterns (like .gitignore)
//  - Parallel file scanning
//  - Memory-mapped file I/O for large files
//

import Foundation

/// Search result containing file and match information.
public struct SearchResult: Sendable, Codable {
    public let filePath: String
    public let lineNumber: Int
    public let column: Int
    public let matchedText: String
    public let context: String

    public init(
        filePath: String,
        lineNumber: Int,
        column: Int,
        matchedText: String,
        context: String
    ) {
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.column = column
        self.matchedText = matchedText
        self.context = context
    }
}

/// Search configuration.
public struct SearchConfig: Sendable {
    public let pattern: String
    public let directory: String
    public let fileExtensions: [String]
    public let ignorePatterns: [String]
    public let caseSensitive: Bool
    public let maxFileSize: Int // bytes
    public let contextLines: Int

    public init(
        pattern: String,
        directory: String = ".",
        fileExtensions: [String] = ["swift"],
        ignorePatterns: [String] = [],
        caseSensitive: Bool = true,
        maxFileSize: Int = 10 * 1024 * 1024, // 10MB
        contextLines: Int = 2
    ) {
        self.pattern = pattern
        self.directory = directory
        self.fileExtensions = fileExtensions
        self.ignorePatterns = ignorePatterns
        self.caseSensitive = caseSensitive
        self.maxFileSize = maxFileSize
        self.contextLines = contextLines
    }
}

/// Fast code search service.
public actor AgSearchService {

    // MARK: - State

    private var fileCache: [String: (size: Int, modified: Date)] = [:]
    private let fileManager = FileManager.default

    // MARK: - Public Interface

    public init() {}

    /// Search for pattern in directory.
    public func search(config: SearchConfig) async throws -> [SearchResult] {
        let startTime = Date()

        // Collect files to search
        let files = try collectFiles(
            in: config.directory,
            extensions: config.fileExtensions,
            ignorePatterns: config.ignorePatterns,
            maxSize: config.maxFileSize
        )

        // Parallel search
        let results = try await withThrowingTaskGroup(of: [SearchResult].self) { group in
            for file in files {
                group.addTask {
                    try await self.searchInFile(
                        filePath: file,
                        pattern: config.pattern,
                        caseSensitive: config.caseSensitive,
                        contextLines: config.contextLines
                    )
                }
            }

            var allResults: [SearchResult] = []
            for try await fileResults in group {
                allResults.append(contentsOf: fileResults)
            }
            return allResults
        }

        let duration = Date().timeIntervalSince(startTime)
        print("Search completed in \(String(format: "%.3f", duration))s: \(results.count) matches in \(files.count) files")

        return results
    }

    /// Clear file cache.
    public func clearCache() {
        fileCache.removeAll()
    }

    // MARK: - Private Methods

    private func collectFiles(
        in directory: String,
        extensions: [String],
        ignorePatterns: [String],
        maxSize: Int
    ) throws -> [String] {
        let directoryURL = URL(fileURLWithPath: directory)
        var files: [String] = []

        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            let filePath = fileURL.path

            // Check ignore patterns
            if shouldIgnore(filePath: filePath, patterns: ignorePatterns) {
                if fileURL.hasDirectoryPath {
                    enumerator.skipDescendants()
                }
                continue
            }

            // Check file extension
            guard extensions.isEmpty || extensions.contains(fileURL.pathExtension) else {
                continue
            }

            // Check file size
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = resourceValues.fileSize ?? 0

            guard fileSize <= maxSize else {
                continue
            }

            // Check cache for changes
            let modified = resourceValues.contentModificationDate ?? Date.distantPast
            if let cached = fileCache[filePath], cached.size == fileSize, cached.modified == modified {
                // File unchanged, skip
                continue
            }

            // Update cache
            fileCache[filePath] = (fileSize, modified)
            files.append(filePath)
        }

        return files
    }

    private func shouldIgnore(filePath: String, patterns: [String]) -> Bool {
        for pattern in patterns {
            if filePath.contains(pattern) {
                return true
            }

            // Simple glob pattern matching
            if pattern.contains("*") {
                let regexPattern = pattern
                    .replacingOccurrences(of: ".", with: "\\.")
                    .replacingOccurrences(of: "*", with: ".*")
                    .replacingOccurrences(of: "?", with: ".")

                if let regex = try? NSRegularExpression(pattern: regexPattern) {
                    let range = NSRange(filePath.startIndex..., in: filePath)
                    if regex.firstMatch(in: filePath, range: range) != nil {
                        return true
                    }
                }
            }
        }
        return false
    }

    private func searchInFile(
        filePath: String,
        pattern: String,
        caseSensitive: Bool,
        contextLines: Int
    ) async throws -> [SearchResult] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            return []
        }

        // Convert to string with proper encoding detection
        guard let content = String(data: data, encoding: .utf8) ??
                            String(data: data, encoding: .ascii) else {
            return []
        }

        var results: [SearchResult] = []
        let lines = content.components(separatedBy: .newlines)
        let searchPattern = caseSensitive ? pattern : pattern.lowercased()

        for (lineIndex, line) in lines.enumerated() {
            let searchLine = caseSensitive ? line : line.lowercased()

            if let range = searchLine.range(of: searchPattern) {
                let column = searchLine.distance(from: searchLine.startIndex, to: range.lowerBound) + 1

                // Get context
                let contextStart = max(0, lineIndex - contextLines)
                let contextEnd = min(lines.count - 1, lineIndex + contextLines)
                let context = lines[contextStart...contextEnd].joined(separator: "\n")

                let result = SearchResult(
                    filePath: filePath,
                    lineNumber: lineIndex + 1,
                    column: column,
                    matchedText: String(line[range]),
                    context: context
                )
                results.append(result)
            }
        }

        return results
    }

    // MARK: - Boyer-Moore Search (for future optimization)

    private class BoyerMoore {
        let pattern: [UInt8]
        let badCharSkip: [Int]
        let goodSuffixSkip: [Int]

        init(pattern: String) {
            self.pattern = Array(pattern.utf8)
            self.badCharSkip = BoyerMoore.buildBadCharSkip(pattern: self.pattern)
            self.goodSuffixSkip = BoyerMoore.buildGoodSuffixSkip(pattern: self.pattern)
        }

        func search(in text: [UInt8]) -> [Int] {
            var positions: [Int] = []
            let n = text.count
            let m = pattern.count

            var i = 0
            while i <= n - m {
                var j = m - 1
                while j >= 0 && pattern[j] == text[i + j] {
                    j -= 1
                }

                if j < 0 {
                    positions.append(i)
                    i += goodSuffixSkip[0]
                } else {
                    let skip = max(
                        goodSuffixSkip[j],
                        badCharSkip[Int(text[i + j])] - m + 1 + j
                    )
                    i += skip
                }
            }

            return positions
        }

        private static func buildBadCharSkip(pattern: [UInt8]) -> [Int] {
            var skip = [Int](repeating: pattern.count, count: 256)
            for (i, char) in pattern.dropLast().enumerated() {
                skip[Int(char)] = pattern.count - 1 - i
            }
            return skip
        }

        private static func buildGoodSuffixSkip(pattern: [UInt8]) -> [Int] {
            let m = pattern.count
            var skip = [Int](repeating: 0, count: m)
            var f = [Int](repeating: 0, count: m + 1)

            // Case 1
            var i = m
            var j = m + 1
            f[i] = j
            while i > 0 {
                while j <= m && pattern[i - 1] != pattern[j - 1] {
                    if skip[j - 1] == 0 {
                        skip[j - 1] = j - i
                    }
                    j = f[j]
                }
                i -= 1
                j -= 1
                f[i] = j
            }

            // Case 2
            j = f[0]
            for i in 0...m {
                if skip[i] == 0 {
                    skip[i] = j
                }
                if i == j {
                    j = f[j]
                }
            }

            return skip
        }
    }
}

// MARK: - Default Ignore Patterns

public extension AgSearchService {
    static var defaultIgnorePatterns: [String] {
        return [
            ".git/",
            ".build/",
            ".swiftpm/",
            "DerivedData/",
            "Pods/",
            "node_modules/",
            "*.xcworkspace",
            "*.xcodeproj",
            "*.DS_Store",
            "*.log"
        ]
    }
}

// MARK: - Swift-Specific Search Helpers

public extension AgSearchService {
    /// Search for Swift-specific patterns.
    func searchSwiftPatterns(
        in directory: String,
        patterns: [SwiftPattern],
        ignorePatterns: [String] = defaultIgnorePatterns
    ) async throws -> [SearchResult] {
        var allResults: [SearchResult] = []

        for pattern in patterns {
            let config = SearchConfig(
                pattern: pattern.rawValue,
                directory: directory,
                fileExtensions: ["swift"],
                ignorePatterns: ignorePatterns,
                caseSensitive: pattern.caseSensitive,
                contextLines: 2
            )

            let results = try await search(config: config)
            allResults.append(contentsOf: results)
        }

        return allResults
    }
}

/// Common Swift code patterns for search.
public enum SwiftPattern: String, Sendable {
    case classDeclaration = "class\\s+\\w+"
    case structDeclaration = "struct\\s+\\w+"
    case enumDeclaration = "enum\\s+\\w+"
    case protocolDeclaration = "protocol\\s+\\w+"
    case extensionDeclaration = "extension\\s+\\w+"
    case functionDeclaration = "func\\s+\\w+\\s*\\("
    case variableDeclaration = "(var|let)\\s+\\w+\\s*:"
    case typealiasDeclaration = "typealias\\s+\\w+"
    case importStatement = "^import\\s+\\w+"
    case sendableConformance = ":\\s*Sendable"
    case actorDeclaration = "actor\\s+\\w+"
    case asyncFunction = "func\\s+\\w+\\s*\\([^)]*\\)\\s*async"
    case awaitExpression = "await\\s+\\w+"
    case taskCreation = "Task\\s*\\{"

    var caseSensitive: Bool {
        switch self {
        case .sendableConformance, .actorDeclaration, .asyncFunction, .awaitExpression, .taskCreation:
            return false
        default:
            return true
        }
    }
}
