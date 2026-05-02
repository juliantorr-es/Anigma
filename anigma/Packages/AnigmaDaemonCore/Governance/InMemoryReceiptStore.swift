//
//  InMemoryReceiptStore.swift
//  AnigmaDaemonCore
//
//  In-memory receipt store for testing (bypasses vault database).
//

import ExecutionCore
import Foundation

/// In-memory receipt store for testing
public actor InMemoryReceiptStore: ReceiptStore {
    private var receipts: [String: ReceiptWire] = [:]

    public init() {}

    public nonisolated var storeID: String {
        return "in-memory-test-store"
    }

    public func store(receipt: ReceiptWire) async throws -> String {
        receipts[receipt.receiptID] = receipt
        return receipt.receiptID
    }

    public func retrieve(receiptID: String) async throws -> ReceiptWire? {
        return receipts[receiptID]
    }

    public func list(filter: ReceiptFilter?) async throws -> [ReceiptWire] {
        var results = Array(receipts.values)

        // Apply filter if provided
        if let filter = filter {
            results = results.filter { receipt in
                if let action = filter.actionName, receipt.actionName != action { return false }
                if let auth = filter.authority, receipt.authority != auth { return false }
                if let dec = filter.decision, receipt.decision != dec { return false }
                if let from = filter.fromTimestampMs, receipt.timestampMs < from { return false }
                if let to = filter.toTimestampMs, receipt.timestampMs > to { return false }
                return true
            }
        }

        return results
    }
}
