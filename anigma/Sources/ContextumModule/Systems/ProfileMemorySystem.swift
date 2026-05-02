//
//  ProfileMemorySystem.swift
//  ContextumModule
//
//  Profile memory system for managing evidence-backed user/workspace facts
//

import Foundation
import ContractsCore
import OSLog

/// Profile memory system for CRUD operations on evidence-backed facts
public struct ProfileMemorySystem: Sendable {
    private let database: ContextumDatabase
    private let logger: Logger

    public init(database: ContextumDatabase, logger: Logger = Logger(subsystem: "com.anigma.ContextumModule", category: "ProfileMemory")) {
        self.database = database
        self.logger = logger
    }

    // MARK: - Create Operations

    /// Create a new profile memory fact with initial evidence
    public func createProfileMemory(
        entityId: String,
        entityType: ProfileMemoryEntityType,
        factType: ProfileMemoryFactType,
        factValue: String,
        factData: [String: String] = [:],
        sourceId: String,
        chunkId: String? = nil,
        evidenceType: ProfileMemoryEvidenceType,
        confidence: Double,
        metadata: [String: String] = [:]
    ) async throws -> ProfileMemoryComponent {
        // Validate confidence range
        let normalizedConfidence = max(0.0, min(1.0, confidence))

        // Create profile memory component
        let memory = ProfileMemoryComponent(
            entityId: entityId,
            entityType: entityType,
            factType: factType,
            factValue: factValue,
            factData: factData,
            confidence: normalizedConfidence,
            sourceCount: 1,
            conflictStatus: .none,
            metadata: metadata
        )

        // Create evidence link
        let evidenceLink = ProfileMemoryEvidenceLink(
            profileMemoryId: memory.id,
            sourceId: sourceId,
            chunkId: chunkId,
            evidenceType: evidenceType,
            confidenceContribution: normalizedConfidence
        )

        // Persist to database
        try await database.createProfileMemory(memory)
        try await database.createProfileMemoryEvidenceLink(evidenceLink)

        logger.info("Created profile memory \(memory.id, privacy: .public) for entity \(entityId, privacy: .public)")

        return memory
    }

    // MARK: - Read Operations

    /// Get profile memory by ID
    public func getProfileMemory(id: String) async throws -> ProfileMemoryComponent? {
        return try await database.getProfileMemory(id: id)
    }

    /// Get profile memory with full evidence chain
    public func getProfileMemoryWithEvidence(id: String) async throws -> ProfileMemoryWithEvidence? {
        guard let memory = try await getProfileMemory(id: id) else {
            return nil
        }

        let evidence = try await database.getProfileMemoryEvidenceLinks(profileMemoryId: id)
        let sourceIds = evidence.map { $0.sourceId }
        let sources = try await database.getContextSources(ids: sourceIds)
        
        let chunkIds = evidence.compactMap { $0.chunkId }
        let chunks = chunkIds.isEmpty ? [] : try await database.getChunks(ids: chunkIds)

        return ProfileMemoryWithEvidence(
            memory: memory,
            evidence: evidence,
            sources: sources,
            chunks: chunks
        )
    }

    /// Query profile memories
    public func queryProfileMemories(query: ProfileMemoryQuery) async throws -> [ProfileMemoryComponent] {
        return try await database.queryProfileMemories(query: query)
    }

    // MARK: - Update Operations

    /// Update profile memory fact
    public func updateProfileMemory(id: String, update: ProfileMemoryUpdateRequest) async throws -> ProfileMemoryComponent? {
        guard let existing = try await getProfileMemory(id: id) else {
            return nil
        }

        // Apply updates
        let factValue = update.factValue ?? existing.factValue
        let factData = update.factData ?? existing.factData
        let confidence = update.confidenceDelta.map { existing.confidence + $0 } ?? existing.confidence
        let conflictStatus = update.conflictStatus ?? existing.conflictStatus
        let isActive = update.isActive ?? existing.isActive
        let metadata = update.metadata ?? existing.metadata

        // Create updated component
        let updated = ProfileMemoryComponent(
            id: existing.id,
            entityId: existing.entityId,
            entityType: existing.entityType,
            factType: existing.factType,
            factValue: factValue,
            factData: factData,
            confidence: confidence,
            sourceCount: existing.sourceCount,
            firstObservedAt: existing.firstObservedAt,
            lastObservedAt: Date(), // Update timestamp
            lastUpdatedAt: Date(),
            isActive: isActive,
            conflictStatus: conflictStatus,
            metadata: metadata
        )

        // Persist update
        try await database.updateProfileMemory(updated)

        logger.info("Updated profile memory \(updated.id, privacy: .public)")

        return updated
    }

    /// Add evidence to existing profile memory
    public func addEvidenceToProfileMemory(
        profileMemoryId: String,
        sourceId: String,
        chunkId: String? = nil,
        evidenceType: ProfileMemoryEvidenceType,
        confidenceContribution: Double
    ) async throws -> ProfileMemoryEvidenceLink {
        // Get existing memory to update source count
        guard let memory = try await getProfileMemory(id: profileMemoryId) else {
            throw ContextumError.profileMemoryNotFound(profileMemoryId)
        }

        // Create evidence link
        let evidenceLink = ProfileMemoryEvidenceLink(
            profileMemoryId: profileMemoryId,
            sourceId: sourceId,
            chunkId: chunkId,
            evidenceType: evidenceType,
            confidenceContribution: confidenceContribution
        )

        let updatedSourceCount = memory.sourceCount + 1
        let updatedConfidence =
            (memory.confidence * Double(memory.sourceCount) + confidenceContribution)
            / Double(updatedSourceCount)
        let now = Date()
        let updatedMemory = ProfileMemoryComponent(
            id: memory.id,
            entityId: memory.entityId,
            entityType: memory.entityType,
            factType: memory.factType,
            factValue: memory.factValue,
            factData: memory.factData,
            confidence: updatedConfidence,
            sourceCount: updatedSourceCount,
            firstObservedAt: memory.firstObservedAt,
            lastObservedAt: now,
            lastUpdatedAt: now,
            isActive: memory.isActive,
            conflictStatus: memory.conflictStatus,
            metadata: memory.metadata
        )

        // Persist changes
        try await database.createProfileMemoryEvidenceLink(evidenceLink)
        try await database.updateProfileMemory(updatedMemory)

        logger.info("Added evidence to profile memory \(profileMemoryId, privacy: .public), source count now \(updatedMemory.sourceCount, privacy: .public)")

        return evidenceLink
    }

    // MARK: - Conflict Resolution

    /// Mark profile memory as having unresolved conflict
    public func markProfileMemoryAsConflicted(id: String, conflictStatus: ProfileMemoryConflictStatus = .unresolved) async throws -> ProfileMemoryComponent? {
        let update = ProfileMemoryUpdateRequest(conflictStatus: conflictStatus)
        return try await updateProfileMemory(id: id, update: update)
    }

    /// Resolve conflict in profile memory
    public func resolveProfileMemoryConflict(id: String, resolution: ProfileMemoryConflictResolution) async throws -> ProfileMemoryComponent? {
        // Apply resolution updates
        var update = ProfileMemoryUpdateRequest(
            conflictStatus: .resolved,
            isActive: resolution.keepActive
        )

        if let factValue = resolution.resolvedFactValue {
            update.factValue = factValue
        }

        if let confidenceAdjustment = resolution.confidenceAdjustment {
            update.confidenceDelta = confidenceAdjustment
        }

        return try await updateProfileMemory(id: id, update: update)
    }

    // MARK: - Deactivation

    /// Deactivate profile memory (soft delete)
    public func deactivateProfileMemory(id: String) async throws -> ProfileMemoryComponent? {
        let update = ProfileMemoryUpdateRequest(isActive: false)
        return try await updateProfileMemory(id: id, update: update)
    }

    /// Reactivate profile memory
    public func reactivateProfileMemory(id: String) async throws -> ProfileMemoryComponent? {
        let update = ProfileMemoryUpdateRequest(isActive: true)
        return try await updateProfileMemory(id: id, update: update)
    }
}

// MARK: - Conflict Resolution

public struct ProfileMemoryConflictResolution: Codable, Sendable {
    public let keepActive: Bool
    public let resolvedFactValue: String?
    public let confidenceAdjustment: Double?
    public let resolutionNotes: String?

    public init(
        keepActive: Bool,
        resolvedFactValue: String? = nil,
        confidenceAdjustment: Double? = nil,
        resolutionNotes: String? = nil
    ) {
        self.keepActive = keepActive
        self.resolvedFactValue = resolvedFactValue
        self.confidenceAdjustment = confidenceAdjustment
        self.resolutionNotes = resolutionNotes
    }
}

// MARK: - Profile Memory Errors

extension ContextumError {
    public static func profileMemoryNotFound(_ id: String) -> ContextumError {
        .profileMemoryNotFound(id: id)
    }

    public static func profileMemoryConflict(_ id: String, message: String) -> ContextumError {
        .profileMemoryConflict(message: "Conflict in profile memory \(id): \(message)")
    }

    public static func profileMemoryConflict(_ message: String) -> ContextumError {
        .profileMemoryConflict(message: message)
    }

    public static func profileMemoryEvidenceValidationFailed(_ message: String) -> ContextumError {
        .profileMemoryEvidenceValidationFailed(message: message)
    }
}
