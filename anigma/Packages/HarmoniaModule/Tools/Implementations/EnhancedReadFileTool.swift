//
//  EnhancedReadFileTool.swift
//  HarmoniaModule
//
//  Enhanced read_file tool with caching, access logging, and trending.
//

import AnigmaPrimitives
import DatabaseCore
@preconcurrency import Foundation

/// Enhanced file read result
public struct EnhancedReadFileResult: Sendable, Codable {
    /// File content
    public let content: String

    /// File metadata
    public let metadata: FileMetadata

    /// Cache status
    public let cacheStatus: CacheStatus

    /// Access statistics
    public let stats: FileStatistics

    /// Recommendations
    public let recommendations: [String]

    public init(
        content: String,
        metadata: FileMetadata,
        cacheStatus: CacheStatus,
        stats: FileStatistics,
        recommendations: [String]
    ) {
        self.content = content
        self.metadata = metadata
        self.cacheStatus = cacheStatus
        self.stats = stats
        self.recommendations = recommendations
    }
}

/// File metadata
public struct FileMetadata: Sendable, Codable {
    public let path: String
    public let size: Int
    public let hash: String
    public let modificationTime: Date
    public let linesOfCode: Int
    public let fileType: String

    public init(
        path: String,
        size: Int,
        hash: String,
        modificationTime: Date,
        linesOfCode: Int,
        fileType: String
    ) {
        self.path = path
        self.size = size
        self.hash = hash
        self.modificationTime = modificationTime
        self.linesOfCode = linesOfCode
        self.fileType = fileType
    }
}

/// Cache status
public enum CacheStatus: String, Sendable, Codable {
    case hit = "hit"
    case miss = "miss"
    case updated = "updated"
    case invalidated = "invalidated"
}

/// File access statistics
public struct FileStatistics: Sendable, Codable {
    public let totalAccesses: Int
    public let lastAccessTime: Date
    public let accessFrequency: Double  // accesses per day
    public let averageAccessTime: TimeInterval
    public let isFrequentlyAccessed: Bool

    public init(
        totalAccesses: Int,
        lastAccessTime: Date,
        accessFrequency: Double,
        averageAccessTime: TimeInterval,
        isFrequentlyAccessed: Bool
    ) {
        self.totalAccesses = totalAccesses
        self.lastAccessTime = lastAccessTime
        self.accessFrequency = accessFrequency
        self.averageAccessTime = averageAccessTime
        self.isFrequentlyAccessed = isFrequentlyAccessed
    }
}

/// Enhanced read_file tool with caching and analytics
public actor EnhancedReadFileTool: ToolHandlerProtocol {
    private let cacheManager: FileCachingManager
    private let accessLogger: FileAccessLogger
    private let repoRoot: String
    private let dbActor: DatabaseActor?

    public init(
        repoRoot: String = FileManager.default.currentDirectoryPath,
        cacheManager: FileCachingManager? = nil,
        accessLogger: FileAccessLogger? = nil,
        dbActor: DatabaseActor? = nil
    ) {
        self.repoRoot = repoRoot
        self.dbActor = dbActor

        let _ = dbActor ?? DatabaseActor(dbPath: Self.defaultDatabasePath())
        self.cacheManager = cacheManager ?? FileCachingManager()
        self.accessLogger = accessLogger ?? FileAccessLogger()
    }

    /// Enhanced read file with caching
    public func readFile(
        path: String,
        useCache: Bool = true
    ) async throws -> EnhancedReadFileResult {
        let startTime = Date()

        // Validate path
        let validatedPath = try validatePath(path)
        let fileURL = URL(fileURLWithPath: validatedPath)

        // Check cache first
        var cacheStatus = CacheStatus.miss
        var content: String?

        if useCache {
            if let cached = await cacheManager.get(validatedPath) {
                content = cached.content
                cacheStatus = .hit
            }
        }

        // Read from disk if not cached
        if content == nil {
            content = try String(contentsOf: fileURL, encoding: .utf8)
            if useCache {
                try await cacheManager.cache(
                    filePath: validatedPath,
                    content: content!,
                    hash: computeHash(content!)
                )
            }
            cacheStatus = cacheStatus == .hit ? .updated : .miss
        }

        let duration = Date().timeIntervalSince(startTime)

        // Log access
        try await accessLogger.logAccess(
            filePath: validatedPath,
            size: content!.utf8.count,
            type: "read",
            duration: duration
        )

        // Get metadata
        let metadata = try getFileMetadata(fileURL, content: content!)

        // Get statistics
        let stats = try await accessLogger.getStats(filePath: validatedPath)
        let fileStats = FileStatistics(
            totalAccesses: stats.totalAccesses,
            lastAccessTime: stats.lastAccessTime,
            accessFrequency: stats.accessFrequency,
            averageAccessTime: stats.averageAccessTime,
            isFrequentlyAccessed: stats.accessFrequency > 10.0  // 10+ times per month
        )

        // Generate recommendations
        let recommendations = generateRecommendations(metadata: metadata, stats: fileStats)

        return EnhancedReadFileResult(
            content: content!,
            metadata: metadata,
            cacheStatus: cacheStatus,
            stats: fileStats,
            recommendations: recommendations
        )
    }

    /// Execute as ToolHandler
    public func handle(request: ToolRequest) async throws -> ToolResponse {
        let parameters = request.arguments

        guard let path = parameters["file_path"] ?? parameters["path"] else {
            return .failure("Missing required parameter: file_path")
        }

        let useCache = (parameters["cache"] ?? "true") == "true"

        do {
            let result = try await readFile(path: path, useCache: useCache)

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let resultData = try encoder.encode(result)
            let resultString = String(data: resultData, encoding: .utf8) ?? "{}"

            return .success(resultString)
        } catch {
            return .failure("Failed to read file: \(error.localizedDescription)")
        }
    }

    /// Validate and resolve file path
    private func validatePath(_ path: String) throws -> String {
        // Prevent directory traversal
        if path.contains("..") {
            throw NSError(domain: "FileAccess", code: 1, userInfo: [NSLocalizedDescriptionKey: "Path traversal not allowed"])
        }

        let filePath = path.hasPrefix("/") ? path : "\(repoRoot)/\(path)"
        let resolvedPath = (filePath as NSString).standardizingPath

        // Ensure file is within repo root
        guard resolvedPath.hasPrefix(repoRoot) else {
            throw NSError(domain: "FileAccess", code: 2, userInfo: [NSLocalizedDescriptionKey: "File outside repo root"])
        }

        return resolvedPath
    }

    /// Get file metadata
    private func getFileMetadata(_ fileURL: URL, content: String) throws -> FileMetadata {
        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        let size = attributes[.size] as? Int ?? 0
        let modTime = attributes[.modificationDate] as? Date ?? Date()
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).count
        let fileType = fileURL.pathExtension.isEmpty ? "unknown" : fileURL.pathExtension

        return FileMetadata(
            path: fileURL.path,
            size: size,
            hash: computeHash(content),
            modificationTime: modTime,
            linesOfCode: lines,
            fileType: fileType
        )
    }

    /// Compute file hash
    private func computeHash(_ content: String) -> String {
        ContentHashing.computeSHA256(content)
    }

    /// Generate recommendations
    private func generateRecommendations(
        metadata: FileMetadata,
        stats: FileStatistics
    ) -> [String] {
        var recommendations: [String] = []

        // Large file recommendation
        if metadata.size > 100_000 {
            recommendations.append("Large file (\(metadata.size / 1000)KB) - consider splitting")
        }

        // Frequently accessed recommendation
        if stats.isFrequentlyAccessed {
            recommendations.append("Frequently accessed - consider caching in memory")
        }

        // Long file recommendation
        if metadata.linesOfCode > 1000 {
            recommendations.append("Long file (\(metadata.linesOfCode) lines) - consider refactoring")
        }

        return recommendations
    }

    /// Get default database path
    private static func defaultDatabasePath() -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory())

        let anigmaDir = appSupport.appendingPathComponent("Anigma")
        try? FileManager.default.createDirectory(at: anigmaDir, withIntermediateDirectories: true)

        return anigmaDir.appendingPathComponent("files.sqlite").path
    }
}
