//
//  VaultReceiptStore.swift
//  AnigmaDaemonCore
//

import ExecutionCore
import Foundation
import StorageCore

/// ReceiptStore implementation backed by VaultAuthority
public struct VaultReceiptStore: ReceiptStore {
    private let vault: VaultAuthority

    public init(vault: VaultAuthority) {
        self.vault = vault
    }

    public var storeID: String {
        return "storagecore-vault"
    }

    public func store(receipt: ReceiptWire) async throws -> String {
        let data = try receipt.deterministicJSON()
        let hash = receipt.receiptID
        let previousHash = receipt.previousReceiptHash

        let ref = try await vault.ingestReceipt(
            data: data,
            hash: hash,
            previousReceiptHash: previousHash
        )
        return ref.hashHex
    }

    public func retrieve(receiptID: String) async throws -> ReceiptWire? {
        do {
            let data = try await vault.open(hash: receiptID)
            let decoder = Foundation.JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            let receipt = try decoder.decode(ReceiptWire.self, from: data)
            try receipt.verifyReceiptID()
            return receipt
        } catch {
            return nil
        }
    }

    public func list(filter: ReceiptFilter?) async throws -> [ReceiptWire] {
        // Fetch all artifacts of type .receipt
        let artifacts = try await vault.listArtifacts()
        let receiptArtifacts = artifacts.filter { $0.kind == .receipt }

        var receipts: [ReceiptWire] = []
        let decoder = Foundation.JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        for art in receiptArtifacts {
            do {
                let data = try await vault.open(hash: art.hashHex)
                let receipt = try decoder.decode(ReceiptWire.self, from: data)
                try receipt.verifyReceiptID()

                // Apply filter
                if let filter = filter {
                    if let action = filter.actionName, receipt.actionName != action { continue }
                    if let auth = filter.authority, receipt.authority != auth { continue }
                    if let dec = filter.decision, receipt.decision != dec { continue }
                    if let from = filter.fromTimestampMs, receipt.timestampMs < from { continue }
                    if let to = filter.toTimestampMs, receipt.timestampMs > to { continue }
                }

                receipts.append(receipt)
            } catch {
                continue
            }
        }

        return receipts
    }
}
