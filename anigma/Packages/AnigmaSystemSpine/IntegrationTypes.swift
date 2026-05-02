//
//  IntegrationTypes.swift
//  AnigmaSystemSpine
//
//  Shared types for Integration Health and Status.
//

import Foundation

public enum IntegrationHealthStatus: String, Codable, Sendable {
    case ok
    case degraded
    case blockedByPolicy = "blocked_by_policy"
    case requiresUserAction = "requires_user_action"
    case requiresAdminAction = "requires_admin_action"
    case providerDown = "provider_down"
    case rateLimited = "rate_limited"
    case revoked
    case unknown
}

public enum SyncTrackType: String, Codable, Sendable {
    case capture
    case browse
    case correctness
    case writeBack = "write_back"
    case roster
    case assignments
    case grades
}

public enum ConflictStatus: String, Codable, Sendable {
    case open
    case resolved
    case ignored
}

public enum RepairActionStatus: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
}

public struct IntegrationHealth: Codable, Sendable {
    public let status: IntegrationHealthStatus
    public let reason: String?
    public let lastChecked: Date

    public init(status: IntegrationHealthStatus, reason: String? = nil, lastChecked: Date = Date()) {
        self.status = status
        self.reason = reason
        self.lastChecked = lastChecked
    }
}

public struct SyncTrackSnapshot: Codable, Sendable {
    public let id: UUID
    public let accountId: UUID
    public let kind: SyncTrackType
    public let lastWatermark: String?
    public let lastSuccess: Date?
    public let lastFailure: Date?
    public let failureReason: String?

    public init(id: UUID, accountId: UUID, kind: SyncTrackType, lastWatermark: String?, lastSuccess: Date?, lastFailure: Date?, failureReason: String?) {
        self.id = id
        self.accountId = accountId
        self.kind = kind
        self.lastWatermark = lastWatermark
        self.lastSuccess = lastSuccess
        self.lastFailure = lastFailure
        self.failureReason = failureReason
    }
}
