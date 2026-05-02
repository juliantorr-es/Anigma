//
//  AuditChainSystem.swift
//  GovernanceCore
//
//  Cryptographic verification for institutional audit logs.
//

import Foundation
import AnigmaPrimitives
import CryptoKit

public struct AuditReceipt: Sendable, Codable {
    public let receiptID: UUID
    public let projectID: ProjectID
    public let principalID: PrincipalID
    public let operation: String
    public let previousHash: String?
    public let payloadHash: String
    
    public init(
        receiptID: UUID,
        projectID: ProjectID,
        principalID: PrincipalID,
        operation: String,
        previousHash: String?,
        payloadHash: String
    ) {
        self.receiptID = receiptID
        self.projectID = projectID
        self.principalID = principalID
        self.operation = operation
        self.previousHash = previousHash
        self.payloadHash = payloadHash
    }
    
    /// Computes the unique hash for this receipt, linking it to the previous one.
    public func computeHash() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(self)
        
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

public enum AuditChainSystem {
    /// Verifies that a chain of receipts is untampered.
    public static func verifyChain(_ receipts: [AuditReceipt]) throws -> Bool {
        var lastHash: String? = nil
        
        for receipt in receipts {
            // 1. Check if this receipt correctly points to the previous hash
            guard receipt.previousHash == lastHash else {
                return false
            }
            
            // 2. Recompute hash and update tracker
            lastHash = try receipt.computeHash()
        }
        
        return true
    }
}
