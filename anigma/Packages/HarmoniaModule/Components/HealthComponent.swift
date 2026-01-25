//
//  HealthComponent.swift
//  HarmoniaModule
//
//  Health status of a subsystem.
//  Migrated from: Harmonia/OrchestrumCore/ECS/Components.swift
//

import AnigmaCore
@preconcurrency import Foundation

/// Health status of a subsystem.
public struct HealthComponent: Component, Codable {
    public let subsystem: String
    public var status: HealthStatus
    public var message: String?
    public var lastCheck: Date
    public var consecutiveFailures: Int

    public init(
        subsystem: String,
        status: HealthStatus = .healthy,
        message: String? = nil,
        lastCheck: Date = Date(),
        consecutiveFailures: Int = 0
    ) {
        self.subsystem = subsystem
        self.status = status
        self.message = message
        self.lastCheck = lastCheck
        self.consecutiveFailures = consecutiveFailures
    }
}

/// Health status values.
public enum HealthStatus: String, Sendable, Codable, CaseIterable {
    case healthy
    case degraded
    case unhealthy
    case unknown

    public var color: String {
        switch self {
        case .healthy: return "green"
        case .degraded: return "yellow"
        case .unhealthy: return "red"
        case .unknown: return "gray"
        }
    }
}
