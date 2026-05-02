//
//  VaultReceiptWriter.swift
//  StorageCore
//
//  Vault receipt persistence for audit and debugging.
//

import Foundation

/// File-backed receipt writer that appends JSONL entries under the vault ledger.
public final class VaultFileReceiptWriter: VaultReceiptWriter, @unchecked Sendable {
    private let ledgerURL: URL
    private let encoder: JSONEncoder
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.ledgerURL =
            rootURL
            .appendingPathComponent("ledger", isDirectory: true)
            .appendingPathComponent("vault_receipts.jsonl", isDirectory: false)
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func write(_ receipt: VaultReceipt) async throws -> String {
        let data = try encoder.encode(receipt)
        var line = data
        line.append(0x0A)
        let directory = ledgerURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        if fileManager.fileExists(atPath: ledgerURL.path) {
            if let handle = try? FileHandle(forWritingTo: ledgerURL) {
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: line)
                return "vault_receipts.jsonl"
            }
        }
        try line.write(to: ledgerURL, options: .atomic)
        return "vault_receipts.jsonl"
    }
}
