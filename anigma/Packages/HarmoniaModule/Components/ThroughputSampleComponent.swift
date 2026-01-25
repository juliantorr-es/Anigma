//
//  ThroughputSampleComponent.swift
//  HarmoniaModule
//
//  A time-series sample for throughput tracking.
//  Migrated from: Harmonia/OrchestrumCore/ECS/Components.swift
//

import AnigmaCore
@preconcurrency import Foundation

/// A time-series sample for throughput tracking.
public struct ThroughputSampleComponent: Component, Codable {
    public let modelKind: String // Changed from ModelKind
    public let timestamp: Date
    public let requestsCompleted: Int
    public let tokensProcessed: Int
    public let avgLatencyMs: Double

    public init(
        modelKind: String,
        timestamp: Date = Date(),
        requestsCompleted: Int = 0,
        tokensProcessed: Int = 0,
        avgLatencyMs: Double = 0
    ) {
        self.modelKind = modelKind
        self.timestamp = timestamp
        self.requestsCompleted = requestsCompleted
        self.tokensProcessed = tokensProcessed
        self.avgLatencyMs = avgLatencyMs
    }
}
