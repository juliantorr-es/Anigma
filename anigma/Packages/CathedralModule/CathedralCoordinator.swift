//
//  CathedralCoordinator.swift
//  CathedralModule
//
//  Evidence-driven coordination system implementing Cathedral invariants
//

import Foundation
import ContractsCore
import DatabaseCore

// MARK: - Cathedral Coordinator Protocol

public protocol CathedralCoordinator: Sendable {
    func validateEvidenceChain(sessionId: String) async throws -> EvidenceChainValidation
    func recordEvidence(_ evidence: Evidence) async throws
    func enforceOperation(_ operation: MLOperation, requirement: EvidenceRequirement) async throws -> EvidenceEnforcementResult
    func executeWithEvidence(operation: MLOperation, requirement: EvidenceRequirement) async throws -> OperationResult
}

// MARK: - Cathedral Coordinator Implementation

/// Production Cathedral coordinator with full evidence enforcement
public actor CathedralCoordinatorImpl: CathedralCoordinator {
    private let evidenceSubstrate: EvidenceSubstrate
    private let config: CathedralConfig
    private let mlService: CathedralMLService?
    private var executionLeases: [String: ExecutionLease] = [:]

    public init(
        evidenceSubstrate: EvidenceSubstrate,
        config: CathedralConfig = CathedralConfig(),
        mlService: CathedralMLService? = nil
    ) {
        self.evidenceSubstrate = evidenceSubstrate
        self.config = config
        self.mlService = mlService
    }

    // MARK: - Evidence Chain Validation

    public func validateEvidenceChain(sessionId: String) async throws -> EvidenceChainValidation {
        return try await evidenceSubstrate.validateChain(sessionId: sessionId)
    }

    // MARK: - Evidence Recording

    public func recordEvidence(_ evidence: Evidence) async throws {
        try await evidenceSubstrate.recordEvidence(evidence)
    }

    // MARK: - Operation Enforcement (Invariant #1)

    /// Enforce evidence requirements before allowing operation
    public func enforceOperation(
        _ operation: MLOperation,
        requirement: EvidenceRequirement = .moderate
    ) async throws -> EvidenceEnforcementResult {
        // Enforce evidence substrate (Invariant #1)
        let enforcementResult = try await evidenceSubstrate.enforceEvidenceSubstrate(
            operation: operation,
            requirement: requirement
        )

        guard enforcementResult.isAllowed else {
            throw CathedralError.validationFailed([
                "Operation \(operation.type.rawValue) blocked by evidence enforcement"
            ])
        }

        return enforcementResult
    }

    // MARK: - Execution Leases (Invariant #4)

    /// Create time-bounded execution lease
    public func createExecutionLease(
        for operation: MLOperation,
        durationSeconds: TimeInterval = 300
    ) async throws -> ExecutionLease {
        let lease = ExecutionLease(
            id: UUID().uuidString,
            operationId: operation.id,
            sessionId: operation.sessionId,
            startTime: Date(),
            expiryTime: Date().addingTimeInterval(durationSeconds),
            status: .active
        )

        executionLeases[lease.id] = lease

        // Record lease creation as evidence
        let leaseEvidence = Evidence(
            type: .operationExecution,
            sessionId: operation.sessionId,
            agentId: operation.agentId,
            contentHash: lease.id.blake3Hash,
            metadata: EvidenceMetadata(
                source: "CathedralCoordinator",
                operation: "createExecutionLease",
                parameters: [
                    "leaseId": lease.id,
                    "operationId": operation.id,
                    "duration": String(durationSeconds)
                ],
                quality: .verified,
                expiryTime: lease.expiryTime
            )
        )

        try await evidenceSubstrate.recordEvidence(leaseEvidence)

        return lease
    }

    /// Validate execution lease is still active
    public func validateLease(_ leaseId: String) async throws -> Bool {
        guard let lease = executionLeases[leaseId] else {
            throw CathedralError.evidenceTimeout("Lease \(leaseId) not found")
        }

        let now = Date()
        guard now < lease.expiryTime else {
            throw CathedralError.evidenceTimeout("Lease \(leaseId) expired at \(lease.expiryTime)")
        }

        return lease.status == .active
    }

    // MARK: - Plan Coordination

    /// Execute evidence-backed plan with time-bounded lease
    public func executeWithEvidence(
        operation: MLOperation,
        requirement: EvidenceRequirement = .moderate
    ) async throws -> OperationResult {
        // 1. Enforce evidence requirements (Invariant #1)
        let enforcement = try await enforceOperation(operation, requirement: requirement)

        // 2. Create execution lease (Invariant #4)
        let lease = try await createExecutionLease(for: operation)

        // 3. Execute operation (this would call actual ML services)
        let result = try await executeOperation(operation, lease: lease)

        // 4. Record result as evidence (Invariant #3)
        let resultEvidence = Evidence(
            type: .operationExecution,
            sessionId: operation.sessionId,
            agentId: operation.agentId,
            contentHash: result.id.blake3Hash,
            metadata: EvidenceMetadata(
                source: "CathedralCoordinator",
                operation: "executeWithEvidence",
                parameters: [
                    "operationId": operation.id,
                    "leaseId": lease.id,
                    "status": result.status.rawValue
                ],
                quality: .verified
            )
        )

        try await evidenceSubstrate.recordEvidence(resultEvidence)

        return result
    }

    private func executeOperation(
        _ operation: MLOperation,
        lease: ExecutionLease
    ) async throws -> OperationResult {
        // Verify lease is still valid
        _ = try await validateLease(lease.id)

        // Execute through ML service if available
        if let mlService = mlService {
            let mlResult = try await mlService.executeOperation(operation)

            return OperationResult(
                id: UUID().uuidString,
                operationId: operation.id,
                status: mlResult.status,
                timestamp: Date(),
                data: mlResult.data
            )
        }

        throw CathedralError.configurationError("Cathedral ML service backend is required for end-to-end execution")
    }
}

// MARK: - Execution Lease

public struct ExecutionLease: Sendable, Codable {
    public let id: String
    public let operationId: String
    public let sessionId: String
    public let startTime: Date
    public let expiryTime: Date
    public let status: LeaseStatus

    public enum LeaseStatus: String, Sendable, Codable {
        case active = "active"
        case expired = "expired"
        case revoked = "revoked"
    }

    public init(
        id: String,
        operationId: String,
        sessionId: String,
        startTime: Date,
        expiryTime: Date,
        status: LeaseStatus
    ) {
        self.id = id
        self.operationId = operationId
        self.sessionId = sessionId
        self.startTime = startTime
        self.expiryTime = expiryTime
        self.status = status
    }
}

// MARK: - Operation Result

public struct OperationResult: Sendable, Codable {
    public let id: String
    public let operationId: String
    public let status: OperationExecutionStatus
    public let timestamp: Date
    public let data: [String: String]

    public init(
        id: String,
        operationId: String,
        status: OperationExecutionStatus,
        timestamp: Date,
        data: [String: String]
    ) {
        self.id = id
        self.operationId = operationId
        self.status = status
        self.timestamp = timestamp
        self.data = data
    }
}
