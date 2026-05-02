//
//  ProfileMemoryConsolidationSystem.swift
//  ContextumModule
//
//  System for consolidating episodic evidence into profile memory facts
//

import Foundation
import DatabaseCore
import ContractsCore
import OSLog

/// System for consolidating episodic evidence into profile memory facts
public struct ProfileMemoryConsolidationSystem: Sendable {
    private let database: ContextumDatabase
    private let profileMemorySystem: ProfileMemorySystem
    private let logger: Logger

    public init(
        database: ContextumDatabase,
        profileMemorySystem: ProfileMemorySystem,
        logger: Logger = Logger(subsystem: "com.anigma.ContextumModule", category: "ProfileMemoryConsolidation")
    ) {
        self.database = database
        self.profileMemorySystem = profileMemorySystem
        self.logger = logger
    }

    // MARK: - Evidence Consolidation

    /// Analyze recent ingestion and promote repeated patterns to profile memory
    public func consolidateEvidenceFromIngestion(
        entityId: String,
        entityType: ProfileMemoryEntityType,
        timeWindow: TimeInterval = 86400 * 7, // 7 days
        minEvidenceCount: Int = 3,
        minConfidenceThreshold: Double = 0.7
    ) async throws -> [ProfileMemoryComponent] {
        let cutoffDate = Date().addingTimeInterval(-timeWindow)
        
        // Get recent chunks for this entity
        let chunks = try await database.getChunksForEntity(
            entityId: entityId,
            since: cutoffDate
        )
        
        // Group by potential fact patterns
        let patternGroups = try await groupChunksByPotentialFacts(chunks: chunks)
        
        var createdMemories: [ProfileMemoryComponent] = []
        
        // Create profile memories for patterns with sufficient evidence
        for (pattern, evidence) in patternGroups {
            guard evidence.count >= minEvidenceCount else { continue }
            
            // Calculate average confidence
            let totalConfidence = evidence.reduce(0.0) { $0 + $1.confidence }
            let averageConfidence = totalConfidence / Double(evidence.count)
            
            guard averageConfidence >= minConfidenceThreshold else { continue }
            
            // Determine fact type based on pattern
            let factType = inferFactTypeFromPattern(pattern)
            
            // Create profile memory
            let memory = try await profileMemorySystem.createProfileMemory(
                entityId: entityId,
                entityType: entityType,
                factType: factType,
                factValue: pattern.factValue,
                factData: [
                    "evidenceCount": "\(evidence.count)",
                    "consolidationSource": "automatic"
                ],
                sourceId: evidence.first?.sourceId ?? "unknown",
                chunkId: evidence.first?.chunkId,
                evidenceType: .derivedFromMultipleSources,
                confidence: averageConfidence
            )
            
            // Add additional evidence links
        for chunkEvidence in evidence.dropFirst() {
            _ = try await profileMemorySystem.addEvidenceToProfileMemory(
                profileMemoryId: memory.id,
                sourceId: chunkEvidence.sourceId,
                    chunkId: chunkEvidence.chunkId,
                    evidenceType: .derivedFromMultipleSources,
                    confidenceContribution: chunkEvidence.confidence
                )
            }
            
            createdMemories.append(memory)
            logger.info("Consolidated profile memory \(memory.id, privacy: .public) from \(evidence.count, privacy: .public) evidence items")
        }
        
        return createdMemories
    }

    // MARK: - Pattern Detection

    /// Group chunks by potential fact patterns
    private func groupChunksByPotentialFacts(chunks: [ProfileMemoryEvidenceChunk]) async throws -> [PatternEvidence: [ChunkEvidence]] {
        var patternGroups: [PatternEvidence: [ChunkEvidence]] = [:]
        
        for chunk in chunks {
            // Extract potential facts from chunk content
            let potentialFacts = extractPotentialFacts(from: chunk.content)
            
            for fact in potentialFacts {
                let pattern = PatternEvidence(
                    factType: fact.type,
                    factValue: fact.value,
                    confidence: fact.confidence
                )
                
                let evidence = ChunkEvidence(
                    chunkId: chunk.chunkId,
                    sourceId: chunk.sourceId,
                    confidence: fact.confidence
                )
                
                if patternGroups[pattern] != nil {
                    patternGroups[pattern]?.append(evidence)
                } else {
                    patternGroups[pattern] = [evidence]
                }
            }
        }
        
        return patternGroups
    }

    /// Extract potential facts from text content
    private func extractPotentialFacts(from content: String) -> [PotentialFact] {
        // Simple pattern-based extraction (would be enhanced with NLP in production)
        var facts: [PotentialFact] = []
        
        // Look for preference patterns
        if content.contains("prefer") || content.contains("favorite") || content.contains("like") {
            facts.append(PotentialFact(
                type: .preference,
                value: extractPreferenceValue(from: content),
                confidence: 0.6
            ))
        }
        
        // Look for skill/interest patterns
        if content.contains("skilled in") || content.contains("expert in") || content.contains("knowledge of") {
            facts.append(PotentialFact(
                type: .skill,
                value: extractSkillValue(from: content),
                confidence: 0.7
            ))
        }
        
        // Look for relationship patterns
        if content.contains("works with") || content.contains("collaborates with") || content.contains("team member") {
            facts.append(PotentialFact(
                type: .relationship,
                value: extractRelationshipValue(from: content),
                confidence: 0.5
            ))
        }
        
        return facts
    }

    // MARK: - Value Extractors

    private func extractPreferenceValue(from content: String) -> String {
        // Simple extraction - would use proper parsing in production
        let patterns = ["prefer ", "favorite ", "like ", "enjoy "]
        for pattern in patterns {
            if let range = content.range(of: pattern) {
                let start = range.upperBound
                let remaining = String(content[start...])
                let end = remaining.firstIndex(of: ".") ?? remaining.endIndex
                return String(remaining[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return "unknown preference"
    }

    private func extractSkillValue(from content: String) -> String {
        let patterns = ["skilled in ", "expert in ", "knowledge of ", "experience with "]
        for pattern in patterns {
            if let range = content.range(of: pattern) {
                let start = range.upperBound
                let remaining = String(content[start...])
                let end = remaining.firstIndex(of: ".") ?? remaining.endIndex
                return String(remaining[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return "unknown skill"
    }

    private func extractRelationshipValue(from content: String) -> String {
        let patterns = ["works with ", "collaborates with ", "team member ", "partner with "]
        for pattern in patterns {
            if let range = content.range(of: pattern) {
                let start = range.upperBound
                let remaining = String(content[start...])
                let end = remaining.firstIndex(of: ".") ?? remaining.endIndex
                return String(remaining[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return "unknown relationship"
    }

    // MARK: - Fact Type Inference

    private func inferFactTypeFromPattern(_ pattern: PatternEvidence) -> ProfileMemoryFactType {
        // Map pattern types to profile memory fact types
        switch pattern.factType {
        case .preference: return .preference
        case .skill: return .skill
        case .relationship: return .relationship
        }
    }

    // MARK: - Manual Profile Memory Creation

    /// Create profile memory manually with explicit evidence
    public func createManualProfileMemory(
        entityId: String,
        entityType: ProfileMemoryEntityType,
        factType: ProfileMemoryFactType,
        factValue: String,
        factData: [String: String] = [:],
        sourceId: String,
        chunkId: String? = nil,
        confidence: Double,
        metadata: [String: String] = [:]
    ) async throws -> ProfileMemoryComponent {
        return try await profileMemorySystem.createProfileMemory(
            entityId: entityId,
            entityType: entityType,
            factType: factType,
            factValue: factValue,
            factData: factData,
            sourceId: sourceId,
            chunkId: chunkId,
            evidenceType: .manualAssertion,
            confidence: confidence,
            metadata: metadata
        )
    }

    // MARK: - Conflict Detection

    /// Detect conflicts in profile memory
    public func detectProfileMemoryConflicts(
        entityId: String,
        entityType: ProfileMemoryEntityType
    ) async throws -> [ProfileMemoryConflict] {
        // Get all active profile memories for this entity
        let query = ProfileMemoryQuery(
            entityId: entityId,
            entityType: entityType,
            includeInactive: false
        )
        
        let memories = try await profileMemorySystem.queryProfileMemories(query: query)
        
        var conflicts: [ProfileMemoryConflict] = []
        
        // Group by fact type to detect conflicts
        let factTypeGroups = Dictionary(grouping: memories, by: { $0.factType })
        
        for (factType, typeMemories) in factTypeGroups {
            guard typeMemories.count > 1 else { continue }
            
            // Check for conflicting values
            let valueGroups = Dictionary(grouping: typeMemories, by: { $0.factValue.lowercased() })
            
            if valueGroups.count > 1 {
                // Multiple different values for the same fact type = conflict
                for (conflictingValue, conflictingMemories) in valueGroups {
                    let conflict = ProfileMemoryConflict(
                        factType: factType,
                        conflictingValue: conflictingValue,
                        memoryIds: conflictingMemories.map { $0.id },
                        confidenceScores: conflictingMemories.map { $0.confidence }
                    )
                    conflicts.append(conflict)
                }
            }
        }
        
        return conflicts
    }

    /// Resolve conflicts by merging or deactivating conflicting memories
    public func resolveProfileMemoryConflicts(
        conflicts: [ProfileMemoryConflict],
        resolutionStrategy: ProfileMemoryConflictResolutionStrategy
    ) async throws -> [ProfileMemoryConflictResolutionResult] {
        var results: [ProfileMemoryConflictResolutionResult] = []
        
        for conflict in conflicts {
            let resolution = try await applyResolutionStrategy(conflict, strategy: resolutionStrategy)
            results.append(resolution)
        }
        
        return results
    }

    private func applyResolutionStrategy(
        _ conflict: ProfileMemoryConflict,
        strategy: ProfileMemoryConflictResolutionStrategy
    ) async throws -> ProfileMemoryConflictResolutionResult {
        switch strategy {
        case .keepHighestConfidence:
            return try await resolveByKeepingHighestConfidence(conflict)
        case .mergeWithAverage:
            return try await resolveByMergingWithAverage(conflict)
        case .deactivateAll:
            return try await resolveByDeactivatingAll(conflict)
        }
    }

    private func resolveByKeepingHighestConfidence(_ conflict: ProfileMemoryConflict) async throws -> ProfileMemoryConflictResolutionResult {
        // Find memory with highest confidence
        guard let maxConfidenceIndex = conflict.confidenceScores.enumerated().max(by: { $0.element < $1.element }) else {
            throw ContextumError.profileMemoryConflict("No memories found for conflict resolution")
        }
        
        let winnerId = conflict.memoryIds[maxConfidenceIndex.offset]
        
        // Deactivate all others
        for (index, memoryId) in conflict.memoryIds.enumerated() {
            if index != maxConfidenceIndex.offset {
                _ = try await profileMemorySystem.deactivateProfileMemory(id: memoryId)
            }
        }
        
        // Mark winner as resolved
        _ = try await profileMemorySystem.markProfileMemoryAsConflicted(id: winnerId, conflictStatus: .resolved)
        
        return ProfileMemoryConflictResolutionResult(
            conflict: conflict,
            resolution: .keptHighestConfidence(winnerId),
            deactivatedMemoryIds: conflict.memoryIds.filter { $0 != winnerId }
        )
    }

    private func resolveByMergingWithAverage(_ conflict: ProfileMemoryConflict) async throws -> ProfileMemoryConflictResolutionResult {
        // This would be more sophisticated in production - merging evidence chains, etc.
        // For now, we'll just keep the first one and mark it as resolved
        guard let firstMemoryId = conflict.memoryIds.first else {
            throw ContextumError.profileMemoryConflict("No memories found for conflict resolution")
        }
        
        // Deactivate all others
        for memoryId in conflict.memoryIds.dropFirst() {
            _ = try await profileMemorySystem.deactivateProfileMemory(id: memoryId)
        }
        
        // Mark winner as resolved
        _ = try await profileMemorySystem.markProfileMemoryAsConflicted(id: firstMemoryId, conflictStatus: .resolved)
        
        return ProfileMemoryConflictResolutionResult(
            conflict: conflict,
            resolution: .merged(firstMemoryId),
            deactivatedMemoryIds: Array(conflict.memoryIds.dropFirst())
        )
    }

    private func resolveByDeactivatingAll(_ conflict: ProfileMemoryConflict) async throws -> ProfileMemoryConflictResolutionResult {
        var deactivatedIds: [String] = []
        
        // Deactivate all conflicting memories
        for memoryId in conflict.memoryIds {
            _ = try await profileMemorySystem.deactivateProfileMemory(id: memoryId)
            deactivatedIds.append(memoryId)
        }
        
        return ProfileMemoryConflictResolutionResult(
            conflict: conflict,
            resolution: .deactivatedAll,
            deactivatedMemoryIds: deactivatedIds
        )
    }
}

// MARK: - Supporting Types

struct PotentialFact: Sendable {
    let type: PotentialFactType
    let value: String
    let confidence: Double
}

enum PotentialFactType: Sendable {
    case preference
    case skill
    case relationship
}

struct PatternEvidence: Hashable, Sendable {
    let factType: PotentialFactType
    let factValue: String
    let confidence: Double
}

struct ChunkEvidence: Sendable {
    let chunkId: String
    let sourceId: String
    let confidence: Double
}

fileprivate struct ProfileMemoryEvidenceChunk: Sendable {
    let chunkId: String
    let sourceId: String
    let content: String
    let confidence: Double
}

public struct ProfileMemoryConflict: Codable, Sendable {
    public let factType: ProfileMemoryFactType
    public let conflictingValue: String
    public let memoryIds: [String]
    public let confidenceScores: [Double]
}

public enum ProfileMemoryConflictResolutionStrategy: Sendable {
    case keepHighestConfidence
    case mergeWithAverage
    case deactivateAll
}

public struct ProfileMemoryConflictResolutionResult: Codable, Sendable {
    public let conflict: ProfileMemoryConflict
    public let resolution: ProfileMemoryConflictResolutionOutcome
    public let deactivatedMemoryIds: [String]
}

public enum ProfileMemoryConflictResolutionOutcome: Codable, Sendable {
    case keptHighestConfidence(String) // winner memory ID
    case merged(String) // merged memory ID
    case deactivatedAll
}

// MARK: - Database Extension for Entity Chunks

extension ContextumDatabase {
    fileprivate func getChunksForEntity(entityId: String, since: Date) async throws -> [ProfileMemoryEvidenceChunk] {
        let rows = try await database.query(
            """
            SELECT c.chunk_id, c.source_id, c.content, c.confidence_score
            FROM contextum_chunks c
            JOIN contextum_sources s ON c.source_id = s.source_id
            WHERE s.canonical_entity_id = ? 
            AND c.created_at >= ?
            """,
            parameters: [
                .text(entityId),
                .double(since.timeIntervalSince1970)
            ]
        )
        
        return rows.compactMap { row in
            guard
                let chunkId = row["chunk_id"].string,
                let sourceId = row["source_id"].string,
                let content = row["content"].string,
                let confidence = row["confidence_score"].double
            else {
                return nil
            }
            
            return ProfileMemoryEvidenceChunk(
                chunkId: chunkId,
                sourceId: sourceId,
                content: content,
                confidence: confidence,
            )
        }
    }
}
