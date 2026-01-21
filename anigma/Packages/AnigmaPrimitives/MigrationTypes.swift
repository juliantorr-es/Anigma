//
//  MigrationTypes.swift
//  AnigmaPrimitives
//
//  [Brief description of file purpose]
//

import Foundation

/// Describes a migration task that travels through the pipeline.
public struct MigrationTaskRow: Sendable, Codable {
    public let id: String
    public let originalTaskId: String?
    public let engineType: String
    public let featureCategory: String
    public let filePath: String?
    public let fileHash: String?
    public let fileModificationDate: Date?
    public let status: String
    public let createdAt: Date?
    public let startedAt: Date?
    public let completedAt: Date?
    public let errorMessage: String?
    public let priority: Int
    public let metadata: [String: String]?
    public let trustTier: String?
    public let projectId: UUID?
    public let findingId: String?
    public let researchBundleId: String?
    public let path: String?
    public let pathDetail: String?

    public init(
        id: String,
        originalTaskId: String? = nil,
        engineType: String,
        featureCategory: String,
        filePath: String? = nil,
        fileHash: String? = nil,
        fileModificationDate: Date? = nil,
        status: String,
        createdAt: Date? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        errorMessage: String? = nil,
        priority: Int,
        metadata: [String: String]? = nil,
        trustTier: String? = nil,
        projectId: UUID? = nil,
        findingId: String? = nil,
        researchBundleId: String? = nil,
        path: String? = nil,
        pathDetail: String? = nil
    ) {
        self.id = id
        self.originalTaskId = originalTaskId
        self.engineType = engineType
        self.featureCategory = featureCategory
        self.filePath = filePath
        self.fileHash = fileHash
        self.fileModificationDate = fileModificationDate
        self.status = status
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.errorMessage = errorMessage
        self.priority = priority
        self.metadata = metadata
        self.trustTier = trustTier
        self.projectId = projectId
        self.findingId = findingId
        self.researchBundleId = researchBundleId
        self.path = path
        self.pathDetail = pathDetail
    }
}

/// Result of processing a migration task in the pipeline.
public enum MigrationResult: Sendable {
    case success(String? = nil, String? = nil)
    case skipped(String? = nil, String, String? = nil)
    case failed(String, String? = nil, String? = nil)

    public var path: String? {
        switch self {
        case let .success(path, _),
             let .skipped(path, _, _),
             let .failed(_, path, _):
            return path
        }
    }

    public var detail: String? {
        switch self {
        case let .success(_, detail),
             let .skipped(_, _, detail),
             let .failed(_, _, detail):
            return detail
        }
    }

    public static var defaultSuccess: MigrationResult {
        .success(nil, nil)
    }

    public static func skipped(
        reason: String,
        path: String? = nil,
        detail: String? = nil
    ) -> MigrationResult {
        .skipped(path, reason, detail)
    }

    public static func failed(
        errorDescription: String,
        path: String? = nil,
        detail: String? = nil
    ) -> MigrationResult {
        .failed(errorDescription, path, detail)
    }
}

public extension UUID {
    /// Hex string with no delimiters (lowercased).
    var hexString: String {
        uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    /// Initialize from hex string (with or without hyphens).
    init?(hexString: String) {
        let sanitized = hexString.replacingOccurrences(of: "-", with: "")
        guard sanitized.count == 32,
              let formatted = UUIDFormatter.format(sanitized) else {
            return nil
        }
        self.init(uuidString: formatted)
    }

    /// Data form suitable for SQLite BLOB binding.
    var asBlobData: Data {
        withUnsafeBytes(of: self) { Data($0) }
    }
}

private enum UUIDFormatter {
    static func format(_ digits: String) -> String? {
        guard digits.count == 32 else { return nil }
        let ranges = [
            digits.startIndex..<digits.index(digits.startIndex, offsetBy: 8),
            digits.index(digits.startIndex, offsetBy: 8)..<digits.index(digits.startIndex, offsetBy: 12),
            digits.index(digits.startIndex, offsetBy: 12)..<digits.index(digits.startIndex, offsetBy: 16),
            digits.index(digits.startIndex, offsetBy: 16)..<digits.index(digits.startIndex, offsetBy: 20),
            digits.index(digits.startIndex, offsetBy: 20)..<digits.endIndex
        ]
        let components = ranges.map { String(digits[$0]) }
        return components.joined(separator: "-")
    }
}
