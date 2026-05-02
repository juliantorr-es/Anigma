import Foundation
import CapsuleCore
import TelemetryCore

public enum DiffOpType: Int32, Codable, Hashable, Sendable {
    case equal = 0
    case delete = 1
    case insert = 2
    case replace = 3
}

public struct DiffOp: Codable, Hashable, Sendable {
    public var opType: DiffOpType
    public var text: String
    public var originalLine: Int
    public var modifiedLine: Int

    public init(opType: DiffOpType, text: String, originalLine: Int, modifiedLine: Int) {
        self.opType = opType
        self.text = text
        self.originalLine = originalLine
        self.modifiedLine = modifiedLine
    }
}

public struct DocumentVersion: Codable, Hashable, Sendable {
    public var docID: String
    public var content: String
    public var timestamp: UInt64
    public var author: String?
    public var message: String?

    public init(
        content: String,
        docID: String = UUID().uuidString,
        timestamp: UInt64 = 0,
        author: String? = nil,
        message: String? = nil
    ) {
        self.docID = docID
        self.content = content
        self.timestamp = timestamp
        self.author = author
        self.message = message
    }

    public init(
        docID: String,
        content: String,
        timestamp: UInt64 = 0,
        author: String? = nil,
        message: String? = nil
    ) {
        self.init(content: content, docID: docID, timestamp: timestamp, author: author, message: message)
    }
}

public struct DocumentDiffResult: Codable, Hashable, Sendable {
    public var operations: [DiffOp]
    public var original: DocumentVersion
    public var modified: DocumentVersion
    public var similarity: Float
    public var processingTime: UInt64

    public var processingTimeUs: UInt64 {
        processingTime
    }

    public init(
        operations: [DiffOp],
        original: DocumentVersion,
        modified: DocumentVersion,
        similarity: Float = 1.0,
        processingTime: UInt64 = 0
    ) {
        self.operations = operations
        self.original = original
        self.modified = modified
        self.similarity = similarity
        self.processingTime = processingTime
    }

    public init(
        operations: [DiffOp],
        original: DocumentVersion,
        modified: DocumentVersion,
        similarity: Float = 1.0,
        processingTimeUs: UInt64
    ) {
        self.init(
            operations: operations,
            original: original,
            modified: modified,
            similarity: similarity,
            processingTime: processingTimeUs
        )
    }
}

public struct DiffConfig: Codable, Hashable, Sendable {
    public var enableLineDiff: Bool = true
    public var enableWordDiff: Bool = false
    public var enableCharDiff: Bool = false
    public var ignoreWhitespace: Bool = false
    public var ignoreCase: Bool = false
    public var contextLines: Int = 3

    public static var `default`: DiffConfig {
        DiffConfig()
    }

    public init() {}
}

public actor DiffCapsule: IdentifiableCapsule {
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "diff-stub-v1"

    public init(
        config: DiffConfig = .default,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        self.diagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        _ = config
    }

    public func computeDiff(original: String, modified: String) throws -> DocumentDiffResult {
        let similarity: Float = (original == modified) ? 1.0 : 0.0
        let operations: [DiffOp] = (original == modified) ? [
            DiffOp(opType: .equal, text: original, originalLine: 0, modifiedLine: 0)
        ] : []

        diagnostics.event(
            level: .debug,
            category: "diff.stub.compute",
            message: "Diff stub produced simplified result",
            correlationID: nil,
            metadata: [
                "original_length": "\(original.count)",
                "modified_length": "\(modified.count)",
                "algorithm_version": Self.algorithmVersion
            ]
        )

        return DocumentDiffResult(
            operations: operations,
            original: DocumentVersion(content: original),
            modified: DocumentVersion(content: modified),
            similarity: similarity,
            processingTime: 0
        )
    }

    public func compute(original: String, modified: String) throws -> DocumentDiffResult {
        try computeDiff(original: original, modified: modified)
    }

    public func compute(original: DocumentVersion, modified: DocumentVersion) throws -> DocumentDiffResult {
        try computeDiff(original: original.content, modified: modified.content)
    }

    public func exportToUnified(result: DocumentDiffResult) throws -> String {
        let header = "--- \(result.original.docID)\n+++ \(result.modified.docID)"
        var lines: [String] = [header]
        lines.append(contentsOf: result.operations.map { op in
            switch op.opType {
            case .equal:
                return " \(op.text)"
            case .delete:
                return "-\(op.text)"
            case .insert:
                return "+\(op.text)"
            case .replace:
                return "~\(op.text)"
            }
        })
        return lines.joined(separator: "\n")
    }

    public func exportToJSON(result: DocumentDiffResult) throws -> String {
        let data = try JSONEncoder().encode(result)
        return String(decoding: data, as: UTF8.self)
    }
}
