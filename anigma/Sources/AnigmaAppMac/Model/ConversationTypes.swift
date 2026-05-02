//
//  ConversationTypes.swift
//  AnigmaAppMac
//
//  Unified conversation message and snapshot types.
//

import Foundation
import ContractsCore

public struct ConversationMessage: Codable, Sendable, Identifiable {
    public enum Role: String, Codable, Sendable {
        case user, assistant, system, tool
    }
    
    public let id: String
    public let role: Role
    public let content: String
    public let createdAt: Date
    public let provenance: AnswerProvenanceRecord?
    public let provenanceId: String?
    public let projectId: String?
    public let replayMode: String?
    public let deterministicRun: Bool?
    public let confidence: Double?
    public let sourceCount: Int?

    public init(
        id: String = UUID().uuidString,
        role: Role,
        content: String,
        createdAt: Date = Date(),
        provenance: AnswerProvenanceRecord? = nil,
        provenanceId: String? = nil,
        projectId: String? = nil,
        replayMode: String? = nil,
        deterministicRun: Bool? = nil,
        confidence: Double? = nil,
        sourceCount: Int? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.provenance = provenance
        self.provenanceId = provenanceId ?? provenance?.id
        self.projectId = projectId ?? provenance?.projectId
        self.replayMode = replayMode ?? provenance?.replay.mode
        self.deterministicRun = deterministicRun ?? provenance?.replay.deterministic
        self.confidence = confidence ?? provenance?.confidence
        self.sourceCount = sourceCount ?? provenance?.sources.count
    }

    public var timestamp: Date {
        createdAt
    }

    public var sources: [AnswerProvenanceSource] {
        provenance?.sources ?? []
    }
}

public struct AssistantConversationSnapshot: Codable, Sendable {
    public let history: [ConversationMessage]
    public let latestContextSummary: AssistantConversationContextSnapshot?
    public let messageCount: Int
    public let updatedAt: Date
    
    public init(history: [ConversationMessage], latestContextSummary: AssistantConversationContextSnapshot? = nil, messageCount: Int, updatedAt: Date = Date()) {
        self.history = history
        self.latestContextSummary = latestContextSummary
        self.messageCount = messageCount
        self.updatedAt = updatedAt
    }
}

public struct AssistantConversationContextSnapshot: Codable, Sendable, Identifiable {
    public let id: String
    public let summary: String
    public let timestamp: Date
    
    public init(id: String = UUID().uuidString, summary: String, timestamp: Date = Date()) {
        self.id = id
        self.summary = summary
        self.timestamp = timestamp
    }
}

// MARK: - Data Quality Conformance

extension AssistantConversationContextSnapshot: DataQualityInspectable {
    public var dataProductKind: DataProductKind { .summary }

    public var dataProductIdentifier: String { id }

    public var dataProductCreatedAt: Date { timestamp }

    public var dataProductUpdatedAt: Date? { nil }

    public var dataProductLineage: DataProductLineage? { nil }

    public var dataProductPayloadReferences: [String] {
        [id]
    }

    public var dataProductSummaryFingerprint: String? {
        summary.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var dataProductEmbeddingModel: String? { nil }

    public var dataProductEmbeddingGeneratedAt: Date? { nil }

    public var dataProductSourceFidelity: Double? { nil }

    public var dataProductHandoffState: String? { nil }
}
