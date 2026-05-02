//
//  MemoryTypes.swift
//  HarmoniaMemory
//
//  Tri-memory architecture types: short-term, long-term, persistent.
//  Migrated from HarmoniaModule - Pure value types with zero side effects.
//

import Foundation
import HarmoniaV2Core

// MARK: - Memory Types

/// Types of memory in the tri-memory architecture.
public enum MemoryType: String, Sendable, Codable, CaseIterable {
    /// Session-bounded, automatically expired, tied to specific task runs.
    case shortTerm

    /// Tenant-scoped knowledge that may change, subject to laws.
    case longTerm

    /// Only changed via releases: control catalogs, schemas, rules.
    case persistent
}

/// Sensitivity levels for memory items.
public enum DataSensitivity: String, Sendable, Codable, CaseIterable {
    case public_
    case internal_
    case confidential
    case restricted
    case ferpa
    case hipaaAdjacent
}

// MARK: - Memory Item Protocol

/// A memory item in the tri-memory system.
public protocol TriMemoryItem: Sendable, Codable {
    var id: String { get }
    var memoryType: MemoryType { get }
    var tenantId: String { get }
    var createdAt: Date { get }
    var accessedAt: Date { get }
    var sensitivity: DataSensitivity { get }
}

// MARK: - Short-Term Memory

/// Short-term memory item (session-bounded).
public struct ShortTermMemory: TriMemoryItem, Sendable, Codable {
    public let id: String
    public let memoryType: MemoryType
    public let tenantId: String
    public let sessionId: String
    public let createdAt: Date
    public var accessedAt: Date
    public let expiresAt: Date
    public let sensitivity: DataSensitivity

    /// Content type identifier.
    public let contentType: ShortTermContentType

    /// The actual content (encoded).
    public let content: Data

    /// Source of this memory.
    public let source: ShortTermSource

    public init(
        id: String = UUID().uuidString,
        tenantId: String,
        sessionId: String,
        contentType: ShortTermContentType,
        content: Data,
        source: ShortTermSource,
        sensitivity: DataSensitivity = .internal_,
        ttlSeconds: TimeInterval = 3600  // 1 hour default
    ) {
        self.id = id
        self.memoryType = .shortTerm
        self.tenantId = tenantId
        self.sessionId = sessionId
        self.contentType = contentType
        self.content = content
        self.source = source
        self.sensitivity = sensitivity
        self.createdAt = Date()
        self.accessedAt = Date()
        self.expiresAt = Date().addingTimeInterval(ttlSeconds)
    }

    public var isExpired: Bool {
        Date() > expiresAt
    }
}

/// Types of short-term content.
public enum ShortTermContentType: String, Sendable, Codable {
    case interactionHistory
    case transientArtifact
    case draftDocument
    case intermediateResult
    case reasoningTrace
    case workingContext
}

/// Sources of short-term memory.
public enum ShortTermSource: String, Sendable, Codable {
    case userInteraction
    case agentReasoning
    case toolExecution
    case pipelineStep
    case scratchpad
}

// MARK: - Vector Memory

/// Vector representation of memory for semantic search
public struct VectorMemoryItem: Sendable, Codable {
    public let id: String
    public let embedding: [Float]
    public let text: String
    public let metadata: [String: String]
    public let timestamp: Date
    
    public init(
        id: String = UUID().uuidString,
        embedding: [Float],
        text: String,
        metadata: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.embedding = embedding
        self.text = text
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

/// Result from vector similarity search
public struct VectorSearchResult: Sendable, Codable {
    public let item: VectorMemoryItem
    public let similarity: Float
    public let rank: Int
    
    public init(item: VectorMemoryItem, similarity: Float, rank: Int) {
        self.item = item
        self.similarity = similarity
        self.rank = rank
    }
}

// MARK: - Memory Query

/// Query for retrieving memory items
public struct MemoryQuery: Sendable {
    public let sessionId: String?
    public let tenantId: String?
    public let contentType: ShortTermContentType?
    public let maxAge: TimeInterval?
    public let limit: Int
    
    public init(
        sessionId: String? = nil,
        tenantId: String? = nil,
        contentType: ShortTermContentType? = nil,
        maxAge: TimeInterval? = nil,
        limit: Int = 100
    ) {
        self.sessionId = sessionId
        self.tenantId = tenantId
        self.contentType = contentType
        self.maxAge = maxAge
        self.limit = limit
    }
}
