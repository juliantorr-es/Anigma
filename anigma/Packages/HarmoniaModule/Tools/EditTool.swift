//
//  EditTool.swift
//  HarmoniaModule
//
//  Edit tool with strict contract and loop prevention.
//  Replaces string-based editing with proof-of-delta requirements.
//

@preconcurrency import Foundation
@preconcurrency import CryptoKit

/// Edit tool request with strict validation.
public struct EditToolRequest: Sendable, Codable {
    public let filePath: String
    public let strategy: EditStrategy
    public let preconditionHash: String

    public init(filePath: String, strategy: EditStrategy, preconditionHash: String) {
        self.filePath = filePath
        self.strategy = strategy
        self.preconditionHash = preconditionHash
    }
}

/// Edit strategy with proof-of-delta requirements.
public enum EditStrategy: Sendable, Codable {
    case unifiedDiff(diff: String)  // Git-style unified diff
    case byteRangePatch(start: Int, end: Int, replacement: Data)
    case exactStringMatch(old: String, new: String)  // Current approach with validation

    public var description: String {
        switch self {
        case .unifiedDiff:
            return "Unified diff"
        case .byteRangePatch:
            return "Byte-range patch"
        case .exactStringMatch:
            return "Exact string match"
        }
    }
}

/// Edit tool response with change tracking.
public struct EditToolResponse: Sendable, Codable {
    public let success: Bool
    public let actualChanges: Int
    public let newFileHash: String
    public let appliedDiff: String?
    public let changes: [FileChange]

    public init(
        success: Bool,
        actualChanges: Int = 0,
        newFileHash: String,
        appliedDiff: String? = nil,
        changes: [FileChange] = []
    ) {
        self.success = success
        self.actualChanges = actualChanges
        self.newFileHash = newFileHash
        self.appliedDiff = appliedDiff
        self.changes = changes
    }
}

/// Individual file change for tracking.
public struct FileChange: Sendable, Codable {
    public let type: ChangeType
    public let startOffset: Int
    public let endOffset: Int
    public let oldContent: String?
    public let newContent: String?

    public init(
        type: ChangeType,
        startOffset: Int,
        endOffset: Int,
        oldContent: String? = nil,
        newContent: String? = nil
    ) {
        self.type = type
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.oldContent = oldContent
        self.newContent = newContent
    }
}

/// Type of file change.
public enum ChangeType: String, Sendable, Codable {
    case insert = "insert"
    case delete = "delete"
    case replace = "replace"
    case modify = "modify"
}

/// Edit tool implementation with strict validation.
public actor EditTool {

    /// Perform edit with strategy-based execution.
    public func performEdit(_ request: EditToolRequest) async throws -> EditToolResponse {
        // Validate precondition hash
        let currentContent = try String(contentsOfFile: request.filePath)
        let currentHash = sha256Hex(currentContent)

        guard currentHash == request.preconditionHash else {
            throw EditError.preconditionFailed(
                "File content changed since read. Expected: \(request.preconditionHash), Actual: \(currentHash)"
            )
        }

        // Execute edit based on strategy
        let result = try await executeStrategy(request.strategy, on: currentContent, file: request.filePath)

        // Validate edit actually changed content
        let newContent = try String(contentsOfFile: request.filePath)
        let newHash = sha256Hex(newContent)

        if currentHash == newHash {
            throw EditError.noOpEdit("Edit did not change file content")
        }

        return EditToolResponse(
            success: true,
            actualChanges: result.changes.count,
            newFileHash: newHash,
            appliedDiff: result.appliedDiff,
            changes: result.changes
        )
    }

    /// Execute edit based on strategy.
    private func executeStrategy(
        _ strategy: EditStrategy,
        on content: String,
        file: String
    ) async throws -> EditResult {

        switch strategy {
        case .unifiedDiff(let diff):
            return try applyUnifiedDiff(diff, to: content, file: file)

        case .byteRangePatch(let start, let end, let replacement):
            return try applyByteRangePatch(start: start, end: end, replacement: replacement, to: content, file: file)

        case .exactStringMatch(let oldString, let newString):
            return try applyExactStringMatch(old: oldString, new: newString, to: content, file: file)
        }
    }

    /// Apply unified diff to content.
    private func applyUnifiedDiff(_ diff: String, to content: String, file: String) throws -> EditResult {
        // Simple unified diff parser for now
        let lines = diff.components(separatedBy: .newlines)
        var modifiedContent = content
        var changes: [FileChange] = []

        for line in lines {
            if line.hasPrefix("@@") {
                // Hunk header - parse context
                continue
            } else if line.hasPrefix("-") {
                // Removal line
                let removalContent = String(line.dropFirst())
                if let range = modifiedContent.range(of: removalContent) {
                    changes.append(FileChange(
                        type: .delete,
                        startOffset: modifiedContent.distance(from: modifiedContent.startIndex, to: range.lowerBound),
                        endOffset: modifiedContent.distance(from: modifiedContent.startIndex, to: range.upperBound),
                        oldContent: removalContent
                    ))
                    modifiedContent.removeSubrange(range)
                }
            } else if line.hasPrefix("+") {
                // Addition line
                let additionContent = String(line.dropFirst())
                // For simplicity, append at end - real implementation would handle context
                changes.append(FileChange(
                    type: .insert,
                    startOffset: modifiedContent.count,
                    endOffset: modifiedContent.count,
                    newContent: additionContent
                ))
                modifiedContent += additionContent + "\n"
            }
        }

        // Write modified content
        try modifiedContent.write(toFile: file, atomically: true, encoding: .utf8)

        return EditResult(
            changes: changes,
            appliedDiff: diff
        )
    }

    /// Apply byte-range patch to content.
    private func applyByteRangePatch(
        start: Int,
        end: Int,
        replacement: Data,
        to content: String,
        file: String
    ) throws -> EditResult {

        let contentData = content.data(using: .utf8) ?? Data()
        guard start >= 0, end <= contentData.count, start <= end else {
            throw EditError.invalidRange("Byte range \(start)-\(end) invalid for content of size \(contentData.count)")
        }

        // Apply patch
        var modifiedData = contentData
        modifiedData.replaceSubrange(start..<end, with: replacement)

        let modifiedContent = String(data: modifiedData, encoding: .utf8) ?? ""

        // Write modified content
        try modifiedContent.write(toFile: file, atomically: true, encoding: .utf8)

        let change = FileChange(
            type: .replace,
            startOffset: start,
            endOffset: end,
            oldContent: String(data: contentData[start..<end], encoding: .utf8),
            newContent: String(data: replacement, encoding: .utf8)
        )

        return EditResult(
            changes: [change],
            appliedDiff: "Byte-range patch: \(start)-\(end) -> \(replacement.count) bytes"
        )
    }

    /// Apply exact string match edit.
    private func applyExactStringMatch(
        old: String,
        new: String,
        to content: String,
        file: String
    ) throws -> EditResult {

        // Detect no-op edit immediately
        if old == new {
            throw EditError.noOpEdit("oldString and newString must be different")
        }

        guard let range = content.range(of: old) else {
            throw EditError.stringNotFound("oldString '\(old)' not found in file")
        }

        let startOffset = content.distance(from: content.startIndex, to: range.lowerBound)
        let endOffset = content.distance(from: content.startIndex, to: range.upperBound)

        var modifiedContent = content
        modifiedContent.replaceSubrange(range, with: new)

        // Write modified content
        try modifiedContent.write(toFile: file, atomically: true, encoding: .utf8)

        let change = FileChange(
            type: .replace,
            startOffset: startOffset,
            endOffset: endOffset,
            oldContent: old,
            newContent: new
        )

        return EditResult(
            changes: [change],
            appliedDiff: "String replacement: '\(old)' -> '\(new)'"
        )
    }

    /// Compute SHA256 hash of content.
    private func sha256Hex(_ content: String) -> String {
        let data = Data(content.utf8)
        let hash = CryptoKit.SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Supporting Types

/// Result of edit operation.
private struct EditResult {
    let changes: [FileChange]
    let appliedDiff: String
}

/// Edit-specific errors.
public enum EditError: Error, LocalizedError {
    case preconditionFailed(String)
    case noOpEdit(String)
    case stringNotFound(String)
    case invalidRange(String)
    case fileReadError(String)
    case fileWriteError(String)

    public var errorDescription: String? {
        switch self {
        case .preconditionFailed(let message):
            return "Precondition failed: \(message)"
        case .noOpEdit(let message):
            return "No-op edit: \(message)"
        case .stringNotFound(let message):
            return "String not found: \(message)"
        case .invalidRange(let message):
            return "Invalid range: \(message)"
        case .fileReadError(let message):
            return "File read error: \(message)"
        case .fileWriteError(let message):
            return "File write error: \(message)"
        }
    }
}
