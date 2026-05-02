//
//  PostgresBulkIngest.swift
//  DatabaseCore
//
//  PostgreSQL COPY FROM bulk ingest support.
//
//  See td-ad1f60: Implement COPY FROM bulk ingest
//

import Foundation

/// COPY format options
public enum CopyFormat: Sendable {
    case text
    case csv
    case binary
}

/// Configuration for COPY FROM operations
public struct CopyFromConfig: Sendable {
    public let table: String
    public let columns: [String]
    
    public init(table: String, columns: [String]) {
        self.table = table
        self.columns = columns
    }
    
    public func buildCopyCommand(from source: String, format: CopyFormat) -> String {
        "COPY " + table + " (" + columns.joined(separator: ", ") + ") FROM '" + source + "' WITH (FORMAT " + formatName(format) + ")"
    }
    
    private func formatName(_ format: CopyFormat) -> String {
        switch format {
        case .text: return "text"
        case .csv: return "csv"
        case .binary: return "binary"
        }
    }
}

/// Error types for COPY FROM operations
public enum CopyFromError: Error, CustomStringConvertible {
    case fileNotFound(url: URL)
    case copyCommandFailed(message: String)
    
    public var description: String {
        switch self {
        case let .fileNotFound(url): return "File not found: " + url.path
        case let .copyCommandFailed(msg): return "COPY failed: " + msg
        }
    }
}

/// Result of a bulk ingest operation
public struct BulkIngestResult: Sendable, Codable {
    public let rowCount: Int
    public let duration: TimeInterval
    public var rowsPerSecond: Double {
        guard duration > 0 else { return 0 }
        return Double(rowCount) / duration
    }
    
    public init(rowCount: Int, duration: TimeInterval) {
        self.rowCount = rowCount
        self.duration = duration
    }
}

/// Bulk ingest service using PostgreSQL COPY FROM
public struct PostgresBulkIngest: Sendable {
    private let database: any DatabaseExecutor
    
    public init(database: any DatabaseExecutor) {
        self.database = database
    }
    
    public func copyFromFile(
        config: CopyFromConfig,
        fileURL: URL,
        format: CopyFormat = .text
    ) async throws -> BulkIngestResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CopyFromError.fileNotFound(url: fileURL)
        }
        
        let cmd = config.buildCopyCommand(from: fileURL.path, format: format)
        let start = Date()
        let result = try await database.execute(cmd)
        let elapsed = Date().timeIntervalSince(start)
        
        return BulkIngestResult(
            rowCount: parseRowCount(from: result),
            duration: elapsed
        )
    }
    
    private func parseRowCount(from result: any Sendable) -> Int {
        if let intResult = result as? Int { return intResult }
        if let strResult = result as? String {
            return strResult.split(whereSeparator: \.isWhitespace).last.flatMap { Int($0) } ?? 0
        }
        return 0
    }
}
