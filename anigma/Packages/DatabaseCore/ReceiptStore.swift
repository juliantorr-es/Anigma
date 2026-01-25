//
//  ReceiptStore.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import ContractsCore
import Foundation

/// Persistence for contract receipts with idempotent inserts and lookup by session/contract/input key.
public actor ReceiptStore {
    private let db: any DatabaseExecutor
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(database: any DatabaseExecutor) async throws {
        self.db = database
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        try await MigrationRegistry.applyMigrations(using: db)
    }

    /// Inserts a receipt if not already present for the same session/contract/input/provenance tuple.
    /// Returns the canonical stored receipt (either the newly inserted receipt or the existing one).
    @discardableResult
    public func putReceiptIdempotent(_ receipt: ContractReceipt, inputKey: String) async throws -> ContractReceipt {
        let data = try encoder.encode(receipt)
        let inserted = try await db.executeAsync(
            """
            INSERT OR IGNORE INTO contract_receipts
            (run_id, session_id, contract_id, status, started_at, ended_at, provenance_hash, receipt_json, input_key)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(receipt.runID),
                .text(receipt.sessionID),
                .text(receipt.contractID.name),
                .text(receipt.status.rawValue),
                .double(receipt.startedAt.timeIntervalSince1970),
                .double(receipt.endedAt.timeIntervalSince1970),
                .text(receipt.provenanceHash),
                .blob(data),
                .text(inputKey)
            ]
        )

        if inserted > 0 {
            return receipt
        }

        if let stored = try await fetchSatisfiedReceipt(contractID: receipt.contractID, sessionID: receipt.sessionID, inputKey: inputKey) {
            return stored
        }
        if let byInput = try await fetchAnyReceipt(contractID: receipt.contractID, sessionID: receipt.sessionID, inputKey: inputKey) {
            return byInput
        }
        if let byRun = try await fetchReceipt(runID: receipt.runID) {
            return byRun
        }
        return receipt
    }

    /// Fetch all receipts for a session.
    public func fetchReceipts(sessionID: String) async throws -> [ContractReceipt] {
        let rows = try await db.query(
            """
            SELECT receipt_json FROM contract_receipts
            WHERE session_id = ?
            """,
            parameters: [.text(sessionID)]
        )
        return rows.compactMap { row in
            guard let data = row.data(for: "receipt_json") else { return nil }
            return try? decoder.decode(ContractReceipt.self, from: data)
        }
    }

    /// Fetch a satisfied receipt for a given contract + session + inputKey, if any.
    public func fetchSatisfiedReceipt(contractID: ContractID, sessionID: String, inputKey: String) async throws -> ContractReceipt? {
        let rows = try await db.query(
            """
            SELECT receipt_json FROM contract_receipts
            WHERE session_id = ? AND contract_id = ? AND input_key = ? AND status = ?
            LIMIT 1
            """,
            parameters: [
                .text(sessionID),
                .text(contractID.name),
                .text(inputKey),
                .text(ContractStatus.satisfied.rawValue)
            ]
        )
        guard let row = rows.first, let data = row.data(for: "receipt_json") else { return nil }
        return try decoder.decode(ContractReceipt.self, from: data)
    }

    /// Fetch a receipt by run identifier.
    public func fetchReceipt(runID: String) async throws -> ContractReceipt? {
        let rows = try await db.query(
            """
            SELECT receipt_json FROM contract_receipts
            WHERE run_id = ?
            LIMIT 1
            """,
            parameters: [.text(runID)]
        )
        guard let row = rows.first, let data = row.data(for: "receipt_json") else { return nil }
        return try decoder.decode(ContractReceipt.self, from: data)
    }

    /// Fetch any receipt for a contract + session + inputKey, regardless of status.
    public func fetchAnyReceipt(contractID: ContractID, sessionID: String, inputKey: String) async throws -> ContractReceipt? {
        let rows = try await db.query(
            """
            SELECT receipt_json FROM contract_receipts
            WHERE session_id = ? AND contract_id = ? AND input_key = ?
            LIMIT 1
            """,
            parameters: [
                .text(sessionID),
                .text(contractID.name),
                .text(inputKey)
            ]
        )
        guard let row = rows.first, let data = row.data(for: "receipt_json") else { return nil }
        return try decoder.decode(ContractReceipt.self, from: data)
    }
}
