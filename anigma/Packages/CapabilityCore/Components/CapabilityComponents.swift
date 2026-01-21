//
//  CapabilityComponents.swift
//  CapabilityCore
//
//  ECS components for capability system integration.
//

import AnigmaCore
import AnigmaPrimitives
import Foundation

/// Component marking an entity as requiring a specific capability.
public struct CapabilityRequestComponent: Component, Codable, Sendable {
    public let capabilityId: String
    public let requestedAt: Date
    public let priority: Int
    public let context: [String: String]

    public init(capabilityId: String, priority: Int = 0, context: [String: String] = [:]) {
        self.capabilityId = capabilityId
        self.requestedAt = Date()
        self.priority = priority
        self.context = context
    }
}

/// Component storing the result of a capability operation.
public struct CapabilityResultComponent: Component, Codable, Sendable {
    public let capabilityId: String
    public let success: Bool
    public let resultHash: String?
    public let error: String?
    public let completedAt: Date
    public let metadata: [String: String]

    public init(
        capabilityId: String,
        success: Bool,
        resultHash: String? = nil,
        error: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.capabilityId = capabilityId
        self.success = success
        self.resultHash = resultHash
        self.error = error
        self.completedAt = Date()
        self.metadata = metadata
    }
}

/// Component storing capability provider metadata.
public struct CapabilityProviderComponent: Component, Codable, Sendable {
    public let providerId: String
    public let capabilityIds: [String]
    public let registeredAt: Date
    public let platform: String

    public init(providerId: String, capabilityIds: [String], platform: String) {
        self.providerId = providerId
        self.capabilityIds = capabilityIds
        self.registeredAt = Date()
        self.platform = platform
    }
}
