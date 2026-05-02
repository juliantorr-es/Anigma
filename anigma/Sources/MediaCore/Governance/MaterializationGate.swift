//
//  MaterializationGate.swift
//  MediaCore
//
//  Tier 2 Authority governing forced media copies (materialization).
//

import Foundation
import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import GovernanceCore
import SaturationKit
import AnigmaPrimitives

/// A Tier 2 Authority that governs all forced media copies across the substrate.
/// Enforces zero-copy continuity or explicitly traces materialization through SaturatedLoggingRing.
public actor MaterializationGate {
    private let loggingRing: SaturatedLoggingRing
    private var eventSequence: UInt32 = 0
    
    public init(loggingRing: SaturatedLoggingRing) {
        self.loggingRing = loggingRing
    }
    
    /// Authorizes a materialization (copy) operation for a given reason and context.
    ///
    /// - Parameters:
    ///   - reason: The architectural reason for the materialization.
    ///   - context: A unique identifier or context for the media being materialized.
    /// - Returns: A GovernanceReceipt proving the decision.
    /// - Throws: If the materialization is denied.
    public func authorizeCopy(
        reason: MaterializationReason,
        context: String
    ) async throws -> GovernanceReceipt {
        // Governance Policy:
        // 1. .unsupportedExecutor is always denied.
        // 2. All other reasons are allowed but must be receipted and logged to SaturatedLoggingRing.
        
        let decision: GovernanceReceipt.Decision
        let receiptReason: String
        
        switch reason {
        case .unsupportedExecutor:
            decision = .denied
            receiptReason = "Materialization denied: unsupported executor capability"
        case .finalArtifact, .debugSnapshot, .fallbackBoundary:
            decision = .allowed
            receiptReason = "Materialization authorized: \(reason.rawValue)"
        }
        
        let receipt = GovernanceReceipt(
            decision: decision,
            reason: receiptReason,
            context: context
        )
        
        // Log to SaturatedLoggingRing
        try await logEvent(reason: reason, decision: decision, context: context)
        
        if decision == .denied {
            throw MaterializationError.governanceDenied(receipt: receipt)
        }
        
        return receipt
    }
    
    private func logEvent(
        reason: MaterializationReason,
        decision: GovernanceReceipt.Decision,
        context: String
    ) async throws {
        let packetType: SaturatedHeartbeatPacketType = (decision == .denied) ? .violation : .heartbeat
        let sequence = eventSequence
        eventSequence = eventSequence &+ 1
        
        // Create a BLAKE3 hash of the context + reason
        let hashSource = "\(reason.rawValue):\(decision.rawValue):\(context)"
        let hash = BLAKE3Digest.digest(Data(hashSource.utf8))
        
        let packet = SaturatedHeartbeatPacket(
            missionID: UUID(),
            packetType: packetType,
            sequence: sequence,
            payloadHash: hash,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000)
        )
        
        try await loggingRing.appendFromCPU(packet)
    }
}

/// Errors related to media materialization.
public enum MaterializationError: LocalizedError {
    case governanceDenied(receipt: GovernanceReceipt)
    
    public var errorDescription: String? {
        switch self {
        case .governanceDenied(let receipt):
            return "Governance denied materialization. Receipt ID: \(receipt.id), Reason: \(receipt.reason)"
        }
    }
}
