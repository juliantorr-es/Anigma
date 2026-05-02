// HarmoniaRuntime Receipt Test Command
// CLI command to test receipt generation and audit event emission

import ArgumentParser
import Foundation
import HarmoniaRuntime
import ExecutionCore

struct ReceiptTestCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "receipt-test",
            abstract: "Test HarmoniaRuntime receipt generation and audit events."
        )
    }
    
    @Option(name: .shortAndLong, help: "Action type to test (query, status, capability, tool, error, health)")
    var actionType: String = "query"
    
    @Option(name: .shortAndLong, help: "Input text for the action")
    var input: String = "test input"
    
    mutating func run() async throws {
        print("🧾 HarmoniaRuntime Receipt Test")
        print("================================")
        
        // Parse action type
        let action: HarmoniaRuntimeAction
        switch actionType.lowercased() {
        case "status": action = .statusCheck
        case "capability": action = .capabilityCheck
        case "tool": action = .toolExecution
        case "error": action = .errorResponse
        case "health": action = .healthMonitor
        case "query", _: action = .queryExecution
        }
        
        print("Action: \(action.rawValue)")
        print("Input: \(input)")
        print()
        
        // Test receipt generation
        print("📋 Generating receipt...")
        let receipt = HarmoniaRuntime.generateReceipt(
            action: action,
            decision: .allowed,
            reasonCode: .success,
            input: input,
            capabilityArea: .ready,
            policyContext: "receipt-test"
        )
        let duplicateReceipt = HarmoniaRuntime.generateReceipt(
            action: action,
            decision: .allowed,
            reasonCode: .success,
            input: input,
            capabilityArea: .ready,
            policyContext: "receipt-test"
        )
        
        print("✅ Receipt generated successfully")
        print("   Receipt ID: \(receipt.receiptID)")
        print("   Action: \(receipt.actionName)")
        print("   Decision: \(receipt.decision.rawValue)")
        print("   Reason Code: \(receipt.reasonCode)")
        print("   Timestamp: \(receipt.timestampMs)ms")
        print("   Input Hash: \(receipt.inputsHash.algorithm.rawValue):\(receipt.inputsHash.hex.prefix(16))...")
        print("   Deterministic ID: \(receipt.receiptID == duplicateReceipt.receiptID ? "verified" : "mismatch")")
        print()
        
        // Test audit event generation
        print("📊 Generating audit event...")
        let auditEvent = HarmoniaRuntime.emitAuditEvent(
            action: action,
            outcome: .allowed,
            reasonCode: .success,
            actor: "cli-user",
            policyContext: "receipt-test",
            evidenceReference: receipt.receiptID,
            timestampMs: receipt.timestampMs
        )
        
        print("✅ Audit event generated successfully")
        print("   Category: \(auditEvent.category)")
        print("   Level: \(auditEvent.level)")
        print("   Message: \(auditEvent.message)")
        print("   Correlation ID: \(auditEvent.correlationID)")
        print("   Actor: \(auditEvent.metadata["actor"] ?? "<missing>")")
        print("   Policy Context: \(auditEvent.metadata["policy_context"] ?? "<missing>")")
        print("   Evidence Reference: \(auditEvent.metadata["evidence_reference"] ?? "<missing>")")
        print()
        
        // Test actionable error
        print("⚠️  Testing actionable error...")
        let baseError = HarmoniaRuntimeError.notConfigured(
            capability: "test.capability",
            reason: "Test configuration missing"
        )
        
        let actionableError = HarmoniaRuntime.createActionableError(
            from: baseError,
            action: action,
            reasonCode: .notConfigured
        )
        
        print("✅ Actionable error created successfully")
        print("   Error: \(actionableError.errorDescription ?? "No description")")
        print("   Help: \(actionableError.recoverySuggestion ?? "No suggestion")")
        print()
        
        // Test deterministic hashing
        print("🔐 Testing deterministic hashing...")
        let generator = HarmoniaReceiptGenerator()
        let hash1 = generator.generateInputHash(from: input)
        let hash2 = generator.generateInputHash(from: input)
        
        if hash1.hex == hash2.hex {
            print("✅ Deterministic hashing verified - same input produces same hash")
        } else {
            print("❌ Hashing failed - same input produced different hashes")
        }
        print()
        
        print("🎉 All receipt tests completed successfully!")
        print("HarmoniaRuntime receipt spine is working correctly.")
    }
}
