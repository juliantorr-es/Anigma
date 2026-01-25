//
//  SessionComponent.swift
//  HarmoniaModule
//
//  Represents a logical session.
//  Migrated from: Harmonia/OrchestrumCore/ECS/Components.swift
//

import AnigmaCore
@preconcurrency import Foundation

/// Represents a logical session.
public struct SessionComponent: Component, Codable {
    public let sessionId: String
    public let userId: String
    public let createdAt: Date
    public var lastActivityAt: Date
    public var messageCount: Int
    public var tokensUsed: Int

    public init(
        sessionId: String,
        userId: String,
        createdAt: Date = Date(),
        lastActivityAt: Date = Date(),
        messageCount: Int = 0,
        tokensUsed: Int = 0
    ) {
        self.sessionId = sessionId
        self.userId = userId
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
        self.messageCount = messageCount
        self.tokensUsed = tokensUsed
    }

    /// Duration since session was created.
    public var age: TimeInterval {
        Date().timeIntervalSince(createdAt)
    }

    /// Duration since last activity.
    public var idleTime: TimeInterval {
        Date().timeIntervalSince(lastActivityAt)
    }
}
