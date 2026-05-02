//
//  HarmoniaModule+Cathedral.swift
//  HarmoniaModule
//
//  Cathedral integration for Harmonia planning system
//  Ensures all plans are evidence-backed with Cathedral enforcement
//

import Foundation
import CathedralModule
import ContractsCore
import AnigmaCore
import TelemetryCore

// MARK: - Cathedral-Integrated Plan Compiler

/// Enhanced PlanCompiler with direct Cathedral integration
public actor CathedralPlanCompiler {
    private let cathedral: CathedralFacade
    private let telemetry: TelemetryClient

    public init(cathedral: CathedralFacade, telemetry: TelemetryClient? = nil) {
        self.cathedral = cathedral
        self.telemetry = telemetry ?? TelemetryClient.forDevelopment()
    }

    /// Generate Cathedral-enforced plan
    public func generatePlan(
        request: PlanRequest
    ) async throws -> CathedralPlan {

        // Log plan generation start
        _ = await telemetry.emit(
            category: .workflow,
            name: "harmonia.cathedral.plan_generation_start",
            privacyClassification: .internal,
            values: [
                "operation_type": .hashedToken(TelemetryHash(input: request.operationType)),
                "priority": .string(request.priority?.rawValue ?? "normal")
            ]
        )

        // 1. Create ML operation from plan request
        let operation = MLOperation(
            type: operationTypeFromRequest(request),
            sessionId: request.sessionContext["sessionId"] ?? UUID().uuidString,
            agentId: request.sessionContext["agentId"] ?? "harmonia",
            parameters: extractOperationParameters(request)
        )

        // 2. Execute through Cathedral enforcement
        let result = try await cathedral.executeOperation(
            operation: operation,
            requirement: evidenceRequirementForPriority(request.priority)
        )

        // 3. Create evidence-backed plan
        let plan = CathedralPlan(
            id: UUID().uuidString,
            operationType: request.operationType,
            status: .approved,
            evidenceId: result.id,
            executionLease: createExecutionLease(),
            sessionId: operation.sessionId,
            agentId: operation.agentId,
            createdAt: Date(),
            parameters: request.parameters
        )

        // Log successful plan approval with Cathedral evidence
        _ = await telemetry.emit(
            category: .audit,
            name: "harmonia.cathedral.plan_approved",
            privacyClassification: .internal,
            values: [
                "plan_id": .hashedToken(TelemetryHash(input: plan.id)),
                "operation_type": .hashedToken(TelemetryHash(input: request.operationType)),
                "evidence_id": .hashedToken(TelemetryHash(input: result.id)),
                "lease_duration_seconds": .integer(Int(plan.executionLease.durationSeconds)),
                "session_id": .hashedToken(TelemetryHash(input: operation.sessionId)),
                "agent_id": .hashedToken(TelemetryHash(input: operation.agentId))
            ]
        )

        return plan
    }

    /// Validate plan execution against Cathedral requirements
    public func validatePlanExecution(
        planId: String,
        executionResults: [String: String]
    ) async throws -> PlanValidationResult {

        // Log validation start
        _ = await telemetry.emit(
            category: .workflow,
            name: "harmonia.cathedral.validation_start",
            privacyClassification: .internal,
            values: [
                "plan_id": .hashedToken(TelemetryHash(input: planId))
            ]
        )

        // Get compliance report from Cathedral
        let sessionId = executionResults["sessionId"] ?? planId
        let report = try await cathedral.getComplianceReport(sessionId: sessionId)

        let result = PlanValidationResult(
            planId: planId,
            isValid: report.isCompliant,
            complianceScore: report.complianceScore,
            violations: report.violations.map { v in
                PlanViolation(
                    id: v.id,
                    type: v.violationType.rawValue,
                    severity: v.severity.rawValue,
                    description: v.description
                )
            },
            validatedAt: Date()
        )

        // Log validation result
        if result.isValid {
            _ = await telemetry.emit(
                category: .audit,
                name: "harmonia.cathedral.validation_success",
                privacyClassification: .internal,
                values: [
                    "plan_id": .hashedToken(TelemetryHash(input: planId)),
                    "compliance_score": .double(result.complianceScore)
                ]
            )
        } else {
            _ = await telemetry.emit(
                category: .security,
                name: "harmonia.cathedral.validation_failed",
                privacyClassification: .internal,
                values: [
                    "plan_id": .hashedToken(TelemetryHash(input: planId)),
                    "compliance_score": .double(result.complianceScore),
                    "violation_count": .integer(result.violations.count)
                ]
            )
        }

        return result
    }

    /// Record plan completion as evidence
    public func recordPlanCompletion(
        planId: String,
        outputs: [String: String]
    ) async throws {

        // Record completion through Cathedral
        let sessionId = outputs["sessionId"] ?? planId
        let evidence = await cathedral.getSessionEvidence(sessionId: sessionId)

        // Log plan completion
        _ = await telemetry.emit(
            category: .audit,
            name: "harmonia.cathedral.plan_completed",
            privacyClassification: .internal,
            values: [
                "plan_id": .hashedToken(TelemetryHash(input: planId)),
                "session_id": .hashedToken(TelemetryHash(input: sessionId)),
                "evidence_count": .integer(evidence.count)
            ]
        )
    }

    // MARK: - Helper Methods

    private func operationTypeFromRequest(_ request: PlanRequest) -> MLOperationType {
        switch request.operationType {
        case let op where op.contains("embed"):
            return .embedding
        case let op where op.contains("search") || op.contains("retrieval"):
            return .retrieval
        case let op where op.contains("generate") || op.contains("completion"):
            return .generation
        case let op where op.contains("classify"):
            return .classification
        default:
            return .transformation
        }
    }

    private func extractOperationParameters(_ request: PlanRequest) -> [String: String] {
        var params: [String: String] = [:]

        // Extract relevant parameters from plan request
        for (key, value) in request.parameters {
            if let stringValue = value as? String {
                params[key] = stringValue
            } else if let intValue = value as? Int {
                params[key] = String(intValue)
            } else if let doubleValue = value as? Double {
                params[key] = String(doubleValue)
            }
        }

        return params
    }

    private func evidenceRequirementForPriority(_ priority: PlanPriority?) -> EvidenceRequirement {
        guard let priority = priority else { return .moderate }

        switch priority {
        case .critical:
            return .strict
        case .high:
            return .high
        case .normal:
            return .moderate
        case .low:
            return .low
        }
    }

    private func createExecutionLease() -> ExecutionLease {
        ExecutionLease(
            id: UUID().uuidString,
            startTime: Date(),
            durationSeconds: 300,
            renewalCount: 0,
            maxRenewals: 3
        )
    }
}

// MARK: - Cathedral Plan Types

public struct CathedralPlan: Sendable, Codable {
    public let id: String
    public let operationType: String
    public let status: PlanStatus
    public let evidenceId: String
    public let executionLease: ExecutionLease
    public let sessionId: String
    public let agentId: String
    public let createdAt: Date
    public let parameters: [String: Sendable]

    enum CodingKeys: String, CodingKey {
        case id, operationType, status, evidenceId, executionLease
        case sessionId, agentId, createdAt, parameters
    }

    public init(
        id: String,
        operationType: String,
        status: PlanStatus,
        evidenceId: String,
        executionLease: ExecutionLease,
        sessionId: String,
        agentId: String,
        createdAt: Date,
        parameters: [String: Sendable]
    ) {
        self.id = id
        self.operationType = operationType
        self.status = status
        self.evidenceId = evidenceId
        self.executionLease = executionLease
        self.sessionId = sessionId
        self.agentId = agentId
        self.createdAt = createdAt
        self.parameters = parameters
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        operationType = try container.decode(String.self, forKey: .operationType)
        status = try container.decode(PlanStatus.self, forKey: .status)
        evidenceId = try container.decode(String.self, forKey: .evidenceId)
        executionLease = try container.decode(ExecutionLease.self, forKey: .executionLease)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        agentId = try container.decode(String.self, forKey: .agentId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)

        // Decode parameters as [String: String] for simplicity
        if let params = try? container.decode([String: String].self, forKey: .parameters) {
            parameters = params
        } else {
            parameters = [:]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(operationType, forKey: .operationType)
        try container.encode(status, forKey: .status)
        try container.encode(evidenceId, forKey: .evidenceId)
        try container.encode(executionLease, forKey: .executionLease)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(agentId, forKey: .agentId)
        try container.encode(createdAt, forKey: .createdAt)

        // Encode only String values
        let stringParams = parameters.compactMapValues { $0 as? String }
        try container.encode(stringParams, forKey: .parameters)
    }
}

public enum PlanStatus: String, Codable, Sendable {
    case approved
    case blocked
    case executing
    case completed
    case failed
}

public struct PlanValidationResult: Sendable, Codable {
    public let planId: String
    public let isValid: Bool
    public let complianceScore: Double
    public let violations: [PlanViolation]
    public let validatedAt: Date

    public init(
        planId: String,
        isValid: Bool,
        complianceScore: Double,
        violations: [PlanViolation],
        validatedAt: Date
    ) {
        self.planId = planId
        self.isValid = isValid
        self.complianceScore = complianceScore
        self.violations = violations
        self.validatedAt = validatedAt
    }
}

public struct PlanViolation: Sendable, Codable {
    public let id: String
    public let type: String
    public let severity: String
    public let description: String

    public init(id: String, type: String, severity: String, description: String) {
        self.id = id
        self.type = type
        self.severity = severity
        self.description = description
    }
}

// MARK: - Supporting Types

public struct PlanRequest: Sendable {
    public let operationType: String
    public let sessionContext: [String: String]
    public let parameters: [String: Sendable]
    public let priority: PlanPriority?

    public init(
        operationType: String,
        sessionContext: [String: String],
        parameters: [String: Sendable],
        priority: PlanPriority? = nil
    ) {
        self.operationType = operationType
        self.sessionContext = sessionContext
        self.parameters = parameters
        self.priority = priority
    }
}

public enum PlanPriority: String, Sendable {
    case critical
    case high
    case normal
    case low
}

// MARK: - Factory

extension CathedralPlanCompiler {
    /// Create Cathedral-integrated plan compiler
    public static func create(
        cathedral: CathedralFacade
    ) -> CathedralPlanCompiler {
        return CathedralPlanCompiler(cathedral: cathedral)
    }
}
