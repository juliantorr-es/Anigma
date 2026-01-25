//
//  MetricsComponent.swift
//  HarmoniaModule
//
//  Aggregated metrics for a model kind.
//  Migrated from: Harmonia/OrchestrumCore/ECS/Components.swift
//

import AnigmaCore
@preconcurrency import Foundation

/// Aggregated metrics for a model kind.
public struct MetricsComponent: Component, Codable {
    public let modelKind: String // Changed from ModelKind
    public var completedCount: Int
    public var failedCount: Int
    public var rejectedCount: Int
    public var totalLatencyMs: Int64
    public var totalTokensInput: Int
    public var totalTokensOutput: Int
    public var lastUpdated: Date

    public init(
        modelKind: String,
        completedCount: Int = 0,
        failedCount: Int = 0,
        rejectedCount: Int = 0,
        totalLatencyMs: Int64 = 0,
        totalTokensInput: Int = 0,
        totalTokensOutput: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.modelKind = modelKind
        self.completedCount = completedCount
        self.failedCount = failedCount
        self.rejectedCount = rejectedCount
        self.totalLatencyMs = totalLatencyMs
        self.totalTokensInput = totalTokensInput
        self.totalTokensOutput = totalTokensOutput
        self.lastUpdated = lastUpdated
    }

    /// Average latency in milliseconds.
    public var avgLatencyMs: Double {
        guard completedCount > 0 else { return 0 }
        return Double(totalLatencyMs) / Double(completedCount)
    }

    /// Success rate (0.0 to 1.0).
    public var successRate: Double {
        let total = completedCount + failedCount
        guard total > 0 else { return 1.0 }
        return Double(completedCount) / Double(total)
    }

    /// Requests per minute (approximate).
    public var requestsPerMinute: Double {
        // This would need a time window; for now return 0
        return 0
    }
}
