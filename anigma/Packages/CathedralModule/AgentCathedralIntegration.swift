//
//  AgentCathedralIntegration.swift
//  CathedralModule
//
//  Cathedral integration for Anigma agents
//  Provides evidence-backed operations for all agent types
//

import Foundation
import ContractsCore

// MARK: - Agent Cathedral Integration

/// Cathedral-integrated agent base protocol
public protocol CathedralAgent: Sendable {
    var agentId: String { get }
    var agentType: AgentType { get }
    var cathedral: CathedralFacade { get }

    /// Execute agent operation with evidence tracking
    func executeOperation(
        _ operation: AgentOperation,
        sessionId: String
    ) async throws -> AgentOperationResult
}

// MARK: - Agent Types

public enum AgentType: String, Sendable, Codable {
    case architect      // Planning and specification
    case builder        // Implementation
    case scribe         // Documentation
    case validator      // Testing and validation
    case techDebtScout  // Technical debt analysis
}

// MARK: - Agent Operation

public struct AgentOperation: Sendable, Codable {
    public let id: String
    public let type: AgentOperationType
    public let sessionId: String
    public let agentId: String
    public let parameters: [String: String]
    public let timestamp: Date

    public init(
        id: String = UUID().uuidString,
        type: AgentOperationType,
        sessionId: String,
        agentId: String,
        parameters: [String: String],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.sessionId = sessionId
        self.agentId = agentId
        self.parameters = parameters
        self.timestamp = timestamp
    }
}

public enum AgentOperationType: String, Sendable, Codable {
    // Architect operations
    case analyzeRequirements
    case generateSpecification
    case validateArchitecture
    case searchExistingAbstractions

    // Builder operations
    case implementSpecification
    case runTests
    case generatePatch
    case validateBuild

    // Scribe operations
    case updateDocumentation
    case recordDecision
    case crossReference
    case updateTechDebt

    // Validator operations
    case runLinter
    case runTypeCheck
    case validateContracts

    // TechDebtScout operations
    case analyzeCodebase
    case identifyDuplication
    case suggestConsolidation
    case trackDebt
}

// MARK: - Agent Operation Result

public struct AgentOperationResult: Sendable, Codable {
    public let operationId: String
    public let evidenceId: String
    public let status: OperationStatus
    public let outputs: [String: String]
    public let timestamp: Date

    public init(
        operationId: String,
        evidenceId: String,
        status: OperationStatus,
        outputs: [String: String],
        timestamp: Date = Date()
    ) {
        self.operationId = operationId
        self.evidenceId = evidenceId
        self.status = status
        self.outputs = outputs
        self.timestamp = timestamp
    }
}

public enum OperationStatus: String, Sendable, Codable {
    case success
    case failure
    case blocked
    case pending
}

// MARK: - Architect Agent

public actor ArchitectAgent: CathedralAgent {
    public let agentId: String
    public let agentType: AgentType = .architect
    public let cathedral: CathedralFacade

    public init(agentId: String, cathedral: CathedralFacade) {
        self.agentId = agentId
        self.cathedral = cathedral
    }

    public func executeOperation(
        _ operation: AgentOperation,
        sessionId: String
    ) async throws -> AgentOperationResult {

        print("🏛️ Architect[\(agentId)]: Executing \(operation.type.rawValue)")

        // Create ML operation for analysis
        let mlOperation = MLOperation(
            type: .retrieval, // Architects search and analyze
            sessionId: sessionId,
            agentId: agentId,
            parameters: operation.parameters
        )

        // Execute through Cathedral
        let result = try await cathedral.executeOperation(
            operation: mlOperation,
            requirement: .high // Architects require high evidence
        )

        // Record agent-specific metadata
        try await recordArchitectMetadata(
            operationType: operation.type,
            evidenceId: result.id,
            sessionId: sessionId
        )

        return AgentOperationResult(
            operationId: operation.id,
            evidenceId: result.id,
            status: .success,
            outputs: result.data
        )
    }

    private func recordArchitectMetadata(
        operationType: AgentOperationType,
        evidenceId: String,
        sessionId: String
    ) async throws {
        // Record architect-specific evidence
        print("📝 Architect: Recording \(operationType.rawValue) metadata")
    }
}

// MARK: - Builder Agent

public actor BuilderAgent: CathedralAgent {
    public let agentId: String
    public let agentType: AgentType = .builder
    public let cathedral: CathedralFacade

    public init(agentId: String, cathedral: CathedralFacade) {
        self.agentId = agentId
        self.cathedral = cathedral
    }

    public func executeOperation(
        _ operation: AgentOperation,
        sessionId: String
    ) async throws -> AgentOperationResult {

        print("🏛️ Builder[\(agentId)]: Executing \(operation.type.rawValue)")

        // Create ML operation for implementation
        let mlOperation = MLOperation(
            type: .transformation, // Builders transform specs into code
            sessionId: sessionId,
            agentId: agentId,
            parameters: operation.parameters
        )

        // Execute through Cathedral with strict evidence
        let result = try await cathedral.executeOperation(
            operation: mlOperation,
            requirement: .strict // Builders require strict evidence
        )

        // Record build artifacts
        try await recordBuildArtifacts(
            operationType: operation.type,
            evidenceId: result.id,
            sessionId: sessionId
        )

        return AgentOperationResult(
            operationId: operation.id,
            evidenceId: result.id,
            status: .success,
            outputs: result.data
        )
    }

    private func recordBuildArtifacts(
        operationType: AgentOperationType,
        evidenceId: String,
        sessionId: String
    ) async throws {
        // Record build artifacts as evidence
        print("📦 Builder: Recording build artifacts for \(operationType.rawValue)")
    }
}

// MARK: - Scribe Agent

public actor ScribeAgent: CathedralAgent {
    public let agentId: String
    public let agentType: AgentType = .scribe
    public let cathedral: CathedralFacade

    public init(agentId: String, cathedral: CathedralFacade) {
        self.agentId = agentId
        self.cathedral = cathedral
    }

    public func executeOperation(
        _ operation: AgentOperation,
        sessionId: String
    ) async throws -> AgentOperationResult {

        print("🏛️ Scribe[\(agentId)]: Executing \(operation.type.rawValue)")

        // Create ML operation for documentation
        let mlOperation = MLOperation(
            type: .transformation,
            sessionId: sessionId,
            agentId: agentId,
            parameters: operation.parameters
        )

        // Execute through Cathedral
        let result = try await cathedral.executeOperation(
            operation: mlOperation,
            requirement: .moderate // Scribes require moderate evidence
        )

        // Record documentation changes
        try await recordDocumentationChanges(
            operationType: operation.type,
            evidenceId: result.id,
            sessionId: sessionId
        )

        return AgentOperationResult(
            operationId: operation.id,
            evidenceId: result.id,
            status: .success,
            outputs: result.data
        )
    }

    private func recordDocumentationChanges(
        operationType: AgentOperationType,
        evidenceId: String,
        sessionId: String
    ) async throws {
        print("📚 Scribe: Recording documentation changes")
    }
}

// MARK: - Validator Agent

public actor ValidatorAgent: CathedralAgent {
    public let agentId: String
    public let agentType: AgentType = .validator
    public let cathedral: CathedralFacade

    public init(agentId: String, cathedral: CathedralFacade) {
        self.agentId = agentId
        self.cathedral = cathedral
    }

    public func executeOperation(
        _ operation: AgentOperation,
        sessionId: String
    ) async throws -> AgentOperationResult {

        print("🏛️ Validator[\(agentId)]: Executing \(operation.type.rawValue)")

        // Create ML operation for validation
        let mlOperation = MLOperation(
            type: .classification, // Validators classify results
            sessionId: sessionId,
            agentId: agentId,
            parameters: operation.parameters
        )

        // Execute through Cathedral
        let result = try await cathedral.executeOperation(
            operation: mlOperation,
            requirement: .strict // Validators require strict evidence
        )

        // Record validation results
        try await recordValidationResults(
            operationType: operation.type,
            evidenceId: result.id,
            sessionId: sessionId
        )

        return AgentOperationResult(
            operationId: operation.id,
            evidenceId: result.id,
            status: .success,
            outputs: result.data
        )
    }

    private func recordValidationResults(
        operationType: AgentOperationType,
        evidenceId: String,
        sessionId: String
    ) async throws {
        print("✅ Validator: Recording validation results")
    }
}

// MARK: - TechDebtScout Agent

public actor TechDebtScoutAgent: CathedralAgent {
    public let agentId: String
    public let agentType: AgentType = .techDebtScout
    public let cathedral: CathedralFacade

    public init(agentId: String, cathedral: CathedralFacade) {
        self.agentId = agentId
        self.cathedral = cathedral
    }

    public func executeOperation(
        _ operation: AgentOperation,
        sessionId: String
    ) async throws -> AgentOperationResult {

        print("🏛️ TechDebtScout[\(agentId)]: Executing \(operation.type.rawValue)")

        // Create ML operation for analysis
        let mlOperation = MLOperation(
            type: .retrieval, // Scouts search for patterns
            sessionId: sessionId,
            agentId: agentId,
            parameters: operation.parameters
        )

        // Execute through Cathedral
        let result = try await cathedral.executeOperation(
            operation: mlOperation,
            requirement: .moderate
        )

        // Record tech debt findings
        try await recordTechDebtFindings(
            operationType: operation.type,
            evidenceId: result.id,
            sessionId: sessionId
        )

        return AgentOperationResult(
            operationId: operation.id,
            evidenceId: result.id,
            status: .success,
            outputs: result.data
        )
    }

    private func recordTechDebtFindings(
        operationType: AgentOperationType,
        evidenceId: String,
        sessionId: String
    ) async throws {
        print("🔍 TechDebtScout: Recording findings")
    }
}

// MARK: - Agent Factory

public enum AgentFactory {
    /// Create Cathedral-integrated agent
    public static func createAgent(
        type: AgentType,
        agentId: String,
        cathedral: CathedralFacade
    ) -> any CathedralAgent {
        switch type {
        case .architect:
            return ArchitectAgent(agentId: agentId, cathedral: cathedral)
        case .builder:
            return BuilderAgent(agentId: agentId, cathedral: cathedral)
        case .scribe:
            return ScribeAgent(agentId: agentId, cathedral: cathedral)
        case .validator:
            return ValidatorAgent(agentId: agentId, cathedral: cathedral)
        case .techDebtScout:
            return TechDebtScoutAgent(agentId: agentId, cathedral: cathedral)
        }
    }
}

// MARK: - Agent Coordinator

public actor AgentCoordinator {
    private let cathedral: CathedralFacade
    private var agents: [String: any CathedralAgent] = [:]

    public init(cathedral: CathedralFacade) {
        self.cathedral = cathedral
    }

    /// Register agent
    public func registerAgent(type: AgentType, agentId: String) {
        let agent = AgentFactory.createAgent(
            type: type,
            agentId: agentId,
            cathedral: cathedral
        )
        agents[agentId] = agent
    }

    /// Execute agent operation with evidence
    public func executeAgentOperation(
        agentId: String,
        operation: AgentOperation,
        sessionId: String
    ) async throws -> AgentOperationResult {

        guard let agent = agents[agentId] else {
            throw CathedralError.agentNotFound(agentId)
        }

        return try await agent.executeOperation(operation, sessionId: sessionId)
    }

    /// Get session evidence for agent
    public func getAgentEvidence(
        agentId: String,
        sessionId: String
    ) async -> [Evidence] {
        return await cathedral.getSessionEvidence(sessionId: sessionId)
            .filter { $0.agentId == agentId }
    }

    /// Get compliance report for agent session
    public func getAgentComplianceReport(
        agentId: String,
        sessionId: String
    ) async throws -> ComplianceReport {
        return try await cathedral.getComplianceReport(sessionId: sessionId)
    }
}

// MARK: - Extended Cathedral Errors

extension CathedralError {
    public static func agentNotFound(_ agentId: String) -> CathedralError {
        return .configurationError("Agent not found: \(agentId)")
    }
}
