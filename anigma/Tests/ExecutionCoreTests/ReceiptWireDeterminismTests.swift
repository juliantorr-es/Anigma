//
//  ReceiptWireDeterminismTests.swift
//  ExecutionCoreTests
//
//  Unit tests for ExecutionCoreTests.
//

import XCTest
import ExecutionCore
import TelemetryCore

class ReceiptWireDeterminismTests: XCTestCase {

    func testCanonicalReceiptIDDerivation() throws {
        // Create receipt with ReceiptWire.create()
        let receipt = ReceiptWire.create(
            actionName: "testAction",
            authority: "test-authority",
            decision: .allowed,
            reasonCode: "test_code",
            timestampMs: 1234567890,
            inputsHash: TelemetryHash(input: "test-input"),
            outputsHash: TelemetryHash(input: "test-output"),
            signature: "signature-data",
            metadata: ["key": .hashedToken(TelemetryHash(input: "value"))]
        )

        // Verify receiptID is computed
        XCTAssertFalse(receipt.receiptID.isEmpty)

        // Verify receiptID matches deterministic derivation
        XCTAssertNoThrow(try receipt.verifyReceiptID())
    }

    func testReceiptIDDeterminism() throws {
        // Create same receipt twice
        let receipt1 = ReceiptWire.create(
            actionName: "testAction",
            authority: "test-authority",
            decision: .allowed,
            reasonCode: "test_code",
            timestampMs: 1234567890,
            inputsHash: TelemetryHash(input: "test-input")
        )

        let receipt2 = ReceiptWire.create(
            actionName: "testAction",
            authority: "test-authority",
            decision: .allowed,
            reasonCode: "test_code",
            timestampMs: 1234567890,
            inputsHash: TelemetryHash(input: "test-input")
        )

        // IDs should match
        XCTAssertEqual(receipt1.receiptID, receipt2.receiptID)
    }

    func testReceiptIDChangesWithDifferentPayload() throws {
        let receipt1 = ReceiptWire.create(
            actionName: "action1",
            authority: "test-authority",
            decision: .allowed,
            reasonCode: "test_code",
            timestampMs: 1234567890,
            inputsHash: TelemetryHash(input: "test-input")
        )

        let receipt2 = ReceiptWire.create(
            actionName: "action2", // Different
            authority: "test-authority",
            decision: .allowed,
            reasonCode: "test_code",
            timestampMs: 1234567890,
            inputsHash: TelemetryHash(input: "test-input")
        )

        // IDs should differ
        XCTAssertNotEqual(receipt1.receiptID, receipt2.receiptID)
    }

    func testReceiptIDVerification() throws {
        let receipt = ReceiptWire.create(
            actionName: "testAction",
            authority: "test-authority",
            decision: .allowed,
            reasonCode: "test_code",
            timestampMs: 1234567890,
            inputsHash: TelemetryHash(input: "test-input")
        )

        // Verification should pass
        XCTAssertNoThrow(try receipt.verifyReceiptID())
    }

    func testReceiptMigration() throws {
        // Create receipt with new API
        let originalReceipt = ReceiptWire.create(
            actionName: "testAction",
            authority: "test-authority",
            decision: .allowed,
            reasonCode: "test_code",
            timestampMs: 1234567890,
            inputsHash: TelemetryHash(input: "test-input")
        )

        // Migrate it
        let result = try ReceiptMigrator.migrateReceipt(originalReceipt)

        // Verify migration
        XCTAssertEqual(result.oldID, originalReceipt.receiptID)
        XCTAssertEqual(result.newID, originalReceipt.receiptID) // Already canonical

        // Verify migrated receipt is valid
        try result.receipt.verifyReceiptID()
    }

    func testReceiptMigrationCheckNeedsMigration() throws {
        let receipt = ReceiptWire.create(
            actionName: "testAction",
            authority: "test-authority",
            decision: .allowed,
            reasonCode: "test_code",
            timestampMs: 1234567890,
            inputsHash: TelemetryHash(input: "test-input")
        )

        // Should not need migration (already canonical)
        let needsMigration = ReceiptMigrator.needsMigration(receipt)
        XCTAssertFalse(needsMigration)
    }

    func testBatchReceiptMigration() throws {
        let receipts = (1...5).map { i in
            ReceiptWire.create(
                actionName: "action\\(i)",
                authority: "test-authority",
                decision: .allowed,
                reasonCode: "test_code",
                timestampMs: 1234567890 + Int64(i),
                inputsHash: TelemetryHash(input: "input\\(i)")
            )
        }

        let results = try ReceiptMigrator.migrateReceipts(receipts)

        XCTAssertEqual(results.count, 5)
        for (index, result) in results.enumerated() {
            XCTAssertEqual(result.oldID, receipts[index].receiptID)
            try result.receipt.verifyReceiptID()
        }
    }

    func testMigrationAnalysis() throws {
        let receipts = (1...3).map { i in
            ReceiptWire.create(
                actionName: "action\\(i)",
                authority: "test-authority",
                decision: .allowed,
                reasonCode: "test_code",
                timestampMs: 1234567890 + Int64(i),
                inputsHash: TelemetryHash(input: "input\\(i)")
            )
        }

        let analysis = ReceiptMigrator.analyzeImpact(receipts)

        XCTAssertEqual(analysis["total_receipts"] as? Int, 3)
        XCTAssertEqual(analysis["needs_migration"] as? Int, 0) // All already canonical
        XCTAssertEqual(analysis["already_correct"] as? Int, 3)
    }
}

// Helper function to assert no throw
func XCTAssertNoThrow<R>(
    _ expression: @autoclosure () throws -> R,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    do {
        _ = try expression()
    } catch {
        XCTFail("Expected no throw but threw: \(error)", file: file, line: line)
    }
}
