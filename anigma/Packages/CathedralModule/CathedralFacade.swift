//
//  CathedralFacade.swift
//  CathedralModule
//
//  Unified facade for Cathedral coordination system
//

import Foundation
import ContractsCore
import DatabaseCore
import AnigmaCore

// MARK: - Cathedral Facade

/// Comprehensive Cathedral coordination facade
/// Provides unified access to all Cathedral subsystems
public actor CathedralFacade {
    // Core subsystems
    private let coordinator: CathedralCoordinator
    private let evidenceSubstrate: EvidenceSubstrate
    private let tamperSystem: TamperEvidenceSystem
    private let enforcementSystem: EvidenceEnforcementSystem
    private let forensicTracker: ForensicMetadataTracker
    private let retrievalExplainer: RetrievalExplainability
    private let fusedKernelPlanner: CathedralFusedKernelPlanner

    // Configuration
    private let config: CathedralConfig

    public init(
        coordinator: CathedralCoordinator,
        evidenceSubstrate: EvidenceSubstrate,
        tamperSystem: TamperEvidenceSystem,
        enforcementSystem: EvidenceEnforcementSystem,
        forensicTracker: ForensicMetadataTracker,
        retrievalExplainer: RetrievalExplainability,
        fusedKernelPlanner: CathedralFusedKernelPlanner,
        config: CathedralConfig
    ) {
        self.coordinator = coordinator
        self.evidenceSubstrate = evidenceSubstrate
        self.tamperSystem = tamperSystem
        self.enforcementSystem = enforcementSystem
        self.forensicTracker = forensicTracker
        self.retrievalExplainer = retrievalExplainer
        self.fusedKernelPlanner = fusedKernelPlanner
        self.config = config
    }

    // MARK: - Coordination Operations

    /// Execute ML operation with full evidence enforcement
    public func executeOperation(
        operation: MLOperation,
        requirement: EvidenceRequirement = .moderate
    ) async throws -> OperationResult {
        // 1. Enforce evidence requirements
        _ = try await enforcementSystem.enforceOperation(
            operation: operation,
            requirement: requirement
        )

        // 2. Execute through coordinator
        return try await coordinator.executeWithEvidence(
            operation: operation,
            requirement: requirement
        )
    }

    /// Validate evidence chain for session
    public func validateSession(sessionId: String) async throws -> EvidenceChainValidation {
        return try await coordinator.validateEvidenceChain(sessionId: sessionId)
    }

    // MARK: - Document Tracking

    /// Record document acquisition
    public func recordDocumentAcquisition(
        documentId: String,
        filePath: String,
        sessionId: String,
        agentId: String,
        sourceMetadata: [String: String] = [:]
    ) async throws {
        try await forensicTracker.recordAcquisition(
            documentId: documentId,
            filePath: filePath,
            sessionId: sessionId,
            agentId: agentId,
            sourceMetadata: sourceMetadata
        )
    }

    /// Record document transformation
    public func recordDocumentTransformation(
        documentId: String,
        transformation: DocumentTransformation,
        sessionId: String,
        agentId: String
    ) async throws {
        try await forensicTracker.recordTransformation(
            documentId: documentId,
            transformation: transformation,
            sessionId: sessionId,
            agentId: agentId
        )
    }

    /// Get document metadata
    public func getDocumentMetadata(documentId: String) async -> DocumentMetadata? {
        return await forensicTracker.getDocumentMetadata(documentId: documentId)
    }

    // MARK: - Retrieval Explainability

    /// Record search query with results
    public func recordSearchQuery(
        query: SearchQuery,
        results: [SearchResult],
        sessionId: String,
        agentId: String
    ) async throws -> QueryRecord {
        return try await retrievalExplainer.recordQuery(
            query: query,
            results: results,
            sessionId: sessionId,
            agentId: agentId
        )
    }

    /// Verify query reproducibility
    public func verifyQueryReproducibility(
        originalQueryId: String,
        newResults: [SearchResult]
    ) async throws -> ReproducibilityReport {
        return try await retrievalExplainer.verifyReproducibility(
            originalQueryId: originalQueryId,
            newResults: newResults
        )
    }

    // MARK: - Compliance Reporting

    /// Get comprehensive compliance report
    public func getComplianceReport(sessionId: String) async throws -> ComplianceReport {
        return try await enforcementSystem.getComplianceReport(sessionId: sessionId)
    }

    /// Get session violations
    public func getSessionViolations(sessionId: String) async -> [EvidenceViolation] {
        return await enforcementSystem.getSessionViolations(sessionId: sessionId)
    }

    // MARK: - Evidence Management

    /// Record custom evidence
    public func recordEvidence(_ evidence: Evidence) async throws {
        try await coordinator.recordEvidence(evidence)
    }

    /// Get session evidence
    public func getSessionEvidence(sessionId: String) async -> [Evidence] {
        return await tamperSystem.getSessionEvidence(sessionId: sessionId)
    }

    // MARK: - Court-Safe Bundle Export

    /// Export court-safe evidence bundle for session
    public func exportEvidenceBundle(
        sessionId: String
    ) async throws -> EvidenceBundle {
        let chainValidation = try await validateSession(sessionId: sessionId)
        let evidence = await getSessionEvidence(sessionId: sessionId)
        let violations = await getSessionViolations(sessionId: sessionId)
        let complianceReport = try await getComplianceReport(sessionId: sessionId)
        let documents = await forensicTracker.getSessionDocuments(sessionId: sessionId)
        let queries = await retrievalExplainer.getSessionQueries(sessionId: sessionId)
        let fusedMission = await fusedKernelPlanner.plan(
            operation: MLOperation(type: .transformation, sessionId: sessionId, agentId: "cathedral-export"),
            evidenceCount: evidence.count
        )
        let fusedReceipt = await fusedKernelPlanner.execute(fusedMission)

        return EvidenceBundle(
            sessionId: sessionId,
            chainValidation: chainValidation,
            evidence: evidence,
            violations: violations,
            complianceReport: complianceReport,
            documents: documents,
            queries: queries,
            exportTimestamp: Date(),
            bundleHash: computeBundleHash(sessionId: sessionId, evidence: evidence, violations: violations, fusedReceipt: fusedReceipt)
        )
    }

    private func computeBundleHash(
        sessionId: String,
        evidence: [Evidence],
        violations: [EvidenceViolation],
        fusedReceipt: CathedralFusedKernelReceipt
    ) -> String {
        let evidenceHashes = evidence.map { $0.computeHash() }.sorted().joined(separator: "|")
        let violationHashes = violations.map { "\($0.severity.rawValue)|\($0.description)" }.sorted().joined(separator: "|")
        let hashInput = [
            sessionId,
            String(evidence.count),
            String(violations.count),
            evidenceHashes,
            violationHashes,
            fusedReceipt.rootHash
        ].joined(separator: "|")
        return hashInput.blake3Hash
    }
}

// MARK: - Evidence Bundle

/// Court-safe evidence bundle for legal discovery
public struct EvidenceBundle: Sendable, Codable {
    public let sessionId: String
    public let chainValidation: EvidenceChainValidation
    public let evidence: [Evidence]
    public let violations: [EvidenceViolation]
    public let complianceReport: ComplianceReport
    public let documents: [DocumentMetadata]
    public let queries: [QueryRecord]
    public let exportTimestamp: Date
    public let bundleHash: String

    public init(
        sessionId: String,
        chainValidation: EvidenceChainValidation,
        evidence: [Evidence],
        violations: [EvidenceViolation],
        complianceReport: ComplianceReport,
        documents: [DocumentMetadata],
        queries: [QueryRecord],
        exportTimestamp: Date,
        bundleHash: String
    ) {
        self.sessionId = sessionId
        self.chainValidation = chainValidation
        self.evidence = evidence
        self.violations = violations
        self.complianceReport = complianceReport
        self.documents = documents
        self.queries = queries
        self.exportTimestamp = exportTimestamp
        self.bundleHash = bundleHash
    }

    /// Whether this bundle is court-admissible
    public var isCourtAdmissible: Bool {
        return chainValidation.isValid &&
               complianceReport.isCompliant &&
               violations.filter { $0.severity == .critical }.isEmpty
    }
}

// MARK: - Convenience Factory

public extension CathedralModule {
    /// Create complete Cathedral facade with all subsystems
    static func createFacade(
        config: CathedralConfig = defaultConfig,
        database: (any DatabaseCore.DatabaseExecutor)? = nil,
        mlService: (any CathedralMLService)? = nil
    ) async -> CathedralFacade {
        // Create database persistence layer if database provided
        let persistence = database.map { CathedralDatabasePersistence(database: $0) }

        // Create tamper system
        let tamperSystem = TamperEvidenceSystem(database: database)

        // Load existing evidence chain from database
        if database != nil {
            try? await tamperSystem.loadFromDatabase()
        }

        // Create evidence substrate
        let evidenceSubstrate = EvidenceSubstrate(
            tamperSystem: tamperSystem,
            config: config
        )

        // Create coordinator with ML service
        let coordinator = CathedralCoordinatorImpl(
            evidenceSubstrate: evidenceSubstrate,
            config: config,
            mlService: mlService
        )

        // Create enforcement system
        let enforcementSystem = EvidenceEnforcementSystem(
            evidenceSubstrate: evidenceSubstrate,
            config: config,
            persistence: persistence
        )

        // Create forensic tracker
        let forensicTracker = ForensicMetadataTracker(
            evidenceSubstrate: evidenceSubstrate,
            persistence: persistence
        )

        // Create retrieval explainer
        let retrievalExplainer = RetrievalExplainability(
            evidenceSubstrate: evidenceSubstrate,
            persistence: persistence
        )
        let fusedKernelPlanner = CathedralFusedKernelPlanner()

        return CathedralFacade(
            coordinator: coordinator,
            evidenceSubstrate: evidenceSubstrate,
            tamperSystem: tamperSystem,
            enforcementSystem: enforcementSystem,
            forensicTracker: forensicTracker,
            retrievalExplainer: retrievalExplainer,
            fusedKernelPlanner: fusedKernelPlanner,
            config: config
        )
    }
}
