//
//  TriMemoryArchitecture.swift
//  HarmoniaModule
//
//  Implements the Titans-inspired tri-memory architecture:
//  - Short-term: Session-bounded, throwaway
//  - Long-term: Editable, versioned, subject to legal retention
//  - Persistent: Versioned code/models/rules, changed via governed releases
//
//  This formalizes memory types as constitutional law, not implicit behavior.
//

import Foundation
import AnigmaCore

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

/// A memory item in the tri-memory system.
public protocol MemoryItem: Sendable, Codable {
    var id: String { get }
    var memoryType: MemoryType { get }
    var tenantId: String { get }
    var createdAt: Date { get }
    var accessedAt: Date { get }
    var sensitivity: DataSensitivity { get }
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

// MARK: - Short-Term Memory

/// Short-term memory item (session-bounded).
public struct ShortTermMemory: MemoryItem {
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

    private enum CodingKeys: String, CodingKey {
        case id, memoryType, tenantId, sessionId, createdAt, accessedAt, expiresAt, sensitivity, contentType, content, source
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.memoryType = try container.decode(MemoryType.self, forKey: .memoryType)
        self.tenantId = try container.decode(String.self, forKey: .tenantId)
        self.sessionId = try container.decode(String.self, forKey: .sessionId)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.accessedAt = try container.decode(Date.self, forKey: .accessedAt)
        self.expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        self.sensitivity = try container.decode(DataSensitivity.self, forKey: .sensitivity)
        self.contentType = try container.decode(ShortTermContentType.self, forKey: .contentType)
        self.content = try container.decode(Data.self, forKey: .content)
        self.source = try container.decode(ShortTermSource.self, forKey: .source)
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

// MARK: - Long-Term Memory

/// Long-term memory item (persistent but mutable under governance).
public struct LongTermMemory: MemoryItem {
    public let id: String
    public let memoryType: MemoryType
    public let tenantId: String
    public let createdAt: Date
    public var accessedAt: Date
    public var modifiedAt: Date
    public let sensitivity: DataSensitivity

    /// Content type identifier.
    public let contentType: LongTermContentType

    /// Version info.
    public let version: Int
    public let previousVersionId: String?

    /// The actual content (encoded).
    public let content: Data

    /// Retention policy.
    public let retentionPolicy: RetentionPolicy

    /// Legal holds affecting this memory.
    public var legalHolds: [String]

    /// Source/provenance info.
    public let source: LongTermSource

    public init(
        id: String = UUID().uuidString,
        tenantId: String,
        contentType: LongTermContentType,
        content: Data,
        sensitivity: DataSensitivity,
        retentionPolicy: RetentionPolicy,
        source: LongTermSource,
        version: Int = 1,
        previousVersionId: String? = nil
    ) {
        self.id = id
        self.memoryType = .longTerm
        self.tenantId = tenantId
        self.contentType = contentType
        self.content = content
        self.sensitivity = sensitivity
        self.retentionPolicy = retentionPolicy
        self.source = source
        self.version = version
        self.previousVersionId = previousVersionId
        self.createdAt = Date()
        self.accessedAt = Date()
        self.modifiedAt = Date()
        self.legalHolds = []
    }

    /// Whether this memory can be deleted (respecting legal holds).
    public var canDelete: Bool {
        legalHolds.isEmpty && retentionPolicy.canDeleteNow
    }

    private enum CodingKeys: String, CodingKey {
        case id, memoryType, tenantId, createdAt, accessedAt, modifiedAt, sensitivity, contentType, version, previousVersionId, content, retentionPolicy, legalHolds, source
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.memoryType = try container.decode(MemoryType.self, forKey: .memoryType)
        self.tenantId = try container.decode(String.self, forKey: .tenantId)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.accessedAt = try container.decode(Date.self, forKey: .accessedAt)
        self.modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
        self.sensitivity = try container.decode(DataSensitivity.self, forKey: .sensitivity)
        self.contentType = try container.decode(LongTermContentType.self, forKey: .contentType)
        self.version = try container.decode(Int.self, forKey: .version)
        self.previousVersionId = try container.decodeIfPresent(String.self, forKey: .previousVersionId)
        self.content = try container.decode(Data.self, forKey: .content)
        self.retentionPolicy = try container.decode(RetentionPolicy.self, forKey: .retentionPolicy)
        self.legalHolds = try container.decode([String].self, forKey: .legalHolds)
        self.source = try container.decode(LongTermSource.self, forKey: .source)
    }
}

/// Types of long-term content.
public enum LongTermContentType: String, Sendable, Codable {
    case policyDocument
    case procedureDocument
    case caseHistory
    case studentRecord
    case accommodationRecord
    case transcriptData
    case institutionalKnowledge
    case learnedPattern
    case federatedAggregate
}

/// Sources of long-term memory.
public enum LongTermSource: String, Sendable, Codable {
    case documentImport
    case userContribution
    case governedUpdate
    case federatedSync
    case systemGenerated
    case curatedExemplar
}

/// Reasons for retention.
public enum RetentionReason: String, Sendable, Codable {
    case ferpaCompliance
    case institutionalPolicy
    case legalRequirement
    case auditTrail
    case businessNeed
    case userRequest
    case activeUse
}

// MARK: - Persistent Memory

/// Persistent memory item (only changed via governed releases).
public struct PersistentMemory: MemoryItem {
    public let id: String
    public let memoryType: MemoryType
    public let tenantId: String
    public let createdAt: Date
    public var accessedAt: Date
    public let sensitivity: DataSensitivity

    /// Content type identifier.
    public let contentType: PersistentContentType

    /// Version (tied to release).
    public let version: String
    public let releaseId: String

    /// The content (often a reference to code/config).
    public let contentReference: String

    /// Hash for integrity verification.
    public let contentHash: String

    public init(
        id: String = UUID().uuidString,
        tenantId: String,
        contentType: PersistentContentType,
        version: String,
        releaseId: String,
        contentReference: String,
        contentHash: String,
        sensitivity: DataSensitivity = .internal_
    ) {
        self.id = id
        self.memoryType = .persistent
        self.tenantId = tenantId
        self.contentType = contentType
        self.version = version
        self.releaseId = releaseId
        self.contentReference = contentReference
        self.contentHash = contentHash
        self.sensitivity = sensitivity
        self.createdAt = Date()
        self.accessedAt = Date()
    }

    private enum CodingKeys: String, CodingKey {
        case id, memoryType, tenantId, createdAt, accessedAt, sensitivity, contentType, version, releaseId, contentReference, contentHash
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.memoryType = try container.decode(MemoryType.self, forKey: .memoryType)
        self.tenantId = try container.decode(String.self, forKey: .tenantId)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.accessedAt = try container.decode(Date.self, forKey: .accessedAt)
        self.sensitivity = try container.decode(DataSensitivity.self, forKey: .sensitivity)
        self.contentType = try container.decode(PersistentContentType.self, forKey: .contentType)
        self.version = try container.decode(String.self, forKey: .version)
        self.releaseId = try container.decode(String.self, forKey: .releaseId)
        self.contentReference = try container.decode(String.self, forKey: .contentReference)
        self.contentHash = try container.decode(String.self, forKey: .contentHash)
    }
}

/// Types of persistent content.
public enum PersistentContentType: String, Sendable, Codable {
    case controlCatalog
    case scenarioTemplate
    case metaPuzzle
    case ecsSchema
    case automationRuleLanguage
    case updatePolicy
    case inferencePlanePolicy
    case charterTemplate
    case modelWeights
    case symbolicRules
}

// MARK: - Tri-Memory Service

/// Service managing the tri-memory architecture.
public actor TriMemoryService {
    /// Short-term memory by session.
    private var shortTermBySession: [String: [ShortTermMemory]] = [:]

    /// Long-term memory by tenant.
    private var longTermByTenant: [String: [LongTermMemory]] = [:]

    /// Persistent memory (global, versioned).
    private var persistentMemory: [String: PersistentMemory] = [:]

    /// Access log for audit.
    private var accessLog: [MemoryAccessRecord] = []

    /// Configuration.
    private let config: TriMemoryConfig

    public init(config: TriMemoryConfig = .default) {
        self.config = config
    }

    // MARK: - Short-Term Operations

    /// Stores short-term memory.
    public func storeShortTerm(_ memory: ShortTermMemory) {
        var sessionMemory = shortTermBySession[memory.sessionId] ?? []
        sessionMemory.append(memory)
        shortTermBySession[memory.sessionId] = sessionMemory

        logAccess(.store, memory: memory)
    }

    /// Retrieves short-term memory.
    public func getShortTerm(
        sessionId: String,
        contentType: ShortTermContentType? = nil
    ) -> [ShortTermMemory] {
        let memories = shortTermBySession[sessionId] ?? []
        return memories.filter { memory in
            guard !memory.isExpired else { return false }
            if let type = contentType {
                return memory.contentType == type
            }
            return true
        }
    }

    /// Expires a session's short-term memory.
    public func expireSession(_ sessionId: String) {
        shortTermBySession.removeValue(forKey: sessionId)
    }

    /// Cleans up expired short-term memory.
    public func cleanupExpiredShortTerm() -> Int {
        var removed = 0
        for (sessionId, memories) in shortTermBySession {
            let active = memories.filter { !$0.isExpired }
            removed += memories.count - active.count
            if active.isEmpty {
                shortTermBySession.removeValue(forKey: sessionId)
            } else {
                shortTermBySession[sessionId] = active
            }
        }
        return removed
    }

    // MARK: - Long-Term Operations

    /// Stores long-term memory (with governance check).
    public func storeLongTerm(
        _ memory: LongTermMemory,
        governance: GovernanceDecision
    ) -> LongTermStoreResult {
        guard governance.isApproved else {
            return .denied(reason: governance.reason ?? "Governance denied")
        }

        var tenantMemory = longTermByTenant[memory.tenantId] ?? []
        tenantMemory.append(memory)
        longTermByTenant[memory.tenantId] = tenantMemory

        logAccess(.store, memory: memory)
        return .stored(id: memory.id)
    }

    /// Retrieves long-term memory.
    public func getLongTerm(
        tenantId: String,
        contentType: LongTermContentType? = nil,
        maxSensitivity: DataSensitivity? = nil
    ) -> [LongTermMemory] {
        let memories = longTermByTenant[tenantId] ?? []
        return memories.filter { memory in
            if let type = contentType, memory.contentType != type {
                return false
            }
            if let maxSens = maxSensitivity {
                if sensitivityLevel(memory.sensitivity) > sensitivityLevel(maxSens) {
                    return false
                }
            }
            return true
        }
    }

    /// Updates long-term memory (creates new version).
    public func updateLongTerm(
        id: String,
        tenantId: String,
        newContent: Data,
        governance: GovernanceDecision
    ) -> LongTermStoreResult {
        guard governance.isApproved else {
            return .denied(reason: governance.reason ?? "Governance denied")
        }

        guard var memories = longTermByTenant[tenantId],
              let index = memories.firstIndex(where: { $0.id == id }) else {
            return .denied(reason: "Memory not found")
        }

        let old = memories[index]
        let newVersion = LongTermMemory(
            id: UUID().uuidString,
            tenantId: tenantId,
            contentType: old.contentType,
            content: newContent,
            sensitivity: old.sensitivity,
            retentionPolicy: old.retentionPolicy,
            source: .governedUpdate,
            version: old.version + 1,
            previousVersionId: old.id
        )

        memories.append(newVersion)
        longTermByTenant[tenantId] = memories

        logAccess(.update, memory: newVersion)
        return .stored(id: newVersion.id)
    }

    /// Applies a legal hold to long-term memory.
    public func applyLegalHold(
        memoryId: String,
        tenantId: String,
        holdId: String
    ) -> Bool {
        guard var memories = longTermByTenant[tenantId],
              let index = memories.firstIndex(where: { $0.id == memoryId }) else {
            return false
        }

        var memory = memories[index]
        memory.legalHolds.append(holdId)
        memories[index] = memory
        longTermByTenant[tenantId] = memories

        logAccess(.legalHold, memory: memory)
        return true
    }

    // MARK: - Persistent Operations

    /// Registers persistent memory (release-gated).
    public func registerPersistent(
        _ memory: PersistentMemory,
        releaseApproval: ReleaseApproval
    ) -> Bool {
        guard releaseApproval.isApproved else {
            return false
        }

        persistentMemory[memory.id] = memory
        logAccess(.store, memory: memory)
        return true
    }

    /// Gets persistent memory.
    public func getPersistent(
        contentType: PersistentContentType
    ) -> [PersistentMemory] {
        persistentMemory.values.filter { $0.contentType == contentType }
    }

    /// Verifies integrity of persistent memory.
    public func verifyIntegrity(memoryId: String) -> IntegrityCheckResult {
        guard let memory = persistentMemory[memoryId] else {
            return .notFound
        }

        // In production: recompute hash and compare
        // For now, assume valid
        return .valid(contentHash: memory.contentHash)
    }

    // MARK: - Cross-Memory Queries

    /// Gets all memory for a subject (e.g., for FERPA requests).
    public func getAllMemoryForSubject(
        subjectId: String,
        tenantId: String
    ) -> SubjectMemoryBundle {
        // This would search across memory types for references to the subject
        // For now, return empty bundle
        SubjectMemoryBundle(
            subjectId: subjectId,
            shortTermCount: 0,
            longTermItems: [],
            hasLegalHolds: false
        )
    }

    // MARK: - Private Helpers

    private func logAccess<T: MemoryItem>(_ operation: MemoryOperation, memory: T) {
        let record = MemoryAccessRecord(
            memoryId: memory.id,
            memoryType: memory.memoryType,
            operation: operation,
            tenantId: memory.tenantId,
            timestamp: Date()
        )
        accessLog.append(record)

        // Prune old logs
        if accessLog.count > 10000 {
            accessLog.removeFirst(1000)
        }
    }

    private func sensitivityLevel(_ sensitivity: DataSensitivity) -> Int {
        switch sensitivity {
        case .public_: return 0
        case .internal_: return 1
        case .confidential: return 2
        case .restricted: return 3
        case .ferpa: return 4
        case .hipaaAdjacent: return 5
        }
    }
}

// MARK: - Supporting Types

/// Configuration for tri-memory service.
public struct TriMemoryConfig: Sendable {
    public var shortTermDefaultTTL: TimeInterval
    public var longTermDefaultRetentionYears: Int
    public var enableAccessLogging: Bool
    public var maxShortTermPerSession: Int

    public init(
        shortTermDefaultTTL: TimeInterval = 3600,
        longTermDefaultRetentionYears: Int = 7,
        enableAccessLogging: Bool = true,
        maxShortTermPerSession: Int = 100
    ) {
        self.shortTermDefaultTTL = shortTermDefaultTTL
        self.longTermDefaultRetentionYears = longTermDefaultRetentionYears
        self.enableAccessLogging = enableAccessLogging
        self.maxShortTermPerSession = maxShortTermPerSession
    }

    public static let `default` = TriMemoryConfig()
}

/// Governance decision for memory operations.
public struct GovernanceDecision: Sendable {
    public let isApproved: Bool
    public let reason: String?
    public let approvedBy: String?

    public init(isApproved: Bool, reason: String? = nil, approvedBy: String? = nil) {
        self.isApproved = isApproved
        self.reason = reason
        self.approvedBy = approvedBy
    }

    public static let approved = GovernanceDecision(isApproved: true)
    public static func denied(_ reason: String) -> GovernanceDecision {
        GovernanceDecision(isApproved: false, reason: reason)
    }
}

/// Release approval for persistent memory.
public struct ReleaseApproval: Sendable {
    public let isApproved: Bool
    public let releaseId: String
    public let approvers: [String]

    public init(isApproved: Bool, releaseId: String, approvers: [String]) {
        self.isApproved = isApproved
        self.releaseId = releaseId
        self.approvers = approvers
    }
}

/// Result of long-term memory store.
public enum LongTermStoreResult: Sendable {
    case stored(id: String)
    case denied(reason: String)
    case conflict(existingId: String)
}

/// Result of integrity check.
public enum IntegrityCheckResult: Sendable {
    case valid(contentHash: String)
    case invalid(expected: String, actual: String)
    case notFound
}

/// Record of memory access.
public struct MemoryAccessRecord: Sendable, Codable {
    public let memoryId: String
    public let memoryType: MemoryType
    public let operation: MemoryOperation
    public let tenantId: String
    public let timestamp: Date
}

/// Memory operations.
public enum MemoryOperation: String, Sendable, Codable {
    case store
    case retrieve
    case update
    case delete
    case legalHold
    case export
}

/// Bundle of memory for a subject.
public struct SubjectMemoryBundle: Sendable {
    public let subjectId: String
    public let shortTermCount: Int
    public let longTermItems: [LongTermMemory]
    public let hasLegalHolds: Bool
}

// MARK: - Memory Context Builder

/// Builds context from tri-memory for inference.
public actor MemoryContextBuilder {
    private let triMemory: TriMemoryService

    public init(triMemory: TriMemoryService) {
        self.triMemory = triMemory
    }

    /// Builds inference context from memory layers.
    public func buildContext(
        sessionId: String,
        tenantId: String,
        task: String,
        maxTokens: Int = 16000
    ) async -> BuiltMemoryContext {
        var contextParts: [ContextPart] = []
        var usedTokens = 0

        // 1. Get relevant persistent memory (skills, rules)
        let persistent = await triMemory.getPersistent(contentType: .symbolicRules)
        for memory in persistent.prefix(5) {
            let tokens = estimateTokens(memory.contentReference)
            if usedTokens + tokens < maxTokens {
                contextParts.append(ContextPart(
                    source: .persistent,
                    content: memory.contentReference,
                    priority: .high
                ))
                usedTokens += tokens
            }
        }

        // 2. Get relevant long-term memory (institutional knowledge)
        let longTerm = await triMemory.getLongTerm(
            tenantId: tenantId,
            contentType: .institutionalKnowledge,
            maxSensitivity: .confidential
        )
        for memory in longTerm.prefix(10) {
            let content = String(data: memory.content, encoding: .utf8) ?? ""
            let tokens = estimateTokens(content)
            if usedTokens + tokens < maxTokens {
                contextParts.append(ContextPart(
                    source: .longTerm,
                    content: content,
                    priority: .medium
                ))
                usedTokens += tokens
            }
        }

        // 3. Get short-term memory (session context)
        let shortTerm = await triMemory.getShortTerm(
            sessionId: sessionId,
            contentType: .interactionHistory
        )
        for memory in shortTerm.suffix(20) {
            let content = String(data: memory.content, encoding: .utf8) ?? ""
            let tokens = estimateTokens(content)
            if usedTokens + tokens < maxTokens {
                contextParts.append(ContextPart(
                    source: .shortTerm,
                    content: content,
                    priority: .high  // Recent context is important
                ))
                usedTokens += tokens
            }
        }

        return BuiltMemoryContext(
            parts: contextParts,
            totalTokens: usedTokens,
            sessionId: sessionId,
            tenantId: tenantId
        )
    }

    private func estimateTokens(_ text: String) -> Int {
        text.count / 4  // Rough approximation
    }
}

/// A part of built context.
public struct ContextPart: Sendable {
    public let source: MemoryType
    public let content: String
    public let priority: ContextPriority
}

/// Priority of context parts.
public enum ContextPriority: String, Sendable, Codable {
    case low
    case medium
    case high
    case critical
}

/// Built context from memory.
public struct BuiltMemoryContext: Sendable {
    public let parts: [ContextPart]
    public let totalTokens: Int
    public let sessionId: String
    public let tenantId: String

    /// Renders context as a single string.
    public func render() -> String {
        parts
            .sorted { $0.priority.rawValue > $1.priority.rawValue }
            .map { $0.content }
            .joined(separator: "\n\n---\n\n")
    }
}
