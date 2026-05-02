//
//  GovernanceReceipt.swift
//  ContractsCore
//
//  A portable receipt proving that a governance decision was made by an Authority or Gate.
//  Used to trace materialization, access control, and policy enforcement.
//

import Foundation

/// A portable receipt proving a governance decision.
public struct GovernanceReceipt: Codable, Sendable, Hashable {
    /// Unique identifier for this receipt.
    public let id: UUID
    
    /// The timestamp when the decision was made.
    public let timestamp: Date
    
    /// The decision outcome.
    public let decision: Decision
    
    /// The reason or category for the decision.
    public let reason: String
    
    /// Optional context or metadata about the decision.
    public let context: String?
    
    /// The outcome of a governance decision.
    public enum Decision: String, Codable, Sendable, Hashable {
        /// The operation was allowed.
        case allowed
        /// The operation was denied.
        case denied
        /// The operation was rerouted to a fallback path.
        case fallback
    }
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        decision: Decision,
        reason: String,
        context: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.decision = decision
        self.reason = reason
        self.context = context
    }
}
