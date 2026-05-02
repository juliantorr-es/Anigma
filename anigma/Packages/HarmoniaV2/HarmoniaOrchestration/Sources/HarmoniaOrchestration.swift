// HarmoniaOrchestration - Execution Control
// Orchestration capabilities: Phase9 loop, agents, tools, workflow execution

import Foundation
import HarmoniaV2Core
import HarmoniaV2Inference
import HarmoniaV2Memory
import AnigmaFoundation

// MARK: - Public API

/// Canonical orchestration spine for runs, lanes, lifecycle, policy checkpoints, receipts, and telemetry hooks.
public actor HarmoniaConductor {
    private let registry: ModuleRegistry
    private let inference: InferenceEngine
    private let memory: MemoryManager
    private let documentAnalysisLane: any DocumentAnalysisLane
    private let policyEvaluationLane: any PolicyEvaluationLane
    private var activeRuns: [String: HarmoniaConductorRunLifecycle] = [:]

    public init(
        registry: ModuleRegistry = ModuleRegistry(),
        inference: InferenceEngine = InferenceEngine(),
        memory: MemoryManager = MemoryManager(),
        documentAnalysisLane: any DocumentAnalysisLane = NotConfiguredDocumentAnalysisLane(),
        policyEvaluationLane: any PolicyEvaluationLane = NotConfiguredPolicyEvaluationLane()
    ) {
        self.registry = registry
        self.inference = inference
        self.memory = memory
        self.documentAnalysisLane = documentAnalysisLane
        self.policyEvaluationLane = policyEvaluationLane
    }

    /// Execute the canonical document-analysis route.
    public func executeDocumentAnalysis(
        objective: String,
        userId: String? = nil,
        policyContext: String? = nil
    ) async throws -> HarmoniaConductorLaneResult {
        let trimmedObjective = objective.trimmingCharacters(in: .whitespacesAndNewlines)
        let runIdentity = HarmoniaConductorRunIdentity(
            runID: UUID().uuidString,
            sessionID: UUID().uuidString,
            createdAt: Date()
        )
        let executionContext = HarmoniaConductorExecutionContext(
            runIdentity: runIdentity,
            objective: trimmedObjective,
            userId: userId,
            policyContext: policyContext ?? Self.defaultPolicyContext,
            laneName: Self.documentAnalysisLaneName
        )

        activeRuns[runIdentity.runID] = HarmoniaConductorRunLifecycle(
            identity: runIdentity,
            state: .running,
            updatedAt: Date()
        )
        defer {
            activeRuns.removeValue(forKey: runIdentity.runID)
        }

        let result = try await documentAnalysisLane.execute(
            request: HarmoniaDocumentAnalysisRequest(
                objective: trimmedObjective,
                userId: userId,
                policyContext: executionContext.policyContext
            ),
            context: executionContext
        )

        return result
    }

    /// Execute the canonical policy-evaluation route.
    public func executePolicyEvaluation(
        principal: String,
        resource: String,
        action: String,
        policyContext: String? = nil,
        attributes: [String: String] = [:]
    ) async throws -> HarmoniaConductorLaneResult {
        let trimmedPrincipal = principal.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedResource = resource.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAction = action.trimmingCharacters(in: .whitespacesAndNewlines)
        let runIdentity = HarmoniaConductorRunIdentity(
            runID: UUID().uuidString,
            sessionID: UUID().uuidString,
            createdAt: Date()
        )
        let executionContext = HarmoniaConductorExecutionContext(
            runIdentity: runIdentity,
            objective: "\(trimmedAction) \(trimmedResource)",
            userId: trimmedPrincipal.isEmpty ? nil : trimmedPrincipal,
            policyContext: policyContext ?? Self.policyEvaluationDefaultPolicyContext,
            laneName: Self.policyEvaluationLaneName
        )

        activeRuns[runIdentity.runID] = HarmoniaConductorRunLifecycle(
            identity: runIdentity,
            state: .running,
            updatedAt: Date()
        )
        defer {
            activeRuns.removeValue(forKey: runIdentity.runID)
        }

        return try await policyEvaluationLane.execute(
            request: HarmoniaPolicyEvaluationRequest(
                principal: trimmedPrincipal,
                resource: trimmedResource,
                action: trimmedAction,
                policyContext: executionContext.policyContext,
                attributes: attributes
            ),
            context: executionContext
        )
    }

    /// Historical Phase9 compatibility route.
    public func executePhase9(context: HarmoniaV2Core.ExecutionContext) async throws -> Phase9Result {
        let result = try await executeDocumentAnalysis(
            objective: "historical phase9 route",
            userId: context.userId,
            policyContext: context.sessionId
        )
        return Phase9Result(
            outcome: result.summary,
            observations: result.policyCheckpoints.map { $0.summary },
            nextActions: result.nextActions
        )
    }

    /// Route and execute tool.
    public func executeTool(
        name: String,
        arguments: [String: Any],
        context: HarmoniaV2Core.ExecutionContext,
        policyContext: String? = nil
    ) async throws -> ToolResult {
        let effectivePolicyContext = policyContext ?? context.userId ?? Self.defaultPolicyContext

        print("⚠️  STUB INVOKED: HarmoniaConductor.executeTool(name: \(name))")
        print("   Tool dispatch lane is not configured. Policy Context: \(effectivePolicyContext)")

        return ToolResult(
            toolName: name,
            output: "Tool dispatch is routed through HarmoniaConductor but the tool lane is not configured yet.",
            success: false,
            error: "reason=notConfigured; tool=\(name); policyContext=\(effectivePolicyContext); arguments=\(arguments.count)"
        )
    }

    public func getRunStatus(runId: String) -> HarmoniaConductorRunLifecycle? {
        activeRuns[runId]
    }

    public func listLanes() -> [String] {
        [Self.documentAnalysisLaneName, Self.policyEvaluationLaneName]
    }

    public func checkpointPolicy(_ checkpoint: HarmoniaConductorPolicyCheckpoint) async {
        guard let lifecycle = activeRuns[checkpoint.runIdentity.runID] else { return }
        activeRuns[checkpoint.runIdentity.runID] = lifecycle.record(checkpoint: checkpoint)
    }

    public func recordReceipt(_ receipt: HarmoniaConductorReceiptHook) async {
        guard let lifecycle = activeRuns[receipt.runIdentity.runID] else { return }
        activeRuns[receipt.runIdentity.runID] = lifecycle.record(receipt: receipt)
    }

    public func emitTelemetry(_ telemetry: HarmoniaConductorTelemetryHook) async {
        guard let lifecycle = activeRuns[telemetry.runIdentity.runID] else { return }
        activeRuns[telemetry.runIdentity.runID] = lifecycle.record(telemetry: telemetry)
    }

    private static let defaultPolicyContext = "harmonia.conductor.document-analysis"
    private static let policyEvaluationDefaultPolicyContext = "harmonia.conductor.policy-evaluation"
    private static let documentAnalysisLaneName = "DocumentAnalysisLane"
    private static let policyEvaluationLaneName = "ParallelPolicyEvaluationLane"
}

// MARK: - Types

public protocol DocumentAnalysisLane: Sendable {
    func execute(
        request: HarmoniaDocumentAnalysisRequest,
        context: HarmoniaConductorExecutionContext
    ) async throws -> HarmoniaConductorLaneResult
}

public protocol PolicyEvaluationLane: Sendable {
    func execute(
        request: HarmoniaPolicyEvaluationRequest,
        context: HarmoniaConductorExecutionContext
    ) async throws -> HarmoniaConductorLaneResult
}

public struct HarmoniaDocumentAnalysisRequest: Sendable {
    public let objective: String
    public let userId: String?
    public let policyContext: String

    public init(objective: String, userId: String?, policyContext: String) {
        self.objective = objective
        self.userId = userId
        self.policyContext = policyContext
    }
}

public struct HarmoniaPolicyEvaluationRequest: Sendable {
    public let principal: String
    public let resource: String
    public let action: String
    public let policyContext: String
    public let attributes: [String: String]

    public init(
        principal: String,
        resource: String,
        action: String,
        policyContext: String,
        attributes: [String: String]
    ) {
        self.principal = principal
        self.resource = resource
        self.action = action
        self.policyContext = policyContext
        self.attributes = attributes
    }
}

public struct HarmoniaConductorRunIdentity: Sendable, Codable, Hashable {
    public let runID: String
    public let sessionID: String
    public let createdAt: Date

    public init(runID: String, sessionID: String, createdAt: Date) {
        self.runID = runID
        self.sessionID = sessionID
        self.createdAt = createdAt
    }
}

public struct HarmoniaConductorExecutionContext: Sendable, Codable {
    public let runIdentity: HarmoniaConductorRunIdentity
    public let objective: String
    public let userId: String?
    public let policyContext: String
    public let laneName: String

    public init(
        runIdentity: HarmoniaConductorRunIdentity,
        objective: String,
        userId: String?,
        policyContext: String,
        laneName: String
    ) {
        self.runIdentity = runIdentity
        self.objective = objective
        self.userId = userId
        self.policyContext = policyContext
        self.laneName = laneName
    }
}

public enum HarmoniaConductorDisposition: String, Sendable, Codable, Equatable {
    case completed
    case deferred
    case failed
}

public enum HarmoniaConductorReasonCode: String, Sendable, Codable, Equatable {
    case success = "SUCCESS"
    case validationFailed = "VALIDATION_FAILED"
    case integrationPending = "INTEGRATION_PENDING"
    case notConfigured = "NOT_CONFIGURED"
    case policyDenied = "POLICY_DENIED"
    case backendFailure = "BACKEND_FAILURE"
    case laneUnavailable = "LANE_UNAVAILABLE"
}

public struct HarmoniaConductorPolicyCheckpoint: Sendable, Codable {
    public let runIdentity: HarmoniaConductorRunIdentity
    public let summary: String
    public let reasonCode: HarmoniaConductorReasonCode
    public let metadata: [String: String]

    public init(
        runIdentity: HarmoniaConductorRunIdentity,
        summary: String,
        reasonCode: HarmoniaConductorReasonCode,
        metadata: [String: String] = [:]
    ) {
        self.runIdentity = runIdentity
        self.summary = summary
        self.reasonCode = reasonCode
        self.metadata = metadata
    }
}

public struct HarmoniaConductorReceiptHook: Sendable, Codable {
    public let runIdentity: HarmoniaConductorRunIdentity
    public let actionName: String
    public let reasonCode: HarmoniaConductorReasonCode
    public let metadata: [String: String]

    public init(
        runIdentity: HarmoniaConductorRunIdentity,
        actionName: String,
        reasonCode: HarmoniaConductorReasonCode,
        metadata: [String: String] = [:]
    ) {
        self.runIdentity = runIdentity
        self.actionName = actionName
        self.reasonCode = reasonCode
        self.metadata = metadata
    }
}

public struct HarmoniaConductorTelemetryHook: Sendable, Codable {
    public let runIdentity: HarmoniaConductorRunIdentity
    public let category: String
    public let message: String
    public let metadata: [String: String]

    public init(
        runIdentity: HarmoniaConductorRunIdentity,
        category: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        self.runIdentity = runIdentity
        self.category = category
        self.message = message
        self.metadata = metadata
    }
}

public struct HarmoniaConductorLaneResult: Sendable, Codable {
    public let runIdentity: HarmoniaConductorRunIdentity
    public let laneName: String
    public let objective: String
    public let disposition: HarmoniaConductorDisposition
    public let summary: String
    public let nextActions: [String]
    public let policyCheckpoints: [HarmoniaConductorPolicyCheckpoint]
    public let receiptHooks: [HarmoniaConductorReceiptHook]
    public let telemetryHooks: [HarmoniaConductorTelemetryHook]
    public let reasonCode: HarmoniaConductorReasonCode
    public let errorDescription: String?
    public let recoverySuggestion: String?

    public init(
        runIdentity: HarmoniaConductorRunIdentity,
        laneName: String,
        objective: String,
        disposition: HarmoniaConductorDisposition,
        summary: String,
        nextActions: [String],
        policyCheckpoints: [HarmoniaConductorPolicyCheckpoint],
        receiptHooks: [HarmoniaConductorReceiptHook],
        telemetryHooks: [HarmoniaConductorTelemetryHook],
        reasonCode: HarmoniaConductorReasonCode,
        errorDescription: String?,
        recoverySuggestion: String?
    ) {
        self.runIdentity = runIdentity
        self.laneName = laneName
        self.objective = objective
        self.disposition = disposition
        self.summary = summary
        self.nextActions = nextActions
        self.policyCheckpoints = policyCheckpoints
        self.receiptHooks = receiptHooks
        self.telemetryHooks = telemetryHooks
        self.reasonCode = reasonCode
        self.errorDescription = errorDescription
        self.recoverySuggestion = recoverySuggestion
    }
}

public struct HarmoniaConductorRunLifecycle: Sendable, Codable {
    public enum State: Sendable, Codable, Equatable {
        case idle
        case running
        case completed(HarmoniaConductorDisposition)
        case blocked(HarmoniaConductorReasonCode)
    }

    public let identity: HarmoniaConductorRunIdentity
    public var state: State
    public var updatedAt: Date
    public var policyCheckpoints: [HarmoniaConductorPolicyCheckpoint]
    public var receiptHooks: [HarmoniaConductorReceiptHook]
    public var telemetryHooks: [HarmoniaConductorTelemetryHook]

    public init(
        identity: HarmoniaConductorRunIdentity,
        state: State,
        updatedAt: Date,
        policyCheckpoints: [HarmoniaConductorPolicyCheckpoint] = [],
        receiptHooks: [HarmoniaConductorReceiptHook] = [],
        telemetryHooks: [HarmoniaConductorTelemetryHook] = []
    ) {
        self.identity = identity
        self.state = state
        self.updatedAt = updatedAt
        self.policyCheckpoints = policyCheckpoints
        self.receiptHooks = receiptHooks
        self.telemetryHooks = telemetryHooks
    }

    func record(checkpoint: HarmoniaConductorPolicyCheckpoint) -> HarmoniaConductorRunLifecycle {
        var copy = self
        copy.policyCheckpoints.append(checkpoint)
        copy.updatedAt = Date()
        return copy
    }

    func record(receipt: HarmoniaConductorReceiptHook) -> HarmoniaConductorRunLifecycle {
        var copy = self
        copy.receiptHooks.append(receipt)
        copy.updatedAt = Date()
        return copy
    }

    func record(telemetry: HarmoniaConductorTelemetryHook) -> HarmoniaConductorRunLifecycle {
        var copy = self
        copy.telemetryHooks.append(telemetry)
        copy.updatedAt = Date()
        return copy
    }
}

public actor NotConfiguredDocumentAnalysisLane: DocumentAnalysisLane {
    public init() {}

    public func execute(
        request: HarmoniaDocumentAnalysisRequest,
        context: HarmoniaConductorExecutionContext
    ) async throws -> HarmoniaConductorLaneResult {
        let checkpoint = HarmoniaConductorPolicyCheckpoint(
            runIdentity: context.runIdentity,
            summary: "Document analysis lane is not configured yet.",
            reasonCode: request.objective.isEmpty ? .validationFailed : .laneUnavailable,
            metadata: [
                "lane": context.laneName,
                "policy_context": context.policyContext
            ]
        )

        let receiptHook = HarmoniaConductorReceiptHook(
            runIdentity: context.runIdentity,
            actionName: "harmonia.conductor.document-analysis",
            reasonCode: request.objective.isEmpty ? .validationFailed : .laneUnavailable,
            metadata: [
                "lane": context.laneName,
                "policy_context": context.policyContext
            ]
        )

        let telemetryHook = HarmoniaConductorTelemetryHook(
            runIdentity: context.runIdentity,
            category: "harmonia.conductor",
            message: "Document analysis lane deferred behind canonical conductor boundary.",
            metadata: [
                "lane": context.laneName,
                "policy_context": context.policyContext
            ]
        )

        if request.objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return HarmoniaConductorLaneResult(
                runIdentity: context.runIdentity,
                laneName: context.laneName,
                objective: request.objective,
                disposition: .failed,
                summary: "Document analysis objective is required.",
                nextActions: [
                    "Provide a non-empty objective to the conductor route."
                ],
                policyCheckpoints: [checkpoint],
                receiptHooks: [receiptHook],
                telemetryHooks: [telemetryHook],
                reasonCode: .validationFailed,
                errorDescription: "Objective cannot be empty.",
                recoverySuggestion: "Re-run the command with a concrete objective."
            )
        }

        return HarmoniaConductorLaneResult(
            runIdentity: context.runIdentity,
            laneName: context.laneName,
            objective: request.objective,
            disposition: .deferred,
            summary: "Document analysis is accepted by HarmoniaConductor and deferred until the lane is configured.",
            nextActions: [
                "Implement the DocumentAnalysisLane behind HarmoniaConductor.",
                "Wire governed tool dispatch and evidence sinks behind the lane."
            ],
            policyCheckpoints: [checkpoint],
            receiptHooks: [receiptHook],
            telemetryHooks: [telemetryHook],
            reasonCode: .integrationPending,
            errorDescription: nil,
            recoverySuggestion: nil
        )
    }
}

public actor NotConfiguredPolicyEvaluationLane: PolicyEvaluationLane {
    public init() {}

    public func execute(
        request: HarmoniaPolicyEvaluationRequest,
        context: HarmoniaConductorExecutionContext
    ) async throws -> HarmoniaConductorLaneResult {
        let checkpoint = HarmoniaConductorPolicyCheckpoint(
            runIdentity: context.runIdentity,
            summary: "Policy evaluation lane is not configured yet.",
            reasonCode: request.principal.isEmpty || request.resource.isEmpty || request.action.isEmpty
                ? .validationFailed
                : .laneUnavailable,
            metadata: [
                "lane": context.laneName,
                "policy_context": context.policyContext,
                "principal": request.principal,
                "resource": request.resource,
                "action": request.action,
                "attribute_count": "\(request.attributes.count)"
            ]
        )

        let receiptHook = HarmoniaConductorReceiptHook(
            runIdentity: context.runIdentity,
            actionName: "harmonia.conductor.policy-evaluation",
            reasonCode: request.principal.isEmpty || request.resource.isEmpty || request.action.isEmpty
                ? .validationFailed
                : .laneUnavailable,
            metadata: [
                "lane": context.laneName,
                "policy_context": context.policyContext,
                "principal": request.principal,
                "resource": request.resource,
                "action": request.action
            ]
        )

        let telemetryHook = HarmoniaConductorTelemetryHook(
            runIdentity: context.runIdentity,
            category: "harmonia.conductor",
            message: "Policy evaluation lane deferred behind canonical conductor boundary.",
            metadata: [
                "lane": context.laneName,
                "policy_context": context.policyContext,
                "principal": request.principal,
                "resource": request.resource,
                "action": request.action
            ]
        )

        if request.principal.isEmpty || request.resource.isEmpty || request.action.isEmpty {
            return HarmoniaConductorLaneResult(
                runIdentity: context.runIdentity,
                laneName: context.laneName,
                objective: context.objective,
                disposition: .failed,
                summary: "Policy evaluation requires principal, resource, and action.",
                nextActions: [
                    "Provide principal, resource, and action.",
                    "Route through a configured PolicyEvaluationLane."
                ],
                policyCheckpoints: [checkpoint],
                receiptHooks: [receiptHook],
                telemetryHooks: [telemetryHook],
                reasonCode: .validationFailed,
                errorDescription: "Principal, resource, and action cannot be empty.",
                recoverySuggestion: "Re-run with a complete ABAC request."
            )
        }

        return HarmoniaConductorLaneResult(
            runIdentity: context.runIdentity,
            laneName: context.laneName,
            objective: context.objective,
            disposition: .deferred,
            summary: "Policy evaluation is accepted by HarmoniaConductor and deferred until the lane is configured.",
            nextActions: [
                "Implement a hardware-backed PolicyEvaluationLane.",
                "Wire ABAC decisions through the conductor boundary."
            ],
            policyCheckpoints: [checkpoint],
            receiptHooks: [receiptHook],
            telemetryHooks: [telemetryHook],
            reasonCode: .integrationPending,
            errorDescription: nil,
            recoverySuggestion: nil
        )
    }
}

/// Legacy compatibility alias retained while the canonical conductor name is adopted.
public typealias Orchestrator = HarmoniaConductor

public struct Phase9Result: Sendable {
    public let outcome: String
    public let observations: [String]
    public let nextActions: [String]
    
    public init(outcome: String, observations: [String], nextActions: [String]) {
        self.outcome = outcome
        self.observations = observations
        self.nextActions = nextActions
    }
}

public struct ToolResult: Sendable {
    public let toolName: String
    public let output: String
    public let success: Bool
    public let error: String?
    
    public init(toolName: String, output: String, success: Bool, error: String? = nil) {
        self.toolName = toolName
        self.output = output
        self.success = success
        self.error = error
    }
}

public struct AgentConfig: Sendable {
    public let name: String
    public let capabilities: Set<String>
    public let maxIterations: Int
    
    public init(name: String, capabilities: Set<String>, maxIterations: Int = 10) {
        self.name = name
        self.capabilities = capabilities
        self.maxIterations = maxIterations
    }
}
