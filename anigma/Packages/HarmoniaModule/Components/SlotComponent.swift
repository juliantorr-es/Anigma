//
//  SlotComponent.swift
//  HarmoniaModule
//
//  Represents a concurrency slot for a specific model kind.
//  Migrated from: Harmonia/OrchestrumCore/ECS/Components.swift
//

import AnigmaCore
@preconcurrency import Foundation

/// Represents a concurrency slot for a specific model kind.
public struct SlotComponent: Component, Codable {
    public let modelKind: String  // Changed from ModelKind enum to String for portability
    public var status: SlotStatus
    public var acquiredAt: Date?
    public var requestId: String?

    public init(
        modelKind: String,
        status: SlotStatus = .available,
        acquiredAt: Date? = nil,
        requestId: String? = nil
    ) {
        self.modelKind = modelKind
        self.status = status
        self.acquiredAt = acquiredAt
        self.requestId = requestId
    }
}

/// Status of a concurrency slot.
public enum SlotStatus: String, Sendable, Codable {
    case available
    case occupied
    case releasing
}
