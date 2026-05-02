//
//  GovernedMLRunner.swift
//  MLWorkerCommon
//
//  Governed ML execution runner that integrates with GovernanceController.
//  Ensures ML operations comply with governance policies (mode, kill switch, access control).
//  Fulfills td-8cbe46: Wire governed ML runs
//

import Foundation
import AnigmaCore
import AnigmaGovernance
import ContractsCore
import MLWorkerCommon
import AnigmaPrimitives

/// Governed ML Runner - Executes ML tasks with full governance enforcement
public actor GovernedMLRunner: Sendable {
    private let mlWorker: MLWorker
    private let governance: GovernanceController
    private let auditLog: any AuditLogging
    
    /// Initialize governed ML runner
    /// - Parameters:
    ///   - mlWorker: ML worker instance
    ///   - governance: Governance controller for policy enforcement
    ///   - auditLog: Audit logging for governance events
    public init(mlWorker: MLWorker, governance: GovernanceController, auditLog: any AuditLogging) {
        self.mlWorker = mlWorker
        self.governance = governance
        self.auditLog = auditLog
    }
    
    /// Execute ML task with governance checks
    /// - Parameters:
    ///   - task: ML task to execute
    ///   - options: Task configuration options
    ///   - principal: Principal requesting execution
    ///   - projectId: Optional project context
    /// - Returns: ML response if allowed, or governance denial
    public func executeGovernedTask(
        _ task: MLWorkerTask,
        options: MLTaskOptions,
        principal: Principal,
        projectId: String? = nil
    ) async -> Result<MLWorkerResponse, GovernanceDenialAnalysis> {
        
        // Create write proposal for governance check
        let proposal = createMLProposal(for: task, options: options, principal: principal, projectId: projectId)
        
        // Check if operation is allowed
        let decision = await governance.canWrite(proposal)
        
        if decision.allowed {
            // Log governance approval
            try? await logGovernanceApproval(proposal, decision: decision)
            
            // Execute the ML task
            do {
                let response = try await executeMLTask(task, options: options)
                return .success(response)
            } catch {
                // Log ML execution failure
                try? await logMLExecutionFailure(task, options: options, error: error)
                return .failure(await analyzeMLFailure(proposal, error: error))
            }
        } else {
            let analysis = await analyzeDenial(proposal, decision: decision)
            // Log governance denial
            try? await logGovernanceDenial(proposal, analysis: analysis)
            return .failure(analysis)
        }
    }
    
    /// Execute ML task (internal implementation)
    private func executeMLTask(_ task: MLWorkerTask, options: MLTaskOptions) async throws -> MLWorkerResponse {
        // Create ML worker request from task and options
        let request = MLWorkerRequest(
            requestId: UUID().uuidString,
            runId: UUID().uuidString,
            stepId: UUID().uuidString,
            engine: mlWorker.engine,
            task: task,
            inputs: [],  // For now, use empty inputs - would be populated from task context
            options: options
        )
        
        // Execute the task using the ML worker
        return try await mlWorker.performTaskAsync(request)
    }
    
    /// Create governance proposal for ML operation
    private func createMLProposal(
        for task: MLWorkerTask,
        options: MLTaskOptions,
        principal: Principal,
        projectId: String?
    ) -> WriteProposal {
        
        var context: [String: String] = [
            "mlTask": task.rawValue,
            "mlEngine": mlWorker.engine.rawValue,
            "sensitivity": "high"  // ML operations are high sensitivity
        ]
        
        if let projectId = projectId {
            context["projectId"] = projectId
        }
        
        return WriteProposal(
            principal: principal.id,
            module: "GovernedMLRunner",
            operation: task.rawValue,
            componentType: "ml_execution",
            context: context
        )
    }

    private func analyzeDenial(_ proposal: WriteProposal, decision: WriteGateDecision) async -> GovernanceDenialAnalysis {
        let unblocker = GovernanceUnblocker(governance: governance, auditLog: auditLog)
        return await unblocker.analyzeDenial(proposal, decision: decision)
    }
    
    /// Analyze ML execution failure for governance context
    private func analyzeMLFailure(_ proposal: WriteProposal, error: Error) async -> GovernanceDenialAnalysis {
        let failureDecision = WriteGateDecision(
            allowed: false,
            checkResults: [
                WriteCheckResult(
                    checkId: "ml_execution",
                    passed: false,
                    message: "ML execution failed: \(error.localizedDescription)",
                    details: ["error": String(describing: error)]
                )
            ],
            evaluatedAt: Date()
        )
        
        return await analyzeDenial(proposal, decision: failureDecision)
    }
    
    // MARK: - Audit Logging
    
    private func logGovernanceApproval(_ proposal: WriteProposal, decision: WriteGateDecision) async throws {
        try await auditLog.recordEvent(
            id: UUID(),
            type: .policyEvaluated,
            principal: proposal.principal,
            module: "GovernedMLRunner",
            description: "ML execution approved by governance",
            metadata: [
                "mlTask": proposal.context["mlTask"] ?? "unknown",
                "mlEngine": proposal.context["mlEngine"] ?? "unknown",
                "projectId": proposal.context["projectId"] ?? "none",
                "governanceChecks": "passed"
            ]
        )
    }
    
    private func logGovernanceDenial(_ proposal: WriteProposal, analysis: GovernanceDenialAnalysis) async throws {
        try await auditLog.recordEvent(
            id: UUID(),
            type: .policyViolation,
            principal: proposal.principal,
            module: "GovernedMLRunner",
            description: "ML execution denied by governance",
            metadata: [
                "mlTask": proposal.context["mlTask"] ?? "unknown",
                "mlEngine": proposal.context["mlEngine"] ?? "unknown",
                "projectId": proposal.context["projectId"] ?? "none",
                "denialReasons": analysis.failedChecks.map { $0.message }.joined(separator: "; "),
                "resolutionOptions": analysis.resolutionOptions.map { $0.title }.joined(separator: "; ")
            ]
        )
    }
    
    private func logMLExecutionFailure(_ task: MLWorkerTask, options: MLTaskOptions, error: Error) async throws {
        try await auditLog.recordEvent(
            id: UUID(),
            type: .custom,
            principal: "system",
            module: "GovernedMLRunner",
            description: "ML execution failed",
            metadata: [
                "mlTask": task.rawValue,
                "error": String(describing: error),
                "seed": String(options.seed),
                "maxTokens": String(options.maxTokens ?? 0)
            ]
        )
    }
}

// MARK: - ML Memo Integration

/// ML Memo represents a captured ML execution result with governance metadata
public struct MLMemo: Sendable, Codable {
    public let memoId: String
    public let task: MLWorkerTask
    public let options: MLTaskOptions
    public let response: MLWorkerResponse
    public let governanceDecision: WriteGateDecision
    public let createdAt: Date
    public let principal: Principal
    public let projectId: String?
    
    public init(
        memoId: String = UUID().uuidString,
        task: MLWorkerTask,
        options: MLTaskOptions,
        response: MLWorkerResponse,
        governanceDecision: WriteGateDecision,
        createdAt: Date = Date(),
        principal: Principal,
        projectId: String? = nil
    ) {
        self.memoId = memoId
        self.task = task
        self.options = options
        self.response = response
        self.governanceDecision = governanceDecision
        self.createdAt = createdAt
        self.principal = principal
        self.projectId = projectId
    }
}

// MARK: - Project Workbench Integration

/// ML Project Workbench - Unifies ML operations within project context
public actor MLProjectWorkbench: Sendable {
    private let governedRunner: GovernedMLRunner
    private var memoStore: [String: MLMemo] = [:]
    private let projectId: String
    
    public init(governedRunner: GovernedMLRunner, projectId: String) {
        self.governedRunner = governedRunner
        self.projectId = projectId
    }
    
    /// Execute ML task within project context
    public func executeTask(
        _ task: MLWorkerTask,
        options: MLTaskOptions,
        principal: Principal
    ) async -> Result<MLMemo, GovernanceDenialAnalysis> {
        
        let result = await governedRunner.executeGovernedTask(
            task,
            options: options,
            principal: principal,
            projectId: projectId
        )
        
        switch result {
        case .success(let response):
            let memo = MLMemo(
                task: task,
                options: options,
                response: response,
                governanceDecision: WriteGateDecision(allowed: true, checkResults: [], evaluatedAt: Date()),
                principal: principal,
                projectId: projectId
            )
            
            // Store memo for project context
            memoStore[memo.memoId] = memo
            
            return .success(memo)
        case .failure(let analysis):
            return .failure(analysis)
        }
    }
    
    /// Retrieve memo by ID
    public func getMemo(_ memoId: String) -> MLMemo? {
        return memoStore[memoId]
    }
    
    /// Get all memos for this project
    public func getAllMemos() -> [MLMemo] {
        return Array(memoStore.values).sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Clear memos (e.g., for memory management)
    public func clearMemos(olderThan: Date? = nil) -> Int {
        if let cutoff = olderThan {
            let oldMemos = memoStore.filter { $0.value.createdAt < cutoff }
            for (id, _) in oldMemos {
                memoStore.removeValue(forKey: id)
            }
            return oldMemos.count
        } else {
            let count = memoStore.count
            memoStore.removeAll()
            return count
        }
    }
}

// MARK: - Integration Extensions

public extension GovernedMLRunner {
    /// Create a project workbench for unified ML operations
    func createProjectWorkbench(for projectId: String) -> MLProjectWorkbench {
        return MLProjectWorkbench(governedRunner: self, projectId: projectId)
    }
}
