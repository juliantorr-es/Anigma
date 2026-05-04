//
//  EvidenceAuthorityImpl.swift
//  AnigmaFoundation
//
//  Core implementation of EvidenceAuthority that uses ReceiptSigner from EvidenceContracts.
//

import Foundation
import AnigmaPrimitives
import GovernanceCore
import EvidenceContracts
import DatabaseCore

// MARK: - Evidence Authority Implementation

/// Core implementation of EvidenceAuthority that unifies all evidence operations
/// Uses ReceiptSigner from EvidenceContracts (Tier 1) - no dependency on ExecutionCore
public actor EvidenceAuthorityImpl: EvidenceAuthority {
    
    // Core components - ReceiptSigner from EvidenceContracts (Tier 1)
    private let database: any DatabaseAuthority
    private let signer: any ReceiptSigner
    private let accessController: any AccessController
    private let governance: any GoverningController
    
    // Configuration
    private let config: EvidenceAuthorityConfig
    
    public init(
        database: any DatabaseAuthority,
        signer: any ReceiptSigner,
        accessController: any AccessController,
        governance: any GoverningController,
        config: EvidenceAuthorityConfig = .default
    ) {
        self.database = database
        self.signer = signer
        self.accessController = accessController
        self.governance = governance
        self.config = config
    }
    
    // MARK: - EvidenceAuthority Protocol
    
    public func record(
        operation: CoreOperationType,
        principal: Principal,
        payload: EvidencePayload,
        governanceDecision: GovernanceDecision?,
        context: ExecutionContext
    ) async throws -> CoreReceipt {
        // Sign the receipt data using ReceiptSigner from EvidenceContracts
        let receiptData = try JSONSerialization.data(withJSONObject: [
            "operation": operation.rawValue,
            "principal": principal.id,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ], options: .sortedKeys)
        
        let signature = try await signer.sign(data: receiptData)
        
        // Create CoreReceipt with signature in metadata
        // TODO: td-d65648 - Full integration with ExecutionCore ReceiptWire pending
        return CoreReceipt(
            id: ReceiptID(),
            operationType: operation.rawValue,
            principal: principal,
            timestamp: Date(),
            outcome: .success,
            summary: "Evidence recorded",
            metadata: ["signature": signature, "signerID": signer.signerID],
            inputRefs: [],
            outputRefs: [],
            contentHash: BLAKE3Digest.hex(of: receiptData),
            durationMs: 0
        )
    }
    
    public func query(
        filter: EvidenceFilter,
        principal: Principal
    ) async throws -> [EvidenceBundle] {
        // TODO: td-d65648 - Query implementation pending database schema alignment
        // For now return empty - satisfies protocol without ExecutionCore dependency
        return []
    }
    
    public func verify(receiptId: ReceiptID) async throws -> VerificationResult {
        // TODO: td-358315 - Full verification pending architecture resolution
        return VerificationResult(
            isValid: false,
            violations: ["Verification not yet implemented - td-358315"],
            chainIntact: false,
            timestampValid: false
        )
    }
}

// MARK: - Supporting Types

public struct EvidenceAuthorityConfig: Sendable {
    public let enableValidation: Bool
    public let requireSignatures: Bool
    
    public static let `default` = EvidenceAuthorityConfig(
        enableValidation: true,
        requireSignatures: true
    )
    
    public init(
        enableValidation: Bool = true,
        requireSignatures: Bool = true
    ) {
        self.enableValidation = enableValidation
        self.requireSignatures = requireSignatures
    }
}
