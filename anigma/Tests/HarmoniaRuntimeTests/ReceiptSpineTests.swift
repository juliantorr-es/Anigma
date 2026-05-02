import Testing
@testable import HarmoniaRuntime
import ExecutionCore
import TelemetryCore
import Foundation

struct ReceiptSpineTests {
    @Test func testReceiptGeneration() throws {
        let receipt = HarmoniaRuntime.generateReceipt(
            action: .queryExecution,
            decision: .allowed,
            reasonCode: .success,
            input: "test query",
            capabilityArea: .ready,
            policyContext: "receipt-test"
        )
        let duplicateReceipt = HarmoniaRuntime.generateReceipt(
            action: .queryExecution,
            decision: .allowed,
            reasonCode: .success,
            input: "test query",
            capabilityArea: .ready,
            policyContext: "receipt-test"
        )
        
        #expect(receipt.actionName == "harmonia.query")
        #expect(receipt.authority == "HarmoniaRuntime")
        #expect(receipt.decision == .allowed)
        #expect(receipt.reasonCode == "SUCCESS")
        #expect(receipt.receiptID == duplicateReceipt.receiptID)
        #expect(receipt.timestampMs == duplicateReceipt.timestampMs)
        
        let metadata = receipt.metadata
        #expect(metadata["capability_area"] != nil)
        #expect(metadata["runtime_version"] != nil)
        #expect(metadata["facade_version"] != nil)
        
        if case .string(let context) = metadata["policy_context"] {
            #expect(context == "receipt-test")
        } else {
            Issue.record("policy_context missing or not a string")
        }
        
        #expect(!receipt.receiptID.isEmpty)
    }
    
    @Test func testAuditEventEmission() throws {
        let auditEvent = HarmoniaRuntime.emitAuditEvent(
            action: .statusCheck,
            outcome: .allowed,
            reasonCode: .success,
            actor: "cli-user",
            policyContext: "runtime.status",
            evidenceReference: "receipt-123",
            timestampMs: 1_700_000_000_000
        )
        
        #expect(auditEvent.category == "harmonia.runtime")
        #expect(auditEvent.level == .info)
        #expect(auditEvent.message.contains("harmonia.status"))
        #expect(auditEvent.message.contains("SUCCESS"))
        #expect(auditEvent.correlationID == "receipt-123")
        
        let metadata = auditEvent.metadata
        #expect(metadata["action"] == "harmonia.status")
        #expect(metadata["outcome"] == "allowed")
        #expect(metadata["reason_code"] == "SUCCESS")
        #expect(metadata["actor"] == "cli-user")
        #expect(metadata["policy_context"] == "runtime.status")
        #expect(metadata["evidence_reference"] == "receipt-123")
    }
    
    @Test func testActionableError() throws {
        let baseError = HarmoniaRuntimeError.notConfigured(
            capability: "test.capability",
            reason: "Test error"
        )
        
        let actionableError = HarmoniaRuntime.createActionableError(
            from: baseError,
            action: .queryExecution,
            reasonCode: .notConfigured
        )
        
        #expect(actionableError.action == .queryExecution)
        #expect(actionableError.reasonCode == .notConfigured)
        #expect(actionableError.errorDescription != nil)
        #expect(actionableError.recoverySuggestion != nil)
        #expect(actionableError.helpMessage.contains("additional configuration"))
    }
    
    @Test func testDeterministicHashGeneration() throws {
        let generator = HarmoniaReceiptGenerator()
        
        let hash1 = generator.generateInputHash(from: "test input")
        let hash2 = generator.generateInputHash(from: "test input")
        
        #expect(hash1.algorithm == hash2.algorithm)
        #expect(hash1.hex == hash2.hex)
        
        let hash3 = generator.generateInputHash(from: "different input")
        #expect(hash1.hex != hash3.hex)
    }
    
    @Test func testCompositeHash() throws {
        let generator = HarmoniaReceiptGenerator()
        
        let components = ["component1", "component2", "component3"]
        let hash = generator.generateCompositeHash(components: components)
        
        #expect(!hash.hex.isEmpty)
        #expect(hash.algorithm == .blake3)
    }
    
    @Test func testStatusUpdate() throws {
        let status = HarmoniaRuntime.status()
        
        #expect(status.receiptsObservability == .partial)
        
        let notes = status.notes
        let receiptsMentioned = notes.contains { $0.lowercased().contains("receipt") }
        #expect(receiptsMentioned)
        #expect(notes.contains { $0.lowercased().contains("journaled") })
    }
}
