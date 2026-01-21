//
//  CLIReceiptManager.swift
//  AnigmaCLIDatabase
//
//  Cryptographic receipt generation and verification for audit trails.
//  Generates receipts for all CLI operations with request/response hashes.
//

import Foundation
import CryptoKit

/// Receipt manager for generating and verifying cryptographic receipts.
public actor CLIReceiptManager {
    private let db: CLIDatabaseActor

    public init(database: CLIDatabaseActor) {
        self.db = database
    }

    // MARK: - Receipt Generation

    /// Generate a receipt for a run start.
    public func recordRunStart(
        runID: String,
        taskSummary: String,
        mode: String,
        dryRun: Bool
    ) async throws -> Receipt {
        let receiptID = UUID().uuidString
        let now = Date().timeIntervalSince1970

        let metadata: [String: String] = [
            "task_summary": taskSummary,
            "mode": mode,
            "dry_run": String(dryRun)
        ]

        try await storeReceipt(
            receiptID: receiptID,
            runID: runID,
            stepID: nil,
            type: .runStart,
            requestHash: hash(taskSummary),
            responseHash: nil,
            metadata: metadata,
            timestamp: now
        )

        return Receipt(
            receiptID: receiptID,
            runID: runID,
            stepID: nil,
            type: .runStart,
            requestHash: hash(taskSummary),
            responseHash: nil,
            metadata: metadata,
            timestamp: now
        )
    }

    /// Generate a receipt for a run completion.
    public func recordRunComplete(
        runID: String,
        status: String,
        message: String
    ) async throws -> Receipt {
        let receiptID = UUID().uuidString
        let now = Date().timeIntervalSince1970

        let metadata: [String: String] = [
            "status": status,
            "message": message
        ]

        try await storeReceipt(
            receiptID: receiptID,
            runID: runID,
            stepID: nil,
            type: .runComplete,
            requestHash: nil,
            responseHash: hash(message),
            metadata: metadata,
            timestamp: now
        )

        return Receipt(
            receiptID: receiptID,
            runID: runID,
            stepID: nil,
            type: .runComplete,
            requestHash: nil,
            responseHash: hash(message),
            metadata: metadata,
            timestamp: now
        )
    }

    /// Generate a receipt for a step execution.
    public func recordStep(
        runID: String,
        stepID: String,
        actionType: String,
        request: String,
        response: String
    ) async throws -> Receipt {
        let receiptID = UUID().uuidString
        let now = Date().timeIntervalSince1970

        let metadata: [String: String] = [
            "action_type": actionType
        ]

        try await storeReceipt(
            receiptID: receiptID,
            runID: runID,
            stepID: stepID,
            type: .stepExecution,
            requestHash: hash(request),
            responseHash: hash(response),
            metadata: metadata,
            timestamp: now
        )

        return Receipt(
            receiptID: receiptID,
            runID: runID,
            stepID: stepID,
            type: .stepExecution,
            requestHash: hash(request),
            responseHash: hash(response),
            metadata: metadata,
            timestamp: now
        )
    }

    /// Generate a receipt for a tool call.
    public func recordToolCall(
        runID: String,
        stepID: String?,
        toolName: String,
        request: String,
        response: String,
        approved: Bool
    ) async throws -> Receipt {
        let receiptID = UUID().uuidString
        let now = Date().timeIntervalSince1970

        let metadata: [String: String] = [
            "tool_name": toolName,
            "approved": String(approved)
        ]

        try await storeReceipt(
            receiptID: receiptID,
            runID: runID,
            stepID: stepID,
            type: .toolCall,
            requestHash: hash(request),
            responseHash: hash(response),
            metadata: metadata,
            timestamp: now
        )

        return Receipt(
            receiptID: receiptID,
            runID: runID,
            stepID: stepID,
            type: .toolCall,
            requestHash: hash(request),
            responseHash: hash(response),
            metadata: metadata,
            timestamp: now
        )
    }

    /// Generate a receipt for a retrieval operation.
    public func recordRetrieval(
        runID: String,
        query: String,
        resultCount: Int,
        mode: String,
        chunkHashes: [String]
    ) async throws -> Receipt {
        let receiptID = UUID().uuidString
        let now = Date().timeIntervalSince1970

        let metadata: [String: String] = [
            "mode": mode,
            "result_count": String(resultCount),
            "chunk_hashes": chunkHashes.joined(separator: ",")
        ]

        try await storeReceipt(
            receiptID: receiptID,
            runID: runID,
            stepID: nil,
            type: .retrieval,
            requestHash: hash(query),
            responseHash: hash(chunkHashes.joined()),
            metadata: metadata,
            timestamp: now
        )

        return Receipt(
            receiptID: receiptID,
            runID: runID,
            stepID: nil,
            type: .retrieval,
            requestHash: hash(query),
            responseHash: hash(chunkHashes.joined()),
            metadata: metadata,
            timestamp: now
        )
    }

    /// Generate a receipt for an index operation.
    public func recordIndexing(
        runID: String?,
        repoRoot: String,
        commit: String,
        chunksCreated: Int,
        chunksReused: Int
    ) async throws -> Receipt {
        let receiptID = UUID().uuidString
        let now = Date().timeIntervalSince1970
        let effectiveRunID = runID ?? "standalone-index"

        let metadata: [String: String] = [
            "repo_root": repoRoot,
            "commit": commit,
            "chunks_created": String(chunksCreated),
            "chunks_reused": String(chunksReused)
        ]

        try await storeReceipt(
            receiptID: receiptID,
            runID: effectiveRunID,
            stepID: nil,
            type: .indexing,
            requestHash: hash(repoRoot + commit),
            responseHash: hash("\(chunksCreated)-\(chunksReused)"),
            metadata: metadata,
            timestamp: now
        )

        return Receipt(
            receiptID: receiptID,
            runID: effectiveRunID,
            stepID: nil,
            type: .indexing,
            requestHash: hash(repoRoot + commit),
            responseHash: hash("\(chunksCreated)-\(chunksReused)"),
            metadata: metadata,
            timestamp: now
        )
    }

    /// Generate a receipt for a worktree operation.
    public func recordWorktreeOperation(
        runID: String?,
        operation: String,
        path: String,
        success: Bool
    ) async throws -> Receipt {
        let receiptID = UUID().uuidString
        let now = Date().timeIntervalSince1970
        let effectiveRunID = runID ?? "standalone-worktree"

        let metadata: [String: String] = [
            "operation": operation,
            "path": path,
            "success": String(success)
        ]

        try await storeReceipt(
            receiptID: receiptID,
            runID: effectiveRunID,
            stepID: nil,
            type: .worktree,
            requestHash: hash(operation + path),
            responseHash: hash(String(success)),
            metadata: metadata,
            timestamp: now
        )

        return Receipt(
            receiptID: receiptID,
            runID: effectiveRunID,
            stepID: nil,
            type: .worktree,
            requestHash: hash(operation + path),
            responseHash: hash(String(success)),
            metadata: metadata,
            timestamp: now
        )
    }

    // MARK: - Receipt Retrieval

    /// List receipts for a run.
    public func listReceipts(runID: String) async throws -> [Receipt] {
        let rows = try await db.query("""
            SELECT * FROM receipts
            WHERE run_id = ?
            ORDER BY created_at ASC
            """, parameters: [.text(runID)])

        return try rows.map { try decodeReceipt($0) }
    }

    /// Get a specific receipt.
    public func getReceipt(receiptID: String) async throws -> Receipt? {
        let rows = try await db.query("""
            SELECT * FROM receipts WHERE receipt_id = ?
            """, parameters: [.text(receiptID)])

        guard let row = rows.first else { return nil }
        return try decodeReceipt(row)
    }

    /// Verify receipt chain integrity for a run.
    public func verifyChain(runID: String) async throws -> ChainVerification {
        let receipts = try await listReceipts(runID: runID)

        guard !receipts.isEmpty else {
            return ChainVerification(valid: true, receiptCount: 0, errors: [])
        }

        var errors: [String] = []

        // Verify hashes are present
        for receipt in receipts {
            if receipt.type != .runComplete, receipt.requestHash == nil {
                errors.append("Receipt \(receipt.receiptID): missing request hash")
            }
        }

        // Verify chronological order
        for i in 1..<receipts.count {
            if receipts[i].timestamp < receipts[i - 1].timestamp {
                errors.append("Receipt \(receipts[i].receiptID): timestamp out of order")
            }
        }

        return ChainVerification(
            valid: errors.isEmpty,
            receiptCount: receipts.count,
            errors: errors
        )
    }

    // MARK: - Internal Helpers

    internal func storeReceipt(
        receiptID: String,
        runID: String,
        stepID: String?,
        type: ReceiptType,
        requestHash: String?,
        responseHash: String?,
        metadata: [String: String],
        timestamp: TimeInterval
    ) async throws {
        let metadataJSON = try JSONSerialization.data(withJSONObject: metadata)
        let metadataString = String(data: metadataJSON, encoding: .utf8) ?? "{}"

        _ = try await db.execute("""
            INSERT INTO receipts (
                receipt_id, run_id, step_id, receipt_type,
                request_hash, response_hash, tool_metadata, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """, parameters: [
                .text(receiptID),
                .text(runID),
                stepID.map { .text($0) } ?? .null,
                .text(type.rawValue),
                requestHash.map { .text($0) } ?? .null,
                responseHash.map { .text($0) } ?? .null,
                .text(metadataString),
                .double(timestamp)
            ])
    }

    private func decodeReceipt(_ row: CLIRow) throws -> Receipt {
        guard let receiptID = row["receipt_id"]?.asString,
              let runID = row["run_id"]?.asString,
              let typeStr = row["receipt_type"]?.asString,
              let timestamp = row["created_at"]?.asDouble else {
            throw ReceiptError.invalidReceiptData
        }

        guard let type = ReceiptType(rawValue: typeStr) else {
            throw ReceiptError.invalidReceiptType(typeStr)
        }

        var metadata: [String: String] = [:]
        if let metadataStr = row["tool_metadata"]?.asString,
           let data = metadataStr.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            metadata = dict
        }

        return Receipt(
            receiptID: receiptID,
            runID: runID,
            stepID: row["step_id"]?.asString,
            type: type,
            requestHash: row["request_hash"]?.asString,
            responseHash: row["response_hash"]?.asString,
            metadata: metadata,
            timestamp: timestamp
        )
    }

    public func hash(_ content: String) -> String {
        let data = Data(content.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Supporting Types

public struct Receipt: Sendable {
    public let receiptID: String
    public let runID: String
    public let stepID: String?
    public let type: ReceiptType
    public let requestHash: String?
    public let responseHash: String?
    public let metadata: [String: String]
    public let timestamp: TimeInterval
}

public enum ReceiptType: String, Sendable {
    case runStart = "run_start"
    case runComplete = "run_complete"
    case stepExecution = "step_execution"
    case toolCall = "tool_call"
    case retrieval = "retrieval"
    case indexing = "indexing"
    case worktree = "worktree"
    case policyCheck = "policy_check"
    case loopBreaker = "loop_breaker"
}

public struct ChainVerification: Sendable {
    public let valid: Bool
    public let receiptCount: Int
    public let errors: [String]
}

public enum ReceiptError: Error, Sendable {
    case invalidReceiptData
    case invalidReceiptType(String)
}