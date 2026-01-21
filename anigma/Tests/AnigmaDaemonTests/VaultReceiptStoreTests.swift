import Foundation
import XCTest

import DatabaseCore
import StorageCore
import TelemetryCore

@testable import AnigmaDaemonCore
@testable import ExecutionCore

final class VaultReceiptStoreTests: XCTestCase {
    func testListSkipsCorruptReceipt() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("anigma-receipts-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let dbPath = tempRoot.appendingPathComponent("vault.db").path
        let dbActor = DatabaseActor(dbPath: dbPath)
        try await dbActor.open()
        let vault = try await VaultAuthority(
            rootURL: tempRoot,
            database: dbActor,
            keyProvider: InMemoryVaultKeyProvider()
        )
        let store = VaultReceiptStore(vault: vault)

        let valid = ReceiptWire.create(
            actionName: "test.valid",
            authority: "test",
            decision: .allowed,
            reasonCode: "OK",
            timestampMs: 1,
            inputsHash: TelemetryHash(input: "in"),
            outputsHash: nil,
            signature: nil,
            previousReceiptHash: nil,
            metadata: [:]
        )
        _ = try await store.store(receipt: valid)

        let corrupt = ReceiptWire(
            receiptID: "corrupt",
            actionName: "test.corrupt",
            authority: "test",
            decision: .allowed,
            reasonCode: "BAD",
            timestampMs: 2,
            inputsHash: TelemetryHash(input: "in"),
            outputsHash: nil,
            signature: nil,
            previousReceiptHash: nil,
            metadata: [:]
        )
        _ = try await store.store(receipt: corrupt)

        let listed = try await store.list(filter: nil)
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed.first?.receiptID, valid.receiptID)
    }
}
