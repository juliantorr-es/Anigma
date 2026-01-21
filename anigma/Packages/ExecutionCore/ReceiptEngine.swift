//
//  ReceiptEngine.swift
//  ExecutionCore
//
//  Runtime engine for receipt generation and management.
//  Records decisions but does not make them - uses injected policy interfaces.
//

import Foundation
import TelemetryCore

// MARK: - Receipt Engine Runtime

/// Runtime engine for generating and managing receipts.
/// Records decisions made by external policy evaluators.
public actor ReceiptEngine {
    private let signer: any ReceiptSigner
    private let store: any ReceiptStore
    private let telemetry: TelemetryClient
    private var lastReceiptHash: String?

    public init(signer: any ReceiptSigner, store: any ReceiptStore, telemetry: TelemetryClient) {
        self.signer = signer
        self.store = store
        self.telemetry = telemetry
    }

    public func recordDecision(
        actionName: String,
        authority: String,
        decision: ReceiptDecision,
        reasonCode: String,
        inputs: [String: any Sendable],
        outputs: [String: any Sendable]? = nil,
        metadata: [String: TelemetryValue] = [:]
    ) async throws -> String {
        let timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
        
        // Convert [String: any Sendable] to [String: Any] for hashing helper
        let inputsDict = inputs as [String: Any]
        let outputsDict = outputs as [String: Any]?
        
        let inputsHash = TelemetryHash(input: try encodeInputsForHash(inputsDict))
        let outputsHash = outputsDict != nil ? TelemetryHash(input: try encodeInputsForHash(outputsDict!)) : nil
        
        let receipt = ReceiptWire.create(
            actionName: actionName,
            authority: authority,
            decision: decision,
            reasonCode: reasonCode,
            timestampMs: timestampMs,
            inputsHash: inputsHash,
            outputsHash: outputsHash,
            signature: nil, // Will be signed
            previousReceiptHash: lastReceiptHash,
            metadata: metadata
        )
        
        // Sign
        let payload = try receipt.deterministicJSON()
        let signature = try await signer.sign(data: payload)
        
        var signedReceipt = receipt
        signedReceipt.signature = signature
        
        // Store
        _ = try await store.store(receipt: signedReceipt)
        
        // Emit telemetry
        _ = await telemetry.emit(
            category: .audit,
            name: "receipt_created",
            values: [
                "receipt_id": .hashedToken(TelemetryHash(input: signedReceipt.receiptID)),
                "action_name": .limitedTag((try? TelemetryTag("audit.action.\(actionName)")) ?? .success),
                "decision": .limitedTag(try decisionTag(for: decision)),
                "authority": .hashedToken(TelemetryHash(input: authority))
            ]
        )
        
        lastReceiptHash = signedReceipt.receiptID
        return signedReceipt.receiptID
    }

    public func recordActionExecution(
        actionName: String,
        authority: String,
        decision: ReceiptDecision,
        reasonCode: String,
        inputs: [String: any Sendable],
        outputs: [String: any Sendable]? = nil,
        metadata: [String: TelemetryValue] = [:]
    ) async throws -> ReceiptWire {
        let timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
        
        let inputsDict = inputs as [String: Any]
        let outputsDict = outputs as [String: Any]?
        
        let inputsHash = TelemetryHash(input: try encodeInputsForHash(inputsDict))
        let outputsHash = outputsDict != nil ? TelemetryHash(input: try encodeInputsForHash(outputsDict!)) : nil
        
        let receipt = ReceiptWire.create(
            actionName: actionName,
            authority: authority,
            decision: decision,
            reasonCode: reasonCode,
            timestampMs: timestampMs,
            inputsHash: inputsHash,
            outputsHash: outputsHash,
            previousReceiptHash: lastReceiptHash,
            metadata: metadata
        )
        
        let payload = try receipt.deterministicJSON()
        let signature = try await signer.sign(data: payload)
        
        var signedReceipt = receipt
        signedReceipt.signature = signature
        
        _ = try await store.store(receipt: signedReceipt)
        lastReceiptHash = signedReceipt.receiptID
        
        _ = await telemetry.emit(
            category: .audit,
            name: "action_execution_recorded",
            values: [
                "receipt_id": .hashedToken(TelemetryHash(input: signedReceipt.receiptID)),
                "action_name": .limitedTag((try? TelemetryTag("audit.action.\(actionName)")) ?? .success),
                "decision": .limitedTag(try decisionTag(for: decision)),
                "has_chain_link": .boolean(true)
            ]
        )
        
        return signedReceipt
    }
    
    public func recordPhaseTransition(
        transitionID: String,
        fromPhase: String,
        toPhase: String,
        authority: String,
        decision: ReceiptDecision,
        reasonCode: String,
        context: [String: any Sendable],
        metadata: [String: TelemetryValue] = [:]
    ) async throws -> PhaseTransitionWire {
        let timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
        let contextDict = context as [String: Any]
        let contextHash = TelemetryHash(input: try encodeInputsForHash(contextDict))
        
        let transition = PhaseTransitionWire.create(
            fromPhase: fromPhase,
            toPhase: toPhase,
            authority: authority,
            decision: decision,
            reasonCode: reasonCode,
            timestampMs: timestampMs,
            contextHash: contextHash,
            metadata: metadata
        )
        
        return transition
    }

    /// Verifies the integrity of a receipt chain.
    /// Returns true if all receipts form a valid hash chain.
    public func verifyChain(receipts: [ReceiptWire]) async throws -> Bool {
        guard !receipts.isEmpty else { return true }

        // Sort by timestamp to ensure chronological order
        let sorted = receipts.sorted { $0.timestampMs < $1.timestampMs }

        // First receipt should have no previous hash
        guard sorted[0].previousReceiptHash == nil else {
            return false
        }

        // Verify receipt IDs and signatures
        for receipt in sorted {
            try receipt.verifyReceiptID()
            guard let signature = receipt.signature else {
                return false
            }
            let payload = try receipt.deterministicJSON()
            let validSignature = try await signer.verify(data: payload, signature: signature)
            guard validSignature else {
                return false
            }
        }

        // Verify each subsequent receipt links to the previous one
        for i in 1..<sorted.count {
            let current = sorted[i]
            let previous = sorted[i - 1]

            // Verify the chain link
            guard current.previousReceiptHash == previous.receiptID else {
                return false
            }
        }

        return true
    }

    /// Gets the current chain head (last receipt hash).
    public func getChainHead() -> String? {
        return lastReceiptHash
    }

    /// Resets the chain head (use with caution - for testing only).
    public func resetChainHead() {
        lastReceiptHash = nil
    }

    // MARK: - Private Helpers

    /// Encodes inputs for hash computation (deterministic)
    private func encodeInputsForHash(_ inputs: [String: Any]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970

        // Convert Any to JSON-serializable types using struct
        struct SerializableValue: Codable {
            let stringValue: String?
            let numberValue: Double?
            let boolValue: Bool?
            let dateValue: Int64?

            init(from any: Any) {
                if let string = any as? String {
                    self.stringValue = string
                    self.numberValue = nil
                    self.boolValue = nil
                    self.dateValue = nil
                } else if let number = any as? NSNumber {
                    self.stringValue = nil
                    self.numberValue = number.doubleValue
                    self.boolValue = nil
                    self.dateValue = nil
                } else if let bool = any as? Bool {
                    self.stringValue = nil
                    self.numberValue = nil
                    self.boolValue = bool
                    self.dateValue = nil
                } else if let date = any as? Date {
                    self.stringValue = nil
                    self.numberValue = nil
                    self.boolValue = nil
                    self.dateValue = Int64(date.timeIntervalSince1970 * 1000)
                } else {
                    self.stringValue = String(describing: any)
                    self.numberValue = nil
                    self.boolValue = nil
                    self.dateValue = nil
                }
            }
        }

        let serializable: [String: SerializableValue] = inputs.mapValues {
            SerializableValue(from: $0)
        }
        let data = try JSONEncoder().encode(serializable)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Converts decision to telemetry-safe tag
    private func decisionTag(for decision: ReceiptDecision) throws -> TelemetryTag {
        switch decision {
        case .allowed:
             return try TelemetryTag("audit.decision.allowed")
        case .denied:
             return try TelemetryTag("audit.decision.denied")
        case .auditRequired:
             return try TelemetryTag("audit.decision.audit_required")
        case .quarantine:
             return try TelemetryTag("audit.decision.quarantine")
        case .error:
             return try TelemetryTag("audit.decision.error")
        }
    }
}
