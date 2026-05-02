//
//  MediaGovernance.swift
//  ContractsCore
//
//  Tier 1 contracts for media governance, specifically materialization policy.
//

import Foundation
import GovernanceContracts

/// Reasons for requesting a materialization (copy) of hardware-resident media.
public enum MaterializationReason: String, Codable, Sendable, CaseIterable {
    /// Materialization for final storage or export.
    case finalArtifact = "finalArtifact"
    
    /// Requested for diagnostic or debug visibility.
    case debugSnapshot = "debugSnapshot"
    
    /// Sent to an executor that cannot process resident references (e.g., PDFium).
    case fallbackBoundary = "fallbackBoundary"
    
    /// Explicitly unsupported executor or capability.
    case unsupportedExecutor = "unsupportedExecutor"
}

/// An event recorded when a materialization attempt is governed by a Gate.
public struct MaterializationEvent: Codable, Sendable {
    /// The reason requested for materialization.
    public let reason: MaterializationReason
    
    /// The outcome of the governance decision.
    public let outcome: GovernanceReceipt.Decision
    
    /// Context or identifier for the media being materialized.
    public let context: String
    
    /// Timestamp of the event.
    public let timestamp: Date
    
    public init(
        reason: MaterializationReason,
        outcome: GovernanceReceipt.Decision,
        context: String,
        timestamp: Date = Date()
    ) {
        self.reason = reason
        self.outcome = outcome
        self.context = context
        self.timestamp = timestamp
    }
}
