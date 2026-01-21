//
//  CapabilityGrant.swift
//  ContractsCore
//
//  Grant of capabilities with expiration.
//

import AnigmaPrimitives
import Foundation

/// Grant of capabilities with expiration.
public struct CapabilityGrant: Sendable, Codable {
    public let id: UUID
    public let engineId: String
    public let capabilities: [GranularCapability]
    public let grantedAt: Date
    public let expiresAt: Date
    public let zone: SecurityZone
    public let trustTier: TrustTier

    public init(
        id: UUID = UUID(),
        engineId: String,
        capabilities: [GranularCapability],
        grantedAt: Date = Date(),
        expiresAt: Date,
        zone: SecurityZone,
        trustTier: TrustTier
    ) {
        self.id = id
        self.engineId = engineId
        self.capabilities = capabilities
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
        self.zone = zone
        self.trustTier = trustTier
    }

    public var isExpired: Bool {
        Date() > expiresAt
    }

    public var timeRemaining: TimeInterval {
        max(0, expiresAt.timeIntervalSince(Date()))
    }

    /// Check if grant includes a specific capability.
    public func includes(_ capability: GranularCapability) -> Bool {
        capabilities.contains(capability)
    }

    /// Check if grant includes all required capabilities.
    public func includesAll(_ required: [GranularCapability]) -> Bool {
        required.allSatisfy { includes($0) }
    }
}
