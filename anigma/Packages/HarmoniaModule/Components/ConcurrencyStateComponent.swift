//
//  ConcurrencyStateComponent.swift
//  HarmoniaModule
//
//  Current state of concurrency for a model kind.
//  Migrated from: Harmonia/OrchestrumCore/ECS/Components.swift
//

import AnigmaCore
@preconcurrency import Foundation

/// Current state of concurrency for a model kind.
public struct ConcurrencyStateComponent: Component, Codable {
    public let modelKind: String // Changed from ModelKind
    public var limit: Int
    public var inFlight: Int
    public var waiting: Int
    public var lastUpdated: Date

    public init(
        modelKind: String,
        limit: Int,
        inFlight: Int = 0,
        waiting: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.modelKind = modelKind
        self.limit = limit
        self.inFlight = inFlight
        self.waiting = waiting
        self.lastUpdated = lastUpdated
    }

    /// Available slots.
    public var available: Int {
        max(0, limit - inFlight)
    }

    /// Utilization (0.0 to 1.0).
    public var utilization: Double {
        guard limit > 0 else { return 0 }
        return Double(inFlight) / Double(limit)
    }

    /// Whether at capacity.
    public var atCapacity: Bool {
        inFlight >= limit
    }

    /// Pressure level based on utilization and waiting.
    public var pressure: PressureLevel {
        if waiting > limit {
            return .critical
        } else if atCapacity && waiting > 0 {
            return .high
        } else if utilization > 0.7 {
            return .medium
        } else {
            return .low
        }
    }
}

/// Pressure level for concurrency.
public enum PressureLevel: String, Sendable, Codable, CaseIterable {
    case low
    case medium
    case high
    case critical

    public var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}
