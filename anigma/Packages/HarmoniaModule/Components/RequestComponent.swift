//
//  RequestComponent.swift
//  HarmoniaModule
//
//  Represents an inference request being processed.
//  Migrated from: Harmonia/OrchestrumCore/ECS/Components.swift
//

import AnigmaCore
@preconcurrency import Foundation

/// Represents an inference request being processed.
public struct RequestComponent: Component, Codable {
    public let requestId: String
    public let modelKind: String // Changed from ModelKind
    public let sessionId: String
    public let userId: String
    public var phase: RequestPhase
    public let startedAt: Date
    public var estimatedTokens: Int
    public var strategy: String?

    public init(
        requestId: String,
        modelKind: String,
        sessionId: String,
        userId: String,
        phase: RequestPhase = .queued,
        startedAt: Date = Date(),
        estimatedTokens: Int = 0,
        strategy: String? = nil
    ) {
        self.requestId = requestId
        self.modelKind = modelKind
        self.sessionId = sessionId
        self.userId = userId
        self.phase = phase
        self.startedAt = startedAt
        self.estimatedTokens = estimatedTokens
        self.strategy = strategy
    }

    /// Duration since request started.
    public var elapsed: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }
}

/// Phase of a request in the processing pipeline.
public enum RequestPhase: String, Sendable, Codable, CaseIterable {
    case queued
    case acquiringSlot
    case processing
    case synthesizing
    case completing
    case completed
    case failed
}
