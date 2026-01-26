import Foundation
import Foundation
import AnigmaSystemSpine

public struct AIModel: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let family: String
    public let format: String
    public let quantization: String?
    public let sizeBytes: Int64
    public let lastUsed: Date?
    public let isValidated: Bool

    public init(id: String, name: String, family: String, format: String, quantization: String?, sizeBytes: Int64, lastUsed: Date?, isValidated: Bool) {
        self.id = id
        self.name = name
        self.family = family
        self.format = format
        self.quantization = quantization
        self.sizeBytes = sizeBytes
        self.lastUsed = lastUsed
        self.isValidated = isValidated
    }
}

public struct AIProvider: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let isEnabled: Bool
    public let policyPosture: String
    public let lastVerified: Date?

    public init(id: String, name: String, isEnabled: Bool, policyPosture: String, lastVerified: Date?) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.policyPosture = policyPosture
        self.lastVerified = lastVerified
    }
}

public struct AITool: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let path: String
    public let fingerprint: String
    public let isApproved: Bool

    public init(id: String, name: String, path: String, fingerprint: String, isApproved: Bool) {
        self.id = id
        self.name = name
        self.path = path
        self.fingerprint = fingerprint
        self.isApproved = isApproved
    }
}

public struct AIBenchmark: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let type: BenchmarkType
    public let result: String?
    public let receiptRef: String?

    public enum BenchmarkType: String, Codable, Sendable {
        case performance
        case capability
    }

    public init(id: String, name: String, type: BenchmarkType, result: String?, receiptRef: String?) {
        self.id = id
        self.name = name
        self.type = type
        self.result = result
        self.receiptRef = receiptRef
    }
}

public struct AIAgent: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let capabilities: [AgentCapability]
    public let isEnabled: Bool
    public let createdAt: Date
    public let lastUsed: Date?
    public let config: [String: String]
    
    public init(id: String, name: String, description: String, capabilities: [AgentCapability], isEnabled: Bool = true, createdAt: Date = Date(), lastUsed: Date? = nil, config: [String: String] = [:]) {
        self.id = id
        self.name = name
        self.description = description
        self.capabilities = capabilities
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.lastUsed = lastUsed
        self.config = config
    }
}
