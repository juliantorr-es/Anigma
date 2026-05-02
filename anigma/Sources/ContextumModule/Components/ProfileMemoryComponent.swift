//
//  ProfileMemoryComponent.swift
//  ContextumModule
//
//  Evidence-backed profile memory component for durable user/workspace facts
//

import Foundation
import ContractsCore

/// Profile memory fact with evidence backing
public struct ProfileMemoryComponent: Codable, Sendable, Identifiable {
    public let id: String
    public let entityId: String
    public let entityType: ProfileMemoryEntityType
    public let factType: ProfileMemoryFactType
    public let factValue: String
    public let factData: [String: String]
    public let confidence: Double
    public let sourceCount: Int
    public let firstObservedAt: Date
    public let lastObservedAt: Date
    public let lastUpdatedAt: Date
    public let isActive: Bool
    public let conflictStatus: ProfileMemoryConflictStatus
    public let metadata: [String: String]

    public init(
        id: String = UUID().uuidString,
        entityId: String,
        entityType: ProfileMemoryEntityType,
        factType: ProfileMemoryFactType,
        factValue: String,
        factData: [String: String] = [:],
        confidence: Double,
        sourceCount: Int,
        firstObservedAt: Date = Date(),
        lastObservedAt: Date = Date(),
        lastUpdatedAt: Date = Date(),
        isActive: Bool = true,
        conflictStatus: ProfileMemoryConflictStatus = .none,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.entityId = entityId
        self.entityType = entityType
        self.factType = factType
        self.factValue = factValue
        self.factData = factData
        self.confidence = confidence
        self.sourceCount = sourceCount
        self.firstObservedAt = firstObservedAt
        self.lastObservedAt = lastObservedAt
        self.lastUpdatedAt = lastUpdatedAt
        self.isActive = isActive
        self.conflictStatus = conflictStatus
        self.metadata = metadata
    }
}

/// Profile memory entity types
public enum ProfileMemoryEntityType: String, Codable, Sendable, CaseIterable {
    case user
    case workspace
    case project
    case person
    case organization
    case location
    case tool
    case system
    case preference
    case policy
    case custom
}

/// Profile memory fact types
public enum ProfileMemoryFactType: String, Codable, Sendable, CaseIterable {
    case preference
    case belief
    case relationship
    case affiliation
    case skill
    case interest
    case habit
    case goal
    case constraint
    case capability
    case custom
}

/// Profile memory conflict status
public enum ProfileMemoryConflictStatus: String, Codable, Sendable, CaseIterable {
    case none
    case unresolved
    case resolved
    case deprecated
}

/// Profile memory evidence link - connects facts to supporting evidence
public struct ProfileMemoryEvidenceLink: Codable, Sendable, Identifiable {
    public let id: String
    public let profileMemoryId: String
    public let sourceId: String
    public let chunkId: String?
    public let evidenceType: ProfileMemoryEvidenceType
    public let confidenceContribution: Double
    public let createdAt: Date
    public let metadata: [String: String]

    public init(
        id: String = UUID().uuidString,
        profileMemoryId: String,
        sourceId: String,
        chunkId: String? = nil,
        evidenceType: ProfileMemoryEvidenceType,
        confidenceContribution: Double,
        createdAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.profileMemoryId = profileMemoryId
        self.sourceId = sourceId
        self.chunkId = chunkId
        self.evidenceType = evidenceType
        self.confidenceContribution = confidenceContribution
        self.createdAt = createdAt
        self.metadata = metadata
    }
}

/// Profile memory evidence types
public enum ProfileMemoryEvidenceType: String, Codable, Sendable, CaseIterable {
    case directObservation
    case explicitStatement
    case inferredFromBehavior
    case derivedFromMultipleSources
    case manualAssertion
    case systemDefault
}

// MARK: - Profile Memory Update Request

public struct ProfileMemoryUpdateRequest: Codable, Sendable {
    public var factValue: String?
    public var factData: [String: String]?
    public var confidenceDelta: Double?
    public var conflictStatus: ProfileMemoryConflictStatus?
    public var isActive: Bool?
    public var metadata: [String: String]?

    public init(
        factValue: String? = nil,
        factData: [String: String]? = nil,
        confidenceDelta: Double? = nil,
        conflictStatus: ProfileMemoryConflictStatus? = nil,
        isActive: Bool? = nil,
        metadata: [String: String]? = nil
    ) {
        self.factValue = factValue
        self.factData = factData
        self.confidenceDelta = confidenceDelta
        self.conflictStatus = conflictStatus
        self.isActive = isActive
        self.metadata = metadata
    }
}

// MARK: - Profile Memory Query

public struct ProfileMemoryQuery: Codable, Sendable {
    public let entityId: String?
    public let entityType: ProfileMemoryEntityType?
    public let factType: ProfileMemoryFactType?
    public let searchText: String?
    public let minConfidence: Double?
    public let includeInactive: Bool
    public let limit: Int
    public let offset: Int

    public init(
        entityId: String? = nil,
        entityType: ProfileMemoryEntityType? = nil,
        factType: ProfileMemoryFactType? = nil,
        searchText: String? = nil,
        minConfidence: Double? = nil,
        includeInactive: Bool = false,
        limit: Int = 50,
        offset: Int = 0
    ) {
        self.entityId = entityId
        self.entityType = entityType
        self.factType = factType
        self.searchText = searchText
        self.minConfidence = minConfidence
        self.includeInactive = includeInactive
        self.limit = limit
        self.offset = offset
    }
}

// MARK: - Profile Memory with Evidence

public struct ProfileMemoryWithEvidence: Codable, Sendable {
    public let memory: ProfileMemoryComponent
    public let evidence: [ProfileMemoryEvidenceLink]
    public let sources: [ContextSourceComponent]
    public let chunks: [ChunkComponent]

    public init(
        memory: ProfileMemoryComponent,
        evidence: [ProfileMemoryEvidenceLink],
        sources: [ContextSourceComponent],
        chunks: [ChunkComponent]
    ) {
        self.memory = memory
        self.evidence = evidence
        self.sources = sources
        self.chunks = chunks
    }
}
