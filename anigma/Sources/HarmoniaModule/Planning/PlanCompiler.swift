//
//  PlanCompiler.swift
//  Phase H Evidence-Producing Plan Compiler
//  Transforms planning from "what feels right" to "what can be proven from evidence"
//
//  This implements the core Cathedral invariant: no coordination without verifiable evidence
//

import Foundation
import DatabaseCore
import ContractsCore
import AnigmaCore
import HarmoniaV2Surface
import TelemetryCore

/// Plan Compiler that transforms planning into evidence-producing transformations
/// Instead of generating plans based on heuristics, it creates plans that are
/// provably justified by evidence and can be validated through cryptographic verification
public actor PlanCompiler {
    private let dbActor: DatabaseActor
    private let evidenceSubstrate: EvidenceSubstrate
    private let telemetry: TelemetryClient
    
    public init(
        dbActor: DatabaseActor,
        evidenceSubstrate: EvidenceSubstrate,
        telemetry: TelemetryClient? = nil
    ) {
        self.dbActor = dbActor
        self.evidenceSubstrate = evidenceSubstrate
        self.telemetry = telemetry ?? TelemetryClient.forDevelopment()
    }
    
    // MARK: - Evidence-Producing Plan Generation
    
    /// Generate a Cathedral plan that is provably justified by evidence
    /// This is the core Phase H transformation: planning becomes evidence-producing
    public func generateEvidenceProducedPlan(
        request: PlanRequest
    ) async throws -> EvidenceProducedPlan {
        
        // Log plan generation start
        _ = await telemetry.emit(
            category: .workflow,
            name: "harmonia.plan.generation_start",
            privacyClassification: .internal,
            values: [
                "operation_type": .hashedToken(TelemetryHash(input: request.operationType)),
                "priority": .string(request.priority.rawValue)
            ]
        )
        
        // Step 1: Gather evidence requirements for this operation type
        let evidenceRequirements = try await gatherEvidenceRequirements(for: request.operationType)
        
        // Step 2: Validate current evidence against requirements
        let evidenceValidation = try await validateCurrentEvidence(
            requirements: evidenceRequirements,
            context: request.sessionContext
        )
        
        // Step 3: If evidence insufficient, BLOCK (Cathedral invariant)
        guard evidenceValidation.hasSufficientEvidence else {
            let blockedPlan = EvidenceProducedPlan(
                id: UUID().uuidString.lowercased(),
                operationType: request.operationType,
                status: .blocked,
                reason: .insufficientEvidence(evidenceValidation.violations),
                evidenceDigest: calculateEvidenceDigest(evidenceDependencies: evidenceValidation.evidenceDependencies),
                createdAt: Date(),
                executionLease: nil,
                conflictResolution: nil
            )
            
            // Log governance blocking decision (CRITICAL for compliance audit trail)
            _ = await telemetry.emit(
                category: .security,
                name: "harmonia.plan.blocked",
                privacyClassification: .internal,
                values: [
                    "plan_id": .hashedToken(TelemetryHash(input: blockedPlan.id)),
                    "operation_type": .hashedToken(TelemetryHash(input: request.operationType)),
                    "required_evidence": .string(evidenceRequirements.requirement.rawValue),
                    "current_evidence": .string(evidenceValidation.currentLevel.rawValue),
                    "violation_count": .integer(evidenceValidation.violations.count),
                    "blocking_reason": .string("insufficient_evidence")
                ]
            )
            
            // Record the blocking decision as evidence itself
            try await recordPlanEvidence(plan: blockedPlan)
            
            return blockedPlan
        }
        
        // Step 4: Generate evidence-backed plan
        let plan = try await createEvidenceBackedPlan(
            request: request,
            evidenceRequirements: evidenceRequirements,
            evidenceValidation: evidenceValidation
        )
        
        // Log successful plan approval (CRITICAL for compliance audit trail)
        _ = await telemetry.emit(
            category: .audit,
            name: "harmonia.plan.approved",
            privacyClassification: .internal,
            values: [
                "plan_id": .hashedToken(TelemetryHash(input: plan.id)),
                "operation_type": .hashedToken(TelemetryHash(input: request.operationType)),
                "evidence_dependencies": .integer(plan.evidenceDigest.dependencies.count),
                "plan_hash": .hashedToken(TelemetryHash(input: plan.evidenceDigest.hash)),
                "lease_duration_seconds": .integer(Int(plan.executionLease?.durationSeconds ?? 0)),
                "evidence_level": .string(evidenceValidation.currentLevel.rawValue)
            ]
        )
        
        return plan
    }
    
    // MARK: - Evidence Gathering & Validation
    
    /// Gather evidence requirements for a specific operation type
    private func gatherEvidenceRequirements(
        for operationType: String
    ) async throws -> EvidenceRequirements {
        
        // Define evidence requirements based on operation criticality
        switch operationType {
        case "code_generation", "model_training", "system_modification":
            return EvidenceRequirements(
                requirement: .high,
                minimumCount: 3,
                recentTimeframeSeconds: 300,
                allowedEvidenceTypes: [.tamperEvents, .forensicAcquisition, .retrievalReceipts]
            )
            
        case "document_ingestion", "embedding_generation", "semantic_search":
            return EvidenceRequirements(
                requirement: .moderate,
                minimumCount: 2,
                recentTimeframeSeconds: 180,
                allowedEvidenceTypes: [.forensicAcquisition, .retrievalReceipts]
            )
            
        case "user_query", "configuration_change":
            return EvidenceRequirements(
                requirement: .low,
                minimumCount: 1,
                recentTimeframeSeconds: 60,
                allowedEvidenceTypes: [.tamperEvents]
            )
            
        default:
            return EvidenceRequirements(
                requirement: .strict,
                minimumCount: 1,
                recentTimeframeSeconds: 600,
                allowedEvidenceTypes: [.tamperEvents, .forensicAcquisition, .retrievalReceipts]
            )
        }
    }
    
    /// Validate current evidence against requirements
    private func validateCurrentEvidence(
        requirements: EvidenceRequirements,
        context: String?
    ) async throws -> EvidenceValidation {
        
        // Gather recent evidence based on requirements
        let recentEvidence = try await gatherRecentEvidence(
            requirements: requirements,
            context: context
        )
        
        // Check evidence count requirements
        let countValid = recentEvidence.count >= requirements.minimumCount
        
        // Check evidence type requirements
        let typeValid = requirements.allowedEvidenceTypes.allSatisfy(recentEvidence.types)
        
        // Check recency requirements
        let recencyValid = recentEvidence.allSatisfy { $0.ageSeconds <= requirements.recentTimeframeSeconds }
        
        // Calculate current evidence level
        let currentLevel = calculateEvidenceLevel(
            count: recentEvidence.count,
            types: typeValid,
            recency: recencyValid
        )
        
        // Collect violations
        var violations: [EvidenceViolation] = []
        
        if !countValid {
            violations.append(EvidenceViolation(
                id: UUID().uuidString.lowercased(),
                evidenceId: "evidence_count_check",
                violationType: .insufficientEvidence,
                severity: .high,
                description: "Insufficient evidence count: required \(requirements.minimumCount), found \(recentEvidence.count)"
            ))
        }
        
        if !typeValid {
            violations.append(EvidenceViolation(
                id: UUID().uuidString.lowercased(),
                evidenceId: "evidence_type_check",
                violationType: .requirementMismatch,
                severity: .medium,
                description: "Invalid evidence types for operation: allowed \(requirements.allowedEvidenceTypes.map(\.rawValue).joined(separator: ", ")), found \(recentEvidence.types.map(\.rawValue).joined(separator: ", "))"
            ))
        }
        
        if !recencyValid {
            violations.append(EvidenceViolation(
                id: UUID().uuidString.lowercased(),
                evidenceId: "evidence_recency_check",
                violationType: .expiredEvidence,
                severity: .medium,
                description: "Evidence too old: maximum age \(requirements.recentTimeframeSeconds)s, oldest evidence is \(recentEvidence.max { $0.ageSeconds }.ageSeconds)s"
            ))
        }
        
        return EvidenceValidation(
            hasSufficientEvidence: violations.isEmpty && currentLevel >= requirements.requirement,
            currentLevel: currentLevel,
            violations: violations,
            evidenceDependencies: recentEvidence
        )
    }
    
    // MARK: - Evidence-Backed Plan Creation
    
    /// Create a plan that is provably backed by evidence
    private func createEvidenceBackedPlan(
        request: PlanRequest,
        evidenceRequirements: EvidenceRequirements,
        evidenceValidation: EvidenceValidation
    ) async throws -> EvidenceProducedPlan {
        
        let planId = UUID().uuidString.lowercased()
        let evidenceDigest = calculateEvidenceDigest(evidenceDependencies: evidenceValidation.evidenceDependencies)
        
        // Generate execution lease with time boundaries
        let executionLease = ExecutionLease(
            leaseId: UUID().uuidString.lowercased(),
            planHash: evidenceDigest.hash,
            nodeHash: await getNodeHash(),
            startTime: Date(),
            durationSeconds: 300, // 5 minute execution window
            renewalCount: 0,
            maxRenewals: 3
        )
        
        // Create conflict resolution strategy
        let conflictResolution = ConflictResolution(
            strategy: .lastWriterWins,
            requiresEvidenceRevalidation: true,
            evidenceThreshold: .moderate
        )
        
        let plan = EvidenceProducedPlan(
            id: planId,
            operationType: request.operationType,
            status: .approved,
            reason: .evidenceBacked(
                evidenceDigest: evidenceDigest,
                confidence: evidenceValidation.currentLevel.confidence,
                assumptions: extractAssumptions(from: evidenceValidation.evidenceDependencies)
            ),
            evidenceDigest: evidenceDigest,
            createdAt: Date(),
            executionLease: executionLease,
            conflictResolution: conflictResolution
        )
        
        // Record the plan generation as evidence
        try await recordPlanEvidence(plan: plan)
        
        return plan
    }
    
    // MARK: - Evidence Utilities
    
    /// Calculate evidence level from collected evidence
    private func calculateEvidenceLevel(
        count: Int,
        types: Bool,
        recency: Bool
    ) -> EvidenceRequirement {
        
        if count >= 5 && types && recency {
            return .high
        } else if count >= 2 && types {
            return .moderate
        } else if count >= 1 {
            return .low
        } else {
            return .none
        }
    }
    
    /// Calculate evidence digest for plan verification
    private func calculateEvidenceDigest(evidenceDependencies: [EvidenceDependency]) -> EvidenceDigest {
        let dependencyHashes = evidenceDependencies.map(\.hash).sorted()
        let combinedHash = dependencyHashes.joined(separator: "|")
        let digestHash = SHA256.hash(data: Data(combinedHash.utf8))
        
        return EvidenceDigest(
            hash: digestHash.hexString,
            dependencies: evidenceDependencies,
            algorithm: "sha256",
            timestamp: Date()
        )
    }
    
    /// Get current node hash for execution
    private func getNodeHash() async -> String {
        // In a real system, this would be a cryptographic hash of the execution environment
        // For now, use a deterministic hash based on system configuration
        let config = [
            "node_version": "1.0.0",
            "cathedral_version": "1.0.0",
            "swift_version": "6.0",
            "platform": "macos"
        ]
        
        return SHA256.hash(data: Data(config.joined(separator: "|").utf8)).hexString
    }
    
    /// Extract assumptions from evidence dependencies
    private func extractAssumptions(from dependencies: [EvidenceDependency]) -> [String] {
        return dependencies.map { dependency in
            switch dependency.type {
            case .tamperEvidence:
                return "Tamper evidence chain is intact"
            case .forensicAcquisition:
                return "File forensics are reliable"
            case .retrievalReceipt:
                return "Retrieval results are reproducible"
            case .mlModelResult:
                return "ML model outputs are consistent"
            case .userInteraction:
                return "User interactions are authorized"
            }
        }
    }
    
    /// Record plan generation as evidence
    private func recordPlanEvidence(plan: EvidenceProducedPlan) async throws {
        _ = try await evidenceSubstrate.performMLOperation(
            operationType: .documentIngestion, // Reuse existing operation type
            inputs: [
                "plan_id": plan.id,
                "operation_type": plan.operationType,
                "plan_status": plan.status.rawValue,
                "evidence_digest_hash": plan.evidenceDigest.hash,
                "lease_duration": plan.executionLease?.durationSeconds ?? 0,
                "node_hash": plan.executionLease?.nodeHash ?? ""
            ] as [String: Sendable],
            actor: "plan_compiler",
            purpose: "evidence_produced_plan_generation"
        )
    }
}

// MARK: - Supporting Types

/// Plan request for evidence-producing transformation
public struct PlanRequest: Sendable {
    public let operationType: String
    public let sessionContext: String?
    public let parameters: [String: Sendable]
    public let priority: Priority
    
    public enum Priority: String, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
    }
}

/// Evidence requirements for Cathedral planning
public struct EvidenceRequirements: Sendable {
    public let requirement: EvidenceRequirement
    public let minimumCount: Int
    public let recentTimeframeSeconds: TimeInterval
    public let allowedEvidenceTypes: [EvidenceType]
    
    public init(
        requirement: EvidenceRequirement,
        minimumCount: Int,
        recentTimeframeSeconds: TimeInterval,
        allowedEvidenceTypes: [EvidenceType]
    ) {
        self.requirement = requirement
        self.minimumCount = minimumCount
        self.recentTimeframeSeconds = recentTimeframeSeconds
        self.allowedEvidenceTypes = allowedEvidenceTypes
    }
}

/// Evidence validation result
public struct EvidenceValidation: Sendable {
    public let hasSufficientEvidence: Bool
    public let currentLevel: EvidenceRequirement
    public let violations: [EvidenceViolation]
    public let evidenceDependencies: [EvidenceDependency]
    
    public init(
        hasSufficientEvidence: Bool,
        currentLevel: EvidenceRequirement,
        violations: [EvidenceViolation] = [],
        evidenceDependencies: [EvidenceDependency] = []
    ) {
        self.hasSufficientEvidence = hasSufficientEvidence
        self.currentLevel = currentLevel
        self.violations = violations
        self.evidenceDependencies = evidenceDependencies
    }
}

/// Recent evidence collection
public struct RecentEvidence: Sendable {
    public let dependencies: [EvidenceDependency]
    public let types: Set<EvidenceType>
    public let maxAgeSeconds: TimeInterval
    
    public var allSatisfy<T>(_ condition: (RecentEvidence) -> Bool) -> Bool {
        return dependencies.allSatisfy(condition) && types.allSatisfy(condition)
    }
    
    public var count: Int { dependencies.count }
    public var max: RecentEvidence? { dependencies.max(by: \.ageSeconds) }
}

/// Evidence dependency for plan verification
public struct EvidenceDependency: Sendable, Hashable {
    public let id: String
    public let type: EvidenceType
    public let hash: String
    public let ageSeconds: TimeInterval
    public let confidence: Double
    
    public init(
        id: String,
        type: EvidenceType,
        hash: String,
        ageSeconds: TimeInterval,
        confidence: Double
    ) {
        self.id = id
        self.type = type
        self.hash = hash
        self.ageSeconds = ageSeconds
        self.confidence = confidence
    }
}

/// Evidence types accepted for planning
public enum EvidenceType: String, CaseIterable {
    case tamperEvidence = "tamper_evidence"
    case forensicAcquisition = "forensic_acquisition"
    case retrievalReceipts = "retrieval_receipts"
    case mlModelResult = "ml_model_result"
    case userInteraction = "user_interaction"
    
    public static func allSatisfy<T>(_ condition: (EvidenceDependency) -> Bool) -> Bool {
        return AllCases.allCases.allSatisfy(condition)
    }
}

/// Evidence digest for cryptographic verification
public struct EvidenceDigest: Sendable, Codable {
    public let hash: String
    public let dependencies: [EvidenceDependency]
    public let algorithm: String
    public let timestamp: Date
    
    public init(
        hash: String,
        dependencies: [EvidenceDependency],
        algorithm: String,
        timestamp: Date
    ) {
        self.hash = hash
        self.dependencies = dependencies
        self.algorithm = algorithm
        self.timestamp = timestamp
    }
}

/// Evidence-produced plan - the core Phase H transformation
public struct EvidenceProducedPlan: Sendable, Codable {
    public let id: String
    public let operationType: String
    public let status: PlanStatus
    public let reason: PlanReason
    public let evidenceDigest: EvidenceDigest
    public let createdAt: Date
    public let executionLease: ExecutionLease?
    public let conflictResolution: ConflictResolution?
    
    public init(
        id: String,
        operationType: String,
        status: PlanStatus,
        reason: PlanReason,
        evidenceDigest: EvidenceDigest,
        createdAt: Date,
        executionLease: ExecutionLease?,
        conflictResolution: ConflictResolution?
    ) {
        self.id = id
        self.operationType = operationType
        self.status = status
        self.reason = reason
        self.evidenceDigest = evidenceDigest
        self.createdAt = createdAt
        self.executionLease = executionLease
        self.conflictResolution = conflictResolution
    }
}

/// Plan status
public enum PlanStatus: String, CaseIterable {
    case blocked = "blocked"
    case approved = "approved"
    case executing = "executing"
    case completed = "completed"
    case failed = "failed"
}

/// Plan reason
public enum PlanReason: Sendable, Codable {
    case insufficientEvidence([EvidenceViolation])
    case evidenceBacked(evidenceDigest: EvidenceDigest, confidence: Double, assumptions: [String])
    case executionFailed(String)
    case conflictDetected(String)
}

/// Execution lease for time-bounded operations
public struct ExecutionLease: Sendable, Codable {
    public let leaseId: String
    public let planHash: String
    public let nodeHash: String
    public let startTime: Date
    public let durationSeconds: TimeInterval
    public let renewalCount: Int
    public let maxRenewals: Int
    
    public init(
        leaseId: String,
        planHash: String,
        nodeHash: String,
        startTime: Date,
        durationSeconds: TimeInterval,
        renewalCount: Int = 0,
        maxRenewals: Int = 3
    ) {
        self.leaseId = leaseId
        self.planHash = planHash
        self.nodeHash = nodeHash
        self.startTime = startTime
        self.durationSeconds = durationSeconds
        self.renewalCount = renewalCount
        self.maxRenewals = maxRenewals
    }
}

/// Conflict resolution strategy
public struct ConflictResolution: Sendable, Codable {
    public let strategy: ConflictStrategy
    public let requiresEvidenceRevalidation: Bool
    public let evidenceThreshold: EvidenceRequirement
    
    public init(
        strategy: ConflictStrategy,
        requiresEvidenceRevalidation: Bool,
        evidenceThreshold: EvidenceRequirement
    ) {
        self.strategy = strategy
        self.requiresEvidenceRevalidation = requiresEvidenceRevalidation
        self.evidenceThreshold = evidenceThreshold
    }
}

/// Conflict resolution strategies
public enum ConflictStrategy: String, CaseIterable {
    case lastWriterWins = "last_writer_wins"
    case firstWriterWins = "first_writer_wins"
    case requiresQuorum = "requires_quorum"
    case evidenceRevalidation = "evidence_revalidation"
}