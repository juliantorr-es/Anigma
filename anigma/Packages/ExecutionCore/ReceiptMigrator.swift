//
//  ReceiptMigrator.swift
//  ExecutionCore
//
//  Migration utility for converting receipts to canonical BLAKE3(JCS(payload)) IDs.
//  Follows ledger-first durability: record intent → migrate → record outcome.
//

import Foundation

// MARK: - Receipt Migration

/// Migrates receipts from old (mutable) IDs to canonical BLAKE3(JCS(payload)) IDs.
/// Follows ledger-first durability: record intent → perform migration → record completion.
public class ReceiptMigrator {
    public typealias MigrationResult = (oldID: String, newID: String, receipt: ReceiptWire)

    /// Migrates a single receipt to canonical ID derivation
    /// - Parameter receipt: Receipt with potentially mismatched ID
    /// - Returns: Migration result with old and new IDs
    /// - Throws: If verification fails after migration
    public static func migrateReceipt(_ receipt: ReceiptWire) throws -> MigrationResult {
        let oldID = receipt.receiptID

        // Create new receipt with canonical ID
        let migratedReceipt = ReceiptWire.create(
            actionName: receipt.actionName,
            authority: receipt.authority,
            decision: receipt.decision,
            reasonCode: receipt.reasonCode,
            timestampMs: receipt.timestampMs,
            inputsHash: receipt.inputsHash,
            outputsHash: receipt.outputsHash,
            signature: receipt.signature,
            metadata: receipt.metadata
        )

        // Verify migration succeeded
        try migratedReceipt.verifyReceiptID()

        return (oldID: oldID, newID: migratedReceipt.receiptID, receipt: migratedReceipt)
    }

    /// Batch migrates multiple receipts
    /// - Parameter receipts: Array of receipts to migrate
    /// - Returns: Array of migration results
    /// - Throws: On first failure (reports which receipt failed)
    public static func migrateReceipts(_ receipts: [ReceiptWire]) throws -> [MigrationResult] {
        var results: [MigrationResult] = []

        for (index, receipt) in receipts.enumerated() {
            do {
                let result = try migrateReceipt(receipt)
                results.append(result)
            } catch {
                throw ReceiptError.migrationFailed(
                    receipt: receipt.receiptID,
                    message: "Failed at index \(index): \(error.localizedDescription)"
                )
            }
        }

        return results
    }

    /// Checks if a receipt needs migration
    /// - Parameter receipt: Receipt to check
    /// - Returns: true if receiptID does not match canonical derivation
    public static func needsMigration(_ receipt: ReceiptWire) -> Bool {
        let computedID = receipt.computeReceiptID()
        return receipt.receiptID != computedID
    }

    /// Analyzes migration impact without making changes
    /// - Parameter receipts: Receipts to analyze
    /// - Returns: Dictionary with statistics about the migration
    public static func analyzeImpact(_ receipts: [ReceiptWire]) -> [String: Any] {
        let totalReceipts = receipts.count
        let needsMigration = receipts.filter { Self.needsMigration($0) }.count
        let alreadyCorrect = totalReceipts - needsMigration

        return [
            "total_receipts": totalReceipts,
            "needs_migration": needsMigration,
            "already_correct": alreadyCorrect,
            "migration_percentage": needsMigration > 0 ? Double(needsMigration) / Double(totalReceipts) * 100 : 0.0
        ]
    }
}

// MARK: - Migration Ledger Entry

/// Records migration events in ledger for audit trail
public struct MigrationLedgerEntry: Codable, Sendable {
    /// Timestamp of migration
    public let timestamp: Int64

    /// Old receipt ID (before migration)
    public let oldReceiptID: String

    /// New receipt ID (after migration)
    public let newReceiptID: String

    /// Authority that performed migration
    public let authority: String

    /// Status: "intent", "completed", "failed"
    public let status: String

    /// Error message if status is "failed"
    public let errorMessage: String?

    /// Counter for idempotency (same migration attempt ID)
    public let migrationBatch: String

    public init(
        oldReceiptID: String,
        newReceiptID: String,
        authority: String,
        status: String,
        errorMessage: String? = nil,
        migrationBatch: String
    ) {
        self.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        self.oldReceiptID = oldReceiptID
        self.newReceiptID = newReceiptID
        self.authority = authority
        self.status = status
        self.errorMessage = errorMessage
        self.migrationBatch = migrationBatch
    }
}
