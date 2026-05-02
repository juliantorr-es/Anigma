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
        operation: AnigmaCore.CoreOperationType,
        principal: AnigmaCore.Principal,
        payload: AnigmaCore.EvidencePayload,
        governanceDecision: GovernanceDecision?,
        context: ExecutionContext
    ) async throws -> AnigmaCore.CoreReceipt {
        let evidenceInputs: [String: any Sendable]
        let evidenceOutputs: [String: any Sendable]?

        switch payload {
        case .workflowExecution(let workflowType, let inputs, let outputs):
            evidenceInputs = [
                "workflow_type": workflowType,
                "input_count": inputs.count,
                "output_count": outputs.count
            ]
            evidenceOutputs = nil
        case .databaseMutation(let sql, let rowsAffected):
            evidenceInputs = [
                "sql": sql,
                "rows_affected": rowsAffected
            ]
            evidenceOutputs = nil
        case .mlInference(let model, let prompt, let response):
            evidenceInputs = [
                "model": model,
                "prompt": prompt
            ]
            evidenceOutputs = [
                "response": response
            ]
        case .artifactStorage(let artifactId, let size):
            evidenceInputs = [
                "artifact_id": artifactId,
                "size": size
            ]
            evidenceOutputs = nil
        case .custom(let type, let data):
            evidenceInputs = [
                "type": type
            ]
            evidenceOutputs = data
        case .hardwareHeartbeat(let missionID, let powerWatts, let opsPerJoule, let timestamp):
            evidenceInputs = [
                "mission_id": missionID,
                "power_watts": powerWatts,
                "ops_per_joule": opsPerJoule,
                "timestamp": timestamp
            ]
            evidenceOutputs = nil
        }

        let receiptWire = try await receiptEngine.recordActionExecution(
            actionName: operation.rawValue,
            authority: "DaemonEvidenceAuthority",
            decision: governanceDecision?.allowed == true ? .allowed : .denied,
            reasonCode: governanceDecision?.reason ?? "NONE",
            inputs: evidenceInputs,
            outputs: evidenceOutputs
        )
        
        // Compute real BLAKE3 hash for verification
        var combinedData = Data()
        combinedData.append(operation.rawValue.data(using: .utf8) ?? Data())
        combinedData.append(principal.id.data(using: .utf8) ?? Data())
        combinedData.append(payload.serialize())
        let contentHash = await BLAKE3Digest.digestHexAsync([UInt8](combinedData))

        return AnigmaCore.CoreReceipt(
            id: AnigmaCore.ReceiptID(raw: receiptWire.receiptID),
            operationType: operation.rawValue,
            principal: principal,
            timestamp: Date(timeIntervalSince1970: Double(receiptWire.timestampMs) / 1000.0),
            outcome: receiptWire.decision == .allowed ? .success : .denied,
            summary: receiptWire.reasonCode,
            metadata: [:],
            contentHash: contentHash
        )
    }
    
    public func query(
        filter: AnigmaCore.EvidenceFilter,
        principal: AnigmaCore.Principal
    ) async throws -> [AnigmaCore.EvidenceBundle] {
        // ReceiptEngine doesn't have a direct query by filter yet.
        // In a real implementation, we'd query the underlying store.
        return []
    }
    
    public func verify(receiptId: AnigmaCore.ReceiptID) async throws -> AnigmaCore.VerificationResult {
        throw NSError(
            domain: "DaemonEvidenceAuthority",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Receipt verification is not supported by ReceiptEngine"]
        )
    }
}
