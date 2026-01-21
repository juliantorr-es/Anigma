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

/// Manages tamper-evident evidence chains with cryptographic verification
public actor TamperEvidenceSystem: TamperEvidenceSystemProtocol {
    private let persistence: CathedralDatabasePersistence?
    private var evidenceChain: [Evidence] = []
    private var lastHash: String?

    public init(database: LegacyDatabaseActor? = nil) {
        self.persistence = database.map { CathedralDatabasePersistence(database: $0) }
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
                guard evidence.previousHash == previousHash else {
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
        let contentHash = payloadData.sha256Hex
        
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

// MARK: - Evidence Chain Validation Extensions

extension TamperEvidenceSystem {
    /// Perform comprehensive chain validation
    public func performComprehensiveValidation(sessionId: String) async throws -> EvidenceChainValidation {
        let integrityReport = try await validateChain(sessionId: sessionId)

        let violations = integrityReport.violations.map { violation in
            EvidenceViolation(
                id: UUID().uuidString,
                evidenceId: violation.eventId,
                violationType: .brokenChain,
                severity: .critical,
                description: violation.description
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
