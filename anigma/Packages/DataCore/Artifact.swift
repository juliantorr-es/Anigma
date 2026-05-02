import Foundation

public struct Artifact: Identifiable, Codable, Sendable {
    public let id: String
    public let type: ArtifactType
    public let contentHash: String
    public let metadata: [String: String]

    public init(id: String, type: ArtifactType, contentHash: String, metadata: [String: String] = [:]) {
        self.id = id
        self.type = type
        self.contentHash = contentHash
        self.metadata = metadata
    }
}

public enum ArtifactType: String, Codable, Sendable {
    case raw
    case tabularIR
    case schemaIR
    case graphIR
    case timelineIR
    case profile
    case viewSpec
    case render
    case change
    case transform
}

public struct CoreReceipt: Identifiable, Codable, Sendable {
    public let id: String
    public let timestamp: Date
    public let action: String
    public let actor: String
    public let surface: String
    public let details: String?
    public let inputArtifacts: [String]
    public let outputArtifacts: [String]

    public init(id: String, timestamp: Date, action: String, actor: String, surface: String, details: String? = nil, inputArtifacts: [String] = [], outputArtifacts: [String] = []) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
        self.actor = actor
        self.surface = surface
        self.details = details
        self.inputArtifacts = inputArtifacts
        self.outputArtifacts = outputArtifacts
    }
}
