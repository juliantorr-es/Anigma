// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import Foundation
import AnigmaPrimitives

public struct ServiceDescriptor: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let version: String
    public let capabilities: [ServiceCapability]
    public let healthStatus: HealthStatus
    public let lastHealthCheck: Date?

    public init(
        id: String,
        name: String,
        version: String,
        capabilities: [ServiceCapability],
        healthStatus: HealthStatus = .unknown,
        lastHealthCheck: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.capabilities = capabilities
        self.healthStatus = healthStatus
        self.lastHealthCheck = lastHealthCheck
    }
}

public struct ServiceCapability: Codable, Sendable, Hashable {
    public let action: String
    public let inputType: String
    public let outputType: String
    public let timeout: TimeInterval

    public init(
        action: String,
        inputType: String,
        outputType: String,
        timeout: TimeInterval = 30.0
    ) {
        self.action = action
        self.inputType = inputType
        self.outputType = outputType
        self.timeout = timeout
    }
}

/// Uses the canonical HealthStatus from AnigmaPrimitives for consistency.
public typealias HealthStatus = AnigmaPrimitives.HealthStatus
