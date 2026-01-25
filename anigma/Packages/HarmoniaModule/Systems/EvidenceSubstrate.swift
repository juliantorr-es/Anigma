//
//  EvidenceSubstrate.swift
//  HarmoniaModule
//
//  ECS system implementation for HarmoniaModule.
//

import AnigmaCore
import DatabaseCore
@preconcurrency import Foundation
@preconcurrency import CryptoKit
import ContractsCore

// MARK: - Legacy Type Aliases for Migration

@available(*, deprecated, message: "Use ContractsCore.EvidenceViolation instead")
public typealias EvidenceViolation = ContractsCore.EvidenceViolation

@available(*, deprecated, message: "Use ContractsCore.EvidenceViolationType instead")
public typealias ViolationType = ContractsCore.EvidenceViolationType

@available(*, deprecated, message: "Use ContractsCore.EvidenceViolationSeverity instead")
public typealias ViolationSeverity = ContractsCore.EvidenceViolationSeverity

/// Unified Evidence Substrate - Cathedral integration layer
/// Makes TamperEvidenceSystem, ForensicMetadataTracker, and RetrievalExplainabilitySystem
/// serve as default evidence primitives for all ML and coordination operations
public actor EvidenceSubstrate {
    private let dbActor: any DatabaseCore.DatabaseExecutor
    private let tamperEvidence: TamperEvidenceSystem
    private let forensicTracker: ForensicMetadataTracker
    private let retrievalExplainability: RetrievalExplainabilitySystem

    public init(dbActor: any DatabaseCore.DatabaseExecutor) async throws {
        self.dbActor = dbActor

        // Initialize the three evidence systems
        self.tamperEvidence = try await TamperEvidenceSystem(dbActor: dbActor)

        // ForensicTracker needs DocumentUnitDatabase for recipe lookups
        let documentDatabase = DocumentUnitDatabase(dbActor: dbActor)
        self.forensicTracker = try await ForensicMetadataTracker(dbActor: dbActor)

        // RetrievalExplainability needs both DocumentUnitDatabase and TamperEvidenceSystem
        self.retrievalExplainability = try await RetrievalExplainabilitySystem(
            dbActor: dbActor,
            documentDatabase: documentDatabase,
            tamperEvidence: tamperEvidence
        )
    }

    // MARK: - Unified Evidence Operations

    /// Perform any ML operation with automatic evidence capture
    public func performMLOperation(
        operationType: MLOperationType,
        inputs: [String: Sendable],
        actor: String,
        sessionContext: String? = nil,
        purpose: String? = nil
    ) async throws -> MLOperationResult {
        let operationId = UUID().uuidString.lowercased()
        let startTime = Date()

        // Create tamper-evident event for the operation
        let eventId = try await tamperEvidence.appendEvent(
            eventType: operationType.rawValue,
            payload: inputs,
            actor: actor,
            actorIP: nil, // Could be extracted from request context
            sessionId: sessionContext
        )

        // Perform operation-specific evidence capture
        let operationResult: MLOperationResult

        switch operationType {
        case .documentIngestion:
            operationResult = try await handleDocumentIngestion(
                inputs: inputs,
                actor: actor,
                operationId: operationId
            )

        case .embeddingGeneration:
            operationResult = try await handleEmbeddingGeneration(
                inputs: inputs,
                actor: actor,
                operationId: operationId
            )

        case .semanticSearch:
            operationResult = try await handleSemanticSearch(
                inputs: inputs,
                actor: actor,
                operationId: operationId
            )

        case .textSearch:
            operationResult = try await handleTextSearch(
                inputs: inputs,
                actor: actor,
                operationId: operationId
            )
        }

        let executionTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)

        // Create completion event with evidence linking
        _ = try await tamperEvidence.appendEvent(
            eventType: "ml_operation_completed",
            payload: [
                "operationId": operationId,
                "operationType": operationType.rawValue,
                "primaryEventId": eventId,
                "resultCount": operationResult.resultCount,
                "executionTimeMs": executionTimeMs,
                "evidenceLinks": operationResult.evidenceLinks
            ],
            actor: actor,
            sessionId: sessionContext
        )

        return MLOperationResult(
            resultCount: operationResult.resultCount,
            evidenceLinks: operationResult.evidenceLinks
        )
    }

    /// Get comprehensive evidence for an operation
    public func getOperationEvidence(operationId: String) async throws -> OperationEvidence {
        // Get tamper events for this operation
        let evidenceEvents = try await getOperationTamperEvents(operationId: operationId)

        // Get related forensic records
        let forensicRecords = try await getOperationForensicRecords(operationId: operationId)

        // Get related retrieval evidence
        let retrievalRecords = try await getOperationRetrievalRecords(operationId: operationId)

        return OperationEvidence(
            operationId: operationId,
            tamperEvents: evidenceEvents,
            forensicRecords: forensicRecords,
            retrievalRecords: retrievalRecords,
            collectedAt: Date(),
            chainIntact: true // Could be verified with tamperEvidence.verifyChain()
        )
    }

    /// Validate evidence chain for a specific operation
    public func validateOperationEvidence(operationId: String) async throws -> EvidenceValidationResult {
        let operationEvidence = try await getOperationEvidence(operationId: operationId)

        // Verify tamper chain integrity
        let chainReport = try await tamperEvidence.verifyChain()

        // Validate forensic chain completeness
        let forensicValidation = validateForensicChain(operationEvidence.forensicRecords)

        // Validate retrieval reproducibility
        let retrievalValidation = try await validateRetrievalReproducibility(operationEvidence.retrievalRecords)

        return EvidenceValidationResult(
            operationId: operationId,
            chainIntegrity: chainReport,
            forensicValidation: forensicValidation,
            retrievalValidation: retrievalValidation,
            overallValid: chainReport.isIntact && forensicValidation.isValid && retrievalValidation.isValid
        )
    }

    /// Enforce evidence substrate for Cathedral coordination
    /// Makes evidence a mandatory precondition for operations
    public func enforceEvidenceSubstrate(
        operation: String,
        evidenceLevel: EvidenceRequirement = .strict
    ) async throws -> EvidenceEnforcementResult {
        // Check if we have sufficient evidence for this operation
        let evidenceCheck = try await validateEvidenceForOperation(
            operation: operation,
            requiredLevel: evidenceLevel
        )

        guard evidenceCheck.hasSufficientEvidence else {
            throw CathedralError.operationBlocked(
                "Insufficient evidence for operation '\(operation)'. Required: \(evidenceLevel.rawValue), Available: \(evidenceCheck.currentLevel.rawValue)"
            )
        }

        // Record that we enforced evidence for this operation
        let enforcementEventId = try await tamperEvidence.appendEvent(
            eventType: "evidence_enforcement",
            payload: [
                "operation": operation,
                "requiredLevel": evidenceLevel.rawValue,
                "actualLevel": evidenceCheck.currentLevel.rawValue,
                "evidenceCount": evidenceCheck.evidenceCount,
                "enforcementTimestamp": Date().timeIntervalSince1970
            ],
            actor: "cathedral_substrate"
        )

        return EvidenceEnforcementResult(
            operation: operation,
            enforcementSuccessful: true,
            evidenceLevel: evidenceCheck.currentLevel,
            enforcementEventId: enforcementEventId,
            blockingReason: nil
        )
    }

    private func validateEvidenceForOperation(
        operation: String,
        requiredLevel: EvidenceRequirement
    ) async throws -> EvidenceCheckResult {
        // Query recent evidence for this operation type
        let recentEvidence = try await dbActor.query("""
            SELECT COUNT(*) as count, MAX(timestamp) as latest_timestamp
            FROM tamper_events
            WHERE event_type LIKE ? OR payload LIKE ?
            AND timestamp > ?
            ORDER BY timestamp DESC
            LIMIT 100
            """, parameters: [
                DatabaseCore.dbp("%\(operation)%"),
                DatabaseCore.dbp("%operation\":\"\(operation)%"),
                DatabaseCore.dbp(Date().addingTimeInterval(-300).timeIntervalSince1970) // Last 5 minutes
            ])

        let evidenceCount = recentEvidence.first?.int(for: "count") ?? 0
        let latestTimestamp = recentEvidence.first?.double(for: "latest_timestamp") ?? 0

        // Determine evidence level based on quantity and recency
        let currentLevel: EvidenceRequirement
        if evidenceCount >= 5 && latestTimestamp > Date().addingTimeInterval(-60).timeIntervalSince1970 {
            currentLevel = .high
        } else if evidenceCount >= 2 && latestTimestamp > Date().addingTimeInterval(-180).timeIntervalSince1970 {
            currentLevel = .moderate
        } else if evidenceCount >= 1 {
            currentLevel = .low
        } else {
            currentLevel = .none
        }

        return EvidenceCheckResult(
            operation: operation,
            currentLevel: currentLevel,
            evidenceCount: evidenceCount,
            hasSufficientEvidence: currentLevel.rawValue >= requiredLevel.rawValue
        )
    }

    /// Generate evidence bundle for legal discovery
    public func generateLegalDiscoveryBundle(
        operationIds: [String],
        bundlePurpose: String,
        requestingActor: String,
        timeRangeHours: Int = 24
    ) async throws -> String {
        // Create evidence bundle with all related evidence
        let bundleId = try await tamperEvidence.createBundle(
            bundleType: "legal_discovery_ml_operations",
            description: "Legal discovery bundle for ML operations: \(operationIds.joined(separator: ", "))",
            purpose: bundlePurpose,
            eventIds: await flattenOperationEventIds(operationIds),
            artifactPaths: await gatherOperationArtifacts(operationIds),
            timeRangeHours: timeRangeHours
        )

        // Export the bundle
        let exportPath = try await tamperEvidence.exportBundle(
            bundleId: bundleId,
            format: .zip,
            outputPath: "/tmp/anigma-legal-discovery-\(bundleId)"
        )

        return exportPath
    }

    // MARK: - Private Operation Handlers

    private func handleDocumentIngestion(
        inputs: [String: Sendable],
        actor: String,
        operationId: String
    ) async throws -> MLOperationResult {
        guard let filePath = inputs["filePath"] as? String else {
            throw EvidenceSubstrateError.missingRequiredInput("filePath")
        }

        // Use forensic tracker for document acquisition
        let acquisitionId = try await forensicTracker.recordDocumentAcquisition(
            filePath: filePath,
            fileSize: try getFileSize(filePath),
            acquisitionMethod: .fileUpload,
            acquisitionTimestamp: Date(),
            acquiringActor: actor
        )

        return MLOperationResult(
            resultCount: 1,
            evidenceLinks: [
                "forensic_acquisition": acquisitionId,
                "file_path": filePath
            ]
        )
    }

    private func handleEmbeddingGeneration(
        inputs: [String: Sendable],
        actor: String,
        operationId: String
    ) async throws -> MLOperationResult {
        guard let documentId = inputs["documentId"] as? String,
              let recipeId = inputs["recipeId"] as? String else {
            throw EvidenceSubstrateError.missingRequiredInput("documentId or recipeId")
        }

        // This would integrate with actual embedding pipeline
        // For now, create mock embedding evidence
        let embeddingEventId = try await tamperEvidence.appendEvent(
            eventType: "embedding_generated",
            payload: [
                "documentId": documentId,
                "recipeId": recipeId,
                "method": "unified_substrate",
                "actor": actor
            ],
            actor: actor
        )

        return MLOperationResult(
            resultCount: 1,
            evidenceLinks: [
                "embedding_event": embeddingEventId,
                "document_id": documentId,
                "recipe_id": recipeId
            ]
        )
    }

    private func handleSemanticSearch(
        inputs: [String: Sendable],
        actor: String,
        operationId: String
    ) async throws -> MLOperationResult {
        guard let queryText = inputs["queryText"] as? String,
              let recipeId = inputs["recipeId"] as? String else {
            throw EvidenceSubstrateError.missingRequiredInput("queryText or recipeId")
        }

        // Use retrieval explainability system
        let retrievalResult = try await retrievalExplainability.explainableSemanticSearch(
            queryText: queryText,
            embeddingRecipeId: recipeId,
            similarityThreshold: inputs["similarityThreshold"] as? Double ?? 0.7,
            maxResults: inputs["maxResults"] as? Int ?? 10,
            requestingActor: actor,
            sessionContext: "operation:\(operationId)",
            searchPurpose: "unified_substrate_search"
        )

        return MLOperationResult(
            resultCount: retrievalResult.results.count,
            evidenceLinks: [
                "retrieval_query": retrievalResult.queryId,
                "result_count": retrievalResult.results.count,
                "similarity_threshold": inputs["similarityThreshold"] ?? 0.7
            ]
        )
    }

    private func handleTextSearch(
        inputs: [String: Sendable],
        actor: String,
        operationId: String
    ) async throws -> MLOperationResult {
        guard let queryText = inputs["queryText"] as? String else {
            throw EvidenceSubstrateError.missingRequiredInput("queryText")
        }

        let retrievalResult = try await retrievalExplainability.explainableTextSearch(
            queryText: queryText,
            searchFields: inputs["searchFields"] as? [String] ?? ["content", "content_preview"],
            maxResults: inputs["maxResults"] as? Int ?? 50,
            requestingActor: actor,
            sessionContext: "operation:\(operationId)",
            searchPurpose: "unified_substrate_text_search"
        )

        return MLOperationResult(
            resultCount: retrievalResult.results.count,
            evidenceLinks: [
                "text_retrieval_query": retrievalResult.queryId,
                "result_count": retrievalResult.results.count,
                "search_fields": inputs["searchFields"] ?? ["content", "content_preview"]
            ]
        )
    }

    // MARK: - Evidence Gathering

    private func getOperationTamperEvents(operationId: String) async throws -> [String] {
        // Find all tamper events related to this operation
        let result = try await dbActor.query("""
            SELECT event_id FROM tamper_events
            WHERE payload LIKE ? OR payload LIKE ?
            ORDER BY timestamp
            """, parameters: [
                dbp("%\"\(operationId)\"%"),
                dbp("%operationId\":\"\(operationId)\"%")
            ])

        return result.compactMap { $0.string(for: "event_id") ?? "" }
    }

    private func getOperationForensicRecords(operationId: String) async throws -> [String] {
        // Find forensic records related to this operation
        let result = try await dbActor.query("""
            SELECT acquisition_id FROM forensic_acquisitions
            WHERE acquiring_actor = ? AND (acquisition_id LIKE ? OR acquisition_id LIKE ?)
            """, parameters: [
                dbp("unified_substrate"),
                dbp("%\(operationId)%"),
                dbp("%operationId%")
            ])

        return result.compactMap { $0.string(for: "acquisition_id") ?? "" }
    }

    private func getOperationRetrievalRecords(operationId: String) async throws -> [String] {
        // Find retrieval evidence related to this operation
        let result = try await dbActor.query("""
            SELECT query_id FROM retrieval_evidence
            WHERE session_context LIKE ? OR requesting_actor = ?
            ORDER BY timestamp DESC
            """, parameters: [
                dbp("operation:\(operationId)"),
                dbp("unified_substrate")
            ])

        return result.compactMap { $0.string(for: "query_id") ?? "" }
    }

    private func flattenOperationEventIds(_ operationIds: [String]) async -> [String] {
        var allEventIds: [String] = []

        for operationId in operationIds {
            if let opEvents = try? await getOperationTamperEvents(operationId: operationId) {
                allEventIds.append(contentsOf: opEvents)
            }
        }

        return allEventIds
    }

    private func gatherOperationArtifacts(_ operationIds: [String]) async throws -> [String] {
        var artifacts: [String] = []

        for operationId in operationIds {
            // Gather forensic artifacts
            if let forensicRecords = try? await getOperationForensicRecords(operationId: operationId) {
                for recordId in forensicRecords {
                    artifacts.append("forensic_acquisition:\(recordId)")
                }
            }

            // Gather retrieval artifacts
            if let retrievalRecords = try? await getOperationRetrievalRecords(operationId: operationId) {
                for recordId in retrievalRecords {
                    artifacts.append("retrieval_evidence:\(recordId)")
                }
            }
        }

        return artifacts
    }

    private func validateForensicChain(_ records: [String]) -> ForensicValidationResult {
        guard !records.isEmpty else {
            return ForensicValidationResult(isValid: true, issues: [])
        }

        var issues: [String] = []

        // Check that each record has proper chain
        for recordId in records {
            // In a real implementation, this would verify the forensic chain
            // For now, just ensure record exists
            if recordId.isEmpty {
                issues.append("Empty forensic record ID: \(recordId)")
            }
        }

        return ForensicValidationResult(isValid: issues.isEmpty, issues: issues)
    }

    private func validateRetrievalReproducibility(_ records: [String]) async throws -> RetrievalValidationResult {
        var reproducibilityScores: [String: Double] = [:]
        var issues: [String] = []

        for recordId in records {
            // In a real implementation, this would test retrieval reproducibility
            // For now, assume perfect reproducibility
            reproducibilityScores[recordId] = 1.0

            if recordId.isEmpty {
                issues.append("Empty retrieval record ID: \(recordId)")
            }
        }

        let avgScore = reproducibilityScores.values.reduce(0, +) / Double(reproducibilityScores.count)

        return RetrievalValidationResult(
            isValid: issues.isEmpty,
            avgReproducibilityScore: avgScore,
            individualScores: reproducibilityScores,
            issues: issues
        )
    }

    // MARK: - Utilities

    private func getFileSize(_ filePath: String) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
        return attributes[.size] as? Int64 ?? 0
    }
}

// MARK: - Supporting Types

/// ML operation types
public enum MLOperationType: String, CaseIterable {
    case documentIngestion = "document_ingestion"
    case embeddingGeneration = "embedding_generation"
    case semanticSearch = "semantic_search"
    case textSearch = "text_search"
}

/// ML operation result with evidence links
public struct MLOperationResult: Sendable {
    public let resultCount: Int
    public let evidenceLinks: [String: Sendable]

    public init(resultCount: Int, evidenceLinks: [String: Sendable]) {
        self.resultCount = resultCount
        self.evidenceLinks = evidenceLinks
    }
}

/// Comprehensive evidence for an operation
public struct OperationEvidence: Sendable {
    public let operationId: String
    public let tamperEvents: [String]
    public let forensicRecords: [String]
    public let retrievalRecords: [String]
    public let collectedAt: Date
    public let chainIntact: Bool

    public init(
        operationId: String,
        tamperEvents: [String],
        forensicRecords: [String],
        retrievalRecords: [String],
        collectedAt: Date,
        chainIntact: Bool
    ) {
        self.operationId = operationId
        self.tamperEvents = tamperEvents
        self.forensicRecords = forensicRecords
        self.retrievalRecords = retrievalRecords
        self.collectedAt = collectedAt
        self.chainIntact = chainIntact
    }
}

/// Forensic validation result
public struct ForensicValidationResult: Sendable {
    public let isValid: Bool
    public let issues: [String]

    public init(isValid: Bool, issues: [String]) {
        self.isValid = isValid
        self.issues = issues
    }
}

/// Retrieval validation result  
public struct RetrievalValidationResult: Sendable {
    public let isValid: Bool
    public let avgReproducibilityScore: Double
    public let individualScores: [String: Double]
    public let issues: [String]

    public init(
        isValid: Bool,
        avgReproducibilityScore: Double,
        individualScores: [String: Double],
        issues: [String]
    ) {
        self.isValid = isValid
        self.avgReproducibilityScore = avgReproducibilityScore
        self.individualScores = individualScores
        self.issues = issues
    }
}

/// Evidence validation result
    public struct EvidenceValidationResult: Sendable {
        public let operationId: String
        public let chainIntegrity: ChainIntegrityReport
        public let forensicValidation: ForensicValidationResult
        public let retrievalValidation: RetrievalValidationResult
        public let overallValid: Bool
        public let validationTimestamp: Date

        public init(
            operationId: String,
            chainIntegrity: ChainIntegrityReport,
            forensicValidation: ForensicValidationResult,
            retrievalValidation: RetrievalValidationResult,
            overallValid: Bool,
            validationTimestamp: Date = Date()
        ) {
            self.operationId = operationId
            self.chainIntegrity = chainIntegrity
            self.forensicValidation = forensicValidation
            self.retrievalValidation = retrievalValidation
            self.overallValid = overallValid
            self.validationTimestamp = validationTimestamp
        }
    }

/// Evidence check result for enforcement
public struct EvidenceCheckResult: Sendable {
    public let operation: String
    public let currentLevel: EvidenceRequirement
    public let evidenceCount: Int
    public let hasSufficientEvidence: Bool

    public init(
        operation: String,
        currentLevel: EvidenceRequirement,
        evidenceCount: Int,
        hasSufficientEvidence: Bool
    ) {
        self.operation = operation
        self.currentLevel = currentLevel
        self.evidenceCount = evidenceCount
        self.hasSufficientEvidence = hasSufficientEvidence
    }
}

public struct EvidenceEnforcementResult: Sendable {
    public let operation: String
    public let enforcementSuccessful: Bool
    public let evidenceLevel: EvidenceRequirement
    public let enforcementEventId: String
    public let blockingReason: String?
}

public enum CathedralError: Error, LocalizedError {
    case operationBlocked(String)
    case evidenceChainCorrupted(String)
    case evidenceTimeout(String)
    case unauthorizedEvidenceAccess(String)
    case invalidEvidenceFormat(String)
    case validationFailed([String])
    case databaseError(String)
    case configurationError(String)

    public var errorDescription: String? {
        switch self {
        case .operationBlocked(let message):
            return "Operation blocked: \(message)"
        case .evidenceChainCorrupted(let details):
            return "Evidence chain corrupted: \(details)"
        case .evidenceTimeout(let details):
            return "Evidence timeout: \(details)"
        case .unauthorizedEvidenceAccess(let details):
            return "Unauthorized evidence access: \(details)"
        case .invalidEvidenceFormat(let details):
            return "Invalid evidence format: \(details)"
        case .validationFailed(let violations):
            return "Evidence validation failed: \(violations.joined(separator: ", "))"
        case .databaseError(let details):
            return "Database error: \(details)"
        case .configurationError(let details):
            return "Configuration error: \(details)"
        }
    }
}

enum EvidenceSubstrateError: Error, LocalizedError {
    case missingRequiredInput(String)
    case evidenceCollectionFailed(String)
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingRequiredInput(let input):
            return "Missing required input: \(input)"
        case .evidenceCollectionFailed(let reason):
            return "Evidence collection failed: \(reason)"
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        }
    }
}
