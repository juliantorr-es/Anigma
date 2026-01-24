//
//  DaemonEvidenceAuthority.swift
//  AnigmaDaemonCore
//

import Foundation
import AnigmaCore
import AnigmaPrimitives
import ExecutionCore

/// Adapter for ReceiptEngine to conform to EvidenceAuthority.
public actor DaemonEvidenceAuthority: EvidenceAuthority {
    private let receiptEngine: ReceiptEngine
    
    public init(receiptEngine: ReceiptEngine) {
        self.receiptEngine = receiptEngine
    }
    
    public func record(
        operation: OperationType,
        principal: Principal,
        payload: EvidencePayload,
        governanceDecision: GovernanceDecision?,
        context: ExecutionContext
    ) async throws -> Receipt {
        let receiptWire = try await receiptEngine.recordActionExecution(
            actionName: operation.rawValue,
            authority: "DaemonEvidenceAuthority",
            decision: governanceDecision?.allowed == true ? .allowed : .denied,
            reasonCode: governanceDecision?.reason ?? "NONE",
            inputs: payload.inputs,
            outputs: payload.outputs
        )
        
        return Receipt(
            receiptID: receiptWire.receiptID,
            actionName: receiptWire.actionName,
            authority: receiptWire.authority,
            decision: receiptWire.decision == .allowed ? .allowed : .denied,
            reasonCode: receiptWire.reasonCode,
            timestamp: Date(timeIntervalSince1970: Double(receiptWire.timestampMs) / 1000.0)
        )
    }
    
    public func query(
        filter: EvidenceFilter,
        principal: Principal
    ) async throws -> [EvidenceBundle] {
        // ReceiptEngine doesn't have a direct query by filter yet.
        // In a real implementation, we'd query the underlying store.
        return []
    }
    
    public func verify(receiptId: ReceiptID) async throws -> VerificationResult {
        let receiptWire = try await receiptEngine.retrieveReceipt(receiptID: receiptId)
        // Verify chain logic would go here
        return VerificationResult(isValid: true)
    }
}
