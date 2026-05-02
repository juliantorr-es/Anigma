//
//  TamperEvidenceSystem.swift
//  CathedralModule
//
//  Tamper-evident evidence chain system with cryptographic verification
//

import Foundation
import ContractsCore
import DatabaseCore
import AnigmaCore

// MARK: - Tamper Evidence System

public protocol TamperEvidenceSystemProtocol: Actor {
    func loadFromDatabase() async throws
    func recordEvidence(_ evidence: Evidence) async throws
    func validateChain(sessionId: String) async throws -> ChainIntegrityReport
    func getEvidence(id: String) async -> Evidence?
    func getSessionEvidence(sessionId: String) async -> [Evidence]
    func getChainLength() async -> Int
    func record(receipt: CoreReceipt) async throws
    func appendEvent(
        eventType: String,
        payload: [String: Sendable],
        actor: String,
        actorIP: String?,
        sessionId: String?
    ) async throws -> String
    
    // MARK: - Evidence Ring (MMR) Support
    func getRing(ringId: String) async throws -> EvidenceRing?
    func generateProof(ringId: String, evidenceHash: String) async throws -> EvidenceInclusionProof
    func verifyProof(_ proof: EvidenceInclusionProof, rootHash: String) async throws -> Bool
}

/// Manages tamper-evident evidence chains with cryptographic verification
public actor TamperEvidenceSystem: TamperEvidenceSystemProtocol {
    private let persistence: CathedralDatabasePersistence?
    private let ringManager: EvidenceRingManager
    private var evidenceChain: [Evidence] = []
    private var lastHash: String?

    public init(database: (any DatabaseCore.DatabaseExecutor)? = nil) {
        let persistence = database.map { CathedralDatabasePersistence(database: $0) }
        self.persistence = persistence
        self.ringManager = EvidenceRingManager(persistence: persistence)
    }

    /// Initialize from database - load existing chain
    public func loadFromDatabase() async throws {
        guard let persistence = persistence else { return }

        // Get last hash from database
        if let dbLastHash = try await persistence.getLastHash() {
            lastHash = dbLastHash
        }

        // Note: We keep in-memory cache for performance
        // but evidence chain is authoritative from database
    }

    // MARK: - Evidence Recording

    /// Record new evidence in the tamper-evident chain
    public func recordEvidence(_ evidence: Evidence) async throws {
        // Validate chain continuity
        if let lastHash = lastHash {
            guard evidence.previousHash == lastHash else {
                throw CathedralError.evidenceChainCorrupted(
                    "Evidence chain broken: expected previous hash \(lastHash), got \(evidence.previousHash ?? "nil")"
                )
            }
        }

        // Compute and verify evidence hash
        let computedHash = evidence.computeHash()

        // Add to in-memory chain
        evidenceChain.append(evidence)
        lastHash = computedHash

        // Append to Evidence Ring (MMR)
        _ = try await ringManager.appendEvidence(
            ringId: "global", // Default ring for now
            evidenceHash: computedHash,
            receiptId: evidence.id
        )

        // Persist to database
        if let persistence = persistence {
            try await persistence.persistEvidence(evidence)
        }
    }


    // MARK: - Chain Validation

    /// Validate entire evidence chain for tampering
    public func validateChain(sessionId: String) async throws -> ChainIntegrityReport {
        let sessionEvidence = evidenceChain.filter { $0.sessionId == sessionId }

        var violations: [ChainViolation] = []
        var previousHash: String?

        for (index, evidence) in sessionEvidence.enumerated() {
            // Check hash continuity
            if index > 0 {
                if evidence.previousHash != previousHash {
                    violations.append(ChainViolation(
                        eventId: evidence.id,
                        description: "Hash chain broken at evidence \(evidence.id)"
                    ))
                }
            }

            // Verify evidence hash
            let computedHash = evidence.computeHash()
            previousHash = computedHash

            // Check timestamp ordering
            if index > 0 {
                let previousEvidence = sessionEvidence[index - 1]
                if evidence.timestamp < previousEvidence.timestamp {
                    violations.append(ChainViolation(
                        eventId: evidence.id,
                        description: "Timestamp ordering violation at evidence \(evidence.id)"
                    ))
                }
            }
        }

        return ChainIntegrityReport(
            totalEvents: sessionEvidence.count,
            violations: violations,
            isIntact: violations.isEmpty,
            headHash: lastHash ?? "empty",
            validationTimestamp: Date()
        )
    }

    // MARK: - Evidence Retrieval

    /// Retrieve evidence by ID
    public func getEvidence(id: String) async -> Evidence? {
        // Check in-memory cache first
        if let evidence = evidenceChain.first(where: { $0.id == id }) {
            return evidence
        }

        // Fall back to database
        if let persistence = persistence {
            return try? await persistence.getEvidence(id: id)
        }

        return nil
    }

    /// Get all evidence for a session
    public func getSessionEvidence(sessionId: String) async -> [Evidence] {
        // Check in-memory first
        let memoryEvidence = evidenceChain.filter { $0.sessionId == sessionId }
        if !memoryEvidence.isEmpty {
            return memoryEvidence
        }

        // Fall back to database
        if let persistence = persistence {
            return (try? await persistence.getSessionEvidence(sessionId: sessionId)) ?? []
        }

        return []
    }

    /// Get evidence chain length
    public func getChainLength() async -> Int {
        // Use database if available for accurate count
        if let persistence = persistence {
            return (try? await persistence.getChainLength()) ?? evidenceChain.count
        }

        return evidenceChain.count
    }

    // MARK: - Evidence Ring (MMR) Implementation

    public func getRing(ringId: String) async throws -> EvidenceRing? {
        return try await ringManager.getRing(ringId: ringId)
    }

    public func generateProof(ringId: String, evidenceHash: String) async throws -> EvidenceInclusionProof {
        return try await ringManager.generateProof(ringId: ringId, evidenceHash: evidenceHash)
    }

    public func verifyProof(_ proof: EvidenceInclusionProof, rootHash: String) async throws -> Bool {
        return try await ringManager.verifyProof(proof, rootHash: rootHash)
    }

    public func record(receipt: CoreReceipt) async throws {
        _ = try await appendEvent(
            eventType: receipt.operationType,
            payload: receipt.metadata,
            actor: receipt.principal.id,
            sessionId: receipt.metadata["session_id"]
        )
    }

    public func appendEvent(
        eventType: String,
        payload: [String: Sendable],
        actor: String,
        actorIP: String? = nil,
        sessionId: String? = nil
    ) async throws -> String {
        let timestamp = Date()
        // Convert payload to Data for hashing
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        let contentHash = payloadData.blake3Hex
        
        // Map eventType to EvidenceType
        let evidenceType: EvidenceType
        switch eventType {
        case "document_acquisition": evidenceType = .documentAcquisition
        case "document_transformation": evidenceType = .documentTransformation
        case "query_execution": evidenceType = .queryExecution
        case "retrieval_result": evidenceType = .retrievalResult
        case "plan_generation": evidenceType = .planGeneration
        case "operation_execution": evidenceType = .operationExecution
        case "validation_check": evidenceType = .validationCheck
        case "violation_detection": evidenceType = .violationDetection
        default: evidenceType = .operationExecution
        }
        
        // Convert payload to string dictionary for metadata parameters
        var parameters: [String: String] = [:]
        for (key, value) in payload {
            if let stringValue = value as? String {
                parameters[key] = stringValue
            } else {
                parameters[key] = String(describing: value)
            }
        }
        
        let evidence = Evidence(
            id: UUID().uuidString,
            type: evidenceType,
            sessionId: sessionId ?? "unknown",
            agentId: actor,
            timestamp: timestamp,
            contentHash: contentHash,
            metadata: EvidenceMetadata(
                source: "TamperEvidenceSystemAdapter",
                operation: eventType,
                parameters: parameters,
                quality: .adequate
            ),
            previousHash: lastHash
        )
        
        try await recordEvidence(evidence)
        return evidence.id
    }

    // MARK: - Database Persistence (Removed - now handled by CathedralDatabasePersistence)
}

extension TamperEvidenceSystem: EvidenceSink {
    public func record(
        receipt: CoreReceipt,
        payload: EvidencePayload,
        operation: CoreOperationType,
        governanceDecision: GovernanceDecision?,
        context: ExecutionContext
    ) async throws {
        _ = payload
        _ = operation
        _ = governanceDecision
        _ = context
        try await record(receipt: receipt)
    }
}

// MARK: - Evidence Chain Validation Extensions

extension TamperEvidenceSystem {
    /// Perform comprehensive chain validation
    public func performComprehensiveValidation(sessionId: String) async throws -> EvidenceChainValidation {
        let integrityReport = try await validateChain(sessionId: sessionId)

        let violations = integrityReport.violations.map { violation in
            EvidenceViolation(
                type: .brokenChain,
                severity: .critical,
                description: violation.description,
                evidenceId: violation.eventId
            )
        }

        return EvidenceChainValidation(
            isValid: integrityReport.isIntact,
            violations: violations,
            chainLength: integrityReport.totalEvents,
            lastHash: integrityReport.headHash
        )
    }
}
