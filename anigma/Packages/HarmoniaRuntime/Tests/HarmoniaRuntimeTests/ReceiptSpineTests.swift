// HarmoniaRuntime Receipt Spine Tests
// Minimal tests for receipt generation and audit event emission

import XCTest
import HarmoniaRuntime
import ExecutionCore
import TelemetryCore

final class ReceiptSpineTests: XCTestCase {
    
    func testReceiptGeneration() throws {
        // Test basic receipt generation
        let receipt = HarmoniaRuntime.generateReceipt(
            action: .queryExecution,
            decision: .allowed,
            reasonCode: .capabilityPartial,
            input: "test query",
            capabilityArea: .querySession,
            policyContext: "receipt-test"
        )
        let duplicateReceipt = HarmoniaRuntime.generateReceipt(
            action: .queryExecution,
            decision: .allowed,
            reasonCode: .capabilityPartial,
            input: "test query",
            capabilityArea: .querySession,
            policyContext: "receipt-test"
        )
        
        // Verify receipt properties
        XCTAssertEqual(receipt.actionName, "harmonia.query")
        XCTAssertEqual(receipt.authority, "HarmoniaRuntime")
        XCTAssertEqual(receipt.decision, .allowed)
        XCTAssertEqual(receipt.reasonCode, "CAPABILITY_PARTIAL")
        XCTAssertEqual(receipt.receiptID, duplicateReceipt.receiptID)
        XCTAssertEqual(receipt.timestampMs, duplicateReceipt.timestampMs)
        
        // Verify metadata
        let metadata = receipt.metadata
        XCTAssertNotNil(metadata["capability_area"])
        XCTAssertNotNil(metadata["runtime_version"])
        XCTAssertNotNil(metadata["facade_version"])
        XCTAssertEqual(metadata["policy_context"], .string("receipt-test"))
        
        // Verify deterministic ID
        XCTAssertFalse(receipt.receiptID.isEmpty)
        print("Generated receipt ID: \(receipt.receiptID)")
    }
    
    func testAuditEventEmission() throws {
        // Test audit event generation
        let auditEvent = HarmoniaRuntime.emitAuditEvent(
            action: .statusCheck,
            outcome: .allowed,
            reasonCode: .success,
            actor: "cli-user",
            policyContext: "runtime.status",
            evidenceReference: "receipt-123",
            timestampMs: 1_700_000_000_000
        )
        
        // Verify event properties
        XCTAssertEqual(auditEvent.category, "harmonia.runtime")
        XCTAssertEqual(auditEvent.level, .info)
        XCTAssertTrue(auditEvent.message.contains("harmonia.status"))
        XCTAssertTrue(auditEvent.message.contains("SUCCESS"))
        XCTAssertEqual(auditEvent.correlationID, "receipt-123")
        
        // Verify metadata
        let metadata = auditEvent.metadata
        XCTAssertEqual(metadata["action"], "harmonia.status")
        XCTAssertEqual(metadata["outcome"], "allowed")
        XCTAssertEqual(metadata["reason_code"], "SUCCESS")
        XCTAssertEqual(metadata["actor"], "cli-user")
        XCTAssertEqual(metadata["policy_context"], "runtime.status")
        XCTAssertEqual(metadata["evidence_reference"], "receipt-123")
    }
    
    func testActionableError() throws {
        // Test actionable error creation
        let baseError = HarmoniaRuntimeError.notConfigured(
            capability: "test.capability",
            reason: "Test error"
        )
        
        let actionableError = HarmoniaRuntime.createActionableError(
            from: baseError,
            action: .queryExecution,
            reasonCode: .notConfigured
        )
        
        // Verify error properties
        XCTAssertEqual(actionableError.action, .queryExecution)
        XCTAssertEqual(actionableError.reasonCode, .notConfigured)
        XCTAssertNotNil(actionableError.errorDescription)
        XCTAssertNotNil(actionableError.recoverySuggestion)
        
        // Verify help message
        XCTAssertTrue(actionableError.helpMessage.contains("additional configuration"))
    }
    
    func testDeterministicHashGeneration() throws {
        // Test that same input generates same hash
        let generator = HarmoniaReceiptGenerator()
        
        let hash1 = generator.generateInputHash(from: "test input")
        let hash2 = generator.generateInputHash(from: "test input")
        
        // Same input should produce same hash
        XCTAssertEqual(hash1.algorithm, hash2.algorithm)
        XCTAssertEqual(hash1.digest, hash2.digest)
        
        // Different input should produce different hash
        let hash3 = generator.generateInputHash(from: "different input")
        XCTAssertNotEqual(hash1.digest, hash3.digest)
    }
    
    func testCompositeHash() throws {
        // Test composite hash generation
        let generator = HarmoniaReceiptGenerator()
        
        let components = ["component1", "component2", "component3"]
        let hash = generator.generateCompositeHash(components: components)
        
        // Verify hash is generated
        XCTAssertFalse(hash.digest.isEmpty)
        XCTAssertEqual(hash.algorithm, "BLAKE3")
    }
    
    func testStatusUpdate() throws {
        // Test that status reflects receipts/observability improvements
        let status = HarmoniaRuntime.status()
        
        // Verify receipts/observability is surfaced truthfully
        XCTAssertEqual(status.receiptsObservability, .partial)
        
        // Verify notes mention receipts
        let notes = status.notes
        let receiptsMentioned = notes.contains { $0.lowercased().contains("receipt") }
        XCTAssertTrue(receiptsMentioned, "Status notes should mention receipt improvements")
        XCTAssertTrue(notes.contains { $0.lowercased().contains("journaled") })
    }
}
