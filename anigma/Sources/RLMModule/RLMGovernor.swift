import Foundation
import AnigmaCore
import DatabaseCore
import HarmoniaModule
import AnigmaPrimitives

/// Governor for Runtime Loop Manager (RLM) operations.
///
/// Manages the execution of RLM runtime loops with:
/// - Budget enforcement (tool calls, tokens, time, recursion depth)
/// - Policy enforcement (allowed tools, verification requirements)
/// - Evidence recording (every operation produces verifiable receipts)
/// - Scheduling (parallel subtask execution when safe)
///
/// The governor implements the Anigma RLM vision:
/// - "Swift governs, capsules compute" - governance layer over native operations
/// - "Context as environment" - mediated access to structured context store
/// - "Evidence substrate" - all operations produce court-safe evidence
public actor RLMGovernor {
    // MARK: - Properties
    
    private let policy: RLMGovernancePolicy
    private let budgets: RLMResourceBudgets
    private let environment: ContextEnvironment
    private let evidenceAuthority: (any EvidenceAuthority)?
    
    // Runtime state
    private var currentState: RLMState
    private var evidenceChain: [EvidenceRecord] = []
    private var spawnedSubtasks: [String: RLMSubtask] = [:] // taskId -> subtask
    private var artifactStore: [String: RLMArtifact] = [:] // artifactId -> artifact
    
    // Evidence recording
    private let evidenceRecorder: RLMEvidenceRecorder
    
    // Statistics
    private var totalToolCalls: Int = 0
    private var totalTokensUsed: Int = 0
    private var totalBytesRetrieved: Int = 0
    private var startTime: Date
    
    // MARK: - Initialization
    
    /// Create an RLM governor.
    /// - Parameters:
    ///   - policy: Governance policy for the runtime loop
    ///   - budgets: Resource budgets for the runtime loop
    ///   - environment: Context environment for source access
    ///   - evidenceAuthority: Authority for evidence recording
    public init(
        policy: RLMGovernancePolicy,
        budgets: RLMResourceBudgets,
        environment: ContextEnvironment,
        evidenceAuthority: (any EvidenceAuthority)? = nil
    ) {
        self.policy = policy
        self.budgets = budgets
        self.environment = environment
        self.evidenceAuthority = evidenceAuthority
        
        self.currentState = RLMState(
            sessionId: UUID().uuidString,
            currentDepth: 0,
            remainingToolCalls: budgets.maxToolCalls,
            remainingPlannerTokens: budgets.plannerTokenBudget,
            remainingWorkerTokens: budgets.workerTokenBudget,
            startTime: Date()
        )
        self.startTime = Date()
        self.evidenceRecorder = RLMEvidenceRecorder(
            evidenceAuthority: evidenceAuthority,
            sessionId: currentState.sessionId
        )
    }
    
    // MARK: - Main Execution Loop
    
    /// Execute a complete RLM planning loop.
    /// - Parameters:
    ///   - userRequest: User's request or task description
    ///   - plannerModel: Model interface for planning (high-level strategy)
    ///   - workerModel: Model interface for execution (detailed work)
    ///   - initialContext: Optional initial context spans to consider
    /// - Returns: Final artifact produced by the loop
    /// - Throws: RLMError if budgets exceeded or policy violated
    public func executePlanningLoop(
        userRequest: String,
        plannerModel: any RLMPlannerModel,
        workerModel: any RLMWorkerModel,
        initialContext: [SpanRef] = []
    ) async throws -> RLMArtifact {
        // Reset state for new loop
        resetForNewLoop()
        
        // Record loop execution evidence
        let loopPayload = RLMEvidence.loopExecutionPayload(
            userRequest: userRequest,
            policy: policy,
            budgets: budgets,
            initialContextSpans: initialContext.count
        )
        _ = try await evidenceRecorder.record(
            operationType: .loopExecution,
            payload: loopPayload
        )
        
        // Record initial evidence
        let initialEvidence = try await recordEvidence(
            operation: .spawnSubtask,
            inputs: ["user_request": AnyCodable(userRequest)],
            result: ToolResult(
                success: true,
                output: ["status": AnyCodable("loop_started")],
                errorMessage: nil,
                evidenceHash: "",
                duration: 0,
                resourcesConsumed: ToolResources()
            ),
            spanRefs: initialContext
        )
        
        // Phase 1: Exploration - Planner explores environment
        let explorationResult = try await executeExplorationPhase(
            userRequest: userRequest,
            plannerModel: plannerModel,
            initialContext: initialContext,
            parentEvidence: initialEvidence
        )
        
        // Phase 2: Decomposition - Planner proposes subtasks
        let decompositionResult = try await executeDecompositionPhase(
            explorationResult: explorationResult,
            plannerModel: plannerModel,
            parentEvidence: explorationResult.evidence
        )
        
        // Phase 3: Execution - Harmonia schedules and executes subtasks
        let executionResults = try await executeSubtasksPhase(
            subtasks: decompositionResult.subtasks,
            workerModel: workerModel,
            parentEvidence: decompositionResult.evidence
        )
        
        // Phase 4: Synthesis - Planner synthesizes final artifact
        let finalArtifact = try await executeSynthesisPhase(
            executionResults: executionResults,
            plannerModel: plannerModel,
            parentEvidence: executionResults.evidence
        )
        
        // Phase 5: Verification (optional)
        if policy.requireVerification {
            let verificationResult = try await executeVerificationPhase(
                artifact: finalArtifact,
                plannerModel: plannerModel,
                parentEvidence: finalArtifact.evidenceChain.last ?? initialEvidence
            )
            
            if !verificationResult.success {
                throw RLMError.verificationFailed(
                    "Artifact failed verification: \(verificationResult.errorMessage ?? "Unknown error")"
                )
            }
        }
        
        return finalArtifact
    }
    
    // MARK: - Tool Execution
    
    /// Execute a tool operation with governance enforcement.
    /// - Parameters:
    ///   - operation: Tool operation to execute
    ///   - inputs: Operation inputs
    ///   - caller: Who is calling the tool (planner or worker)
    ///   - parentEvidenceId: Parent evidence ID for chaining
    /// - Returns: Tool result with evidence
    /// - Throws: RLMError if operation not allowed or budgets exceeded
    public func executeTool(
        _ operation: ToolOperation,
        inputs: [String: AnyCodable],
        caller: ToolCaller,
        parentEvidenceId: String? = nil
    ) async throws -> (result: ToolResult, evidence: EvidenceRecord) {
        // Check policy
        guard policy.allowedTools.contains(operation.rawValue) else {
            throw RLMError.operationNotAllowed(
                "Tool '\(operation.rawValue)' not allowed by policy"
            )
        }
        
        // Check budgets
        try checkBudgets(for: operation, caller: caller)
        
        // Check recursion depth
        if operation == .spawnSubtask {
            guard currentState.currentDepth < policy.maxRecursionDepth else {
                throw RLMError.recursionLimitExceeded(
                    "Maximum recursion depth (\(policy.maxRecursionDepth)) exceeded"
                )
            }
        }
        
        // Execute tool
        let startTime = Date()
        let result: ToolResult
        let spanRefs: [SpanRef]
        
        do {
            // Dispatch to appropriate tool implementation
            (result, spanRefs) = try await executeToolImplementation(
                operation,
                inputs: inputs,
                caller: caller
            )
        } catch {
            // Record failure evidence
            let errorEvidence = try await recordEvidence(
                operation: operation,
                inputs: inputs,
                result: ToolResult(
                    success: false,
                    output: [:],
                    errorMessage: error.localizedDescription,
                    evidenceHash: "",
                    duration: Date().timeIntervalSince(startTime),
                    resourcesConsumed: ToolResources(toolCalls: 1)
                ),
                parentEvidenceIds: parentEvidenceId.map { [$0] } ?? [],
                spanRefs: []
            )
            
            // Update state
            updateStateAfterToolCall(
                operation: operation,
                success: false,
                resources: ToolResources(toolCalls: 1)
            )
            
            throw RLMError.toolExecutionFailed(
                "Tool '\(operation.rawValue)' failed: \(error.localizedDescription)",
                underlyingError: error
            )
        }
        
        // Record evidence
        let evidence = try await recordEvidence(
            operation: operation,
            inputs: inputs,
            result: result,
            parentEvidenceIds: parentEvidenceId.map { [$0] } ?? [],
            spanRefs: spanRefs
        )
        
        // Update state
        updateStateAfterToolCall(
            operation: operation,
            success: true,
            resources: result.resourcesConsumed
        )
        
        // Reset environment check timer if this is an environment check
        if policy.environmentCheckTools.contains(operation.rawValue) {
            currentState.lastEnvironmentCheck = Date()
        }
        
        return (result, evidence)
    }
    
    // MARK: - Private Methods
    
    private func resetForNewLoop() {
        currentState = RLMState(
            sessionId: UUID().uuidString,
            currentDepth: 0,
            remainingToolCalls: budgets.maxToolCalls,
            remainingPlannerTokens: budgets.plannerTokenBudget,
            remainingWorkerTokens: budgets.workerTokenBudget,
            startTime: Date()
        )
        evidenceChain.removeAll()
        spawnedSubtasks.removeAll()
        artifactStore.removeAll()
        totalToolCalls = 0
        totalTokensUsed = 0
        totalBytesRetrieved = 0
        startTime = Date()
    }
    
    private func checkBudgets(for operation: ToolOperation, caller: ToolCaller) throws {
        // Check tool call budget
        guard currentState.remainingToolCalls > 0 else {
            throw RLMError.budgetExceeded("Tool call budget exceeded")
        }
        
        // Check execution time budget
        let elapsedTime = Date().timeIntervalSince(startTime)
        guard elapsedTime < budgets.maxExecutionTime else {
            throw RLMError.budgetExceeded("Execution time budget exceeded")
        }
        
        // Check token budget based on caller
        switch caller {
        case .planner:
            guard currentState.remainingPlannerTokens > 0 else {
                throw RLMError.budgetExceeded("Planner token budget exceeded")
            }
        case .worker:
            guard currentState.remainingWorkerTokens > 0 else {
                throw RLMError.budgetExceeded("Worker token budget exceeded")
            }
        }
        
        // Check retrieval budget for retrieval operations
        if [.peek, .search, .slice, .getHeadings].contains(operation) {
            guard totalBytesRetrieved < budgets.maxRetrievalBytes else {
                throw RLMError.budgetExceeded("Retrieval byte budget exceeded")
            }
        }
    }
    
    private func updateStateAfterToolCall(
        operation: ToolOperation,
        success: Bool,
        resources: ToolResources
    ) {
        currentState.remainingToolCalls -= 1
        totalToolCalls += 1
        
        switch operation {
        case .spawnSubtask:
            currentState.currentDepth += 1
        case .getSubtaskResult:
            // When we get a subtask result, we can decrement depth
            if !spawnedSubtasks.isEmpty {
                currentState.currentDepth = max(0, currentState.currentDepth - 1)
            }
        default:
            break
        }
        
        // Update token budgets
        currentState.remainingPlannerTokens -= resources.tokensUsed
        currentState.remainingWorkerTokens -= resources.tokensUsed
        
        // Update retrieval stats
        totalBytesRetrieved += resources.bytesRetrieved
    }
    
    private func executeToolImplementation(
        _ operation: ToolOperation,
        inputs: [String: AnyCodable],
        caller: ToolCaller
    ) async throws -> (ToolResult, [SpanRef]) {
        // This will be implemented with actual tool implementations
        // For now, return a stub implementation
        switch operation {
        case .peek:
            return try await environment.peek(inputs: inputs)
        case .search:
            return try await environment.search(inputs: inputs)
        case .slice:
            return try await environment.slice(inputs: inputs)
        case .getHeadings:
            return try await environment.getHeadings(inputs: inputs)
        case .listEntities:
            return try await environment.listEntities(inputs: inputs)
        case .summarizeSpan:
            return try await environment.summarizeSpan(inputs: inputs)
        case .rankCandidates:
            return try await environment.rankCandidates(inputs: inputs)
        case .diffSpans:
            return try await environment.diffSpans(inputs: inputs)
        case .verifyClaim:
            return try await environment.verifyClaim(inputs: inputs)
        case .checkConsistency:
            return try await environment.checkConsistency(inputs: inputs)
        case .spawnSubtask:
            return try await spawnSubtask(inputs: inputs, caller: caller)
        case .getSubtaskResult:
            return try await getSubtaskResult(inputs: inputs)
        case .synthesizeArtifact:
            return try await synthesizeArtifact(inputs: inputs)
        case .generateProvenance:
            return try await generateProvenance(inputs: inputs)
        case .generateCode:
            return try await environment.generateCode(inputs: inputs)
        }
    }
    
    private func recordEvidence(
        operation: ToolOperation,
        inputs: [String: AnyCodable],
        result: ToolResult,
        parentEvidenceIds: [String] = [],
        spanRefs: [SpanRef] = []
    ) async throws -> EvidenceRecord {
        let evidence = EvidenceRecord(
            operation: operation,
            inputs: inputs,
            result: result,
            parentEvidenceIds: parentEvidenceIds,
            spanRefs: spanRefs
        )
        
        evidenceChain.append(evidence)
        
        // Record evidence through evidence authority
        let payload = RLMEvidence.toolOperationPayload(
            tool: operation,
            inputs: inputs,
            result: result,
            spanRefs: spanRefs
        )
        
        _ = try await evidenceRecorder.record(
            operationType: .toolOperation,
            payload: payload
        )
        
        return evidence
    }
    
    // MARK: - Phase Implementations (stubs for now)
    
    private func executeExplorationPhase(
        userRequest: String,
        plannerModel: any RLMPlannerModel,
        initialContext: [SpanRef],
        parentEvidence: EvidenceRecord
    ) async throws -> ExplorationPhaseResult {
        let startTime = Date()
        
        // 1. Get directory listing from environment
        let directory = try await environment.getDirectoryListing()
        
        // 2. Ask planner for exploration plan
        let plan = try await plannerModel.planExploration(
            request: userRequest,
            directory: directory,
            initialContext: initialContext
        )
        
        // 3. Execute planned tool calls
        var sampledSpans = initialContext
        for op in plan.toolCalls {
            do {
                // For exploration, we usually call peek or search
                // Note: inputs would normally come from the model, here we use defaults based on userRequest
                let inputs: [String: AnyCodable]
                if op == .search {
                    inputs = ["query": AnyCodable(userRequest)]
                } else {
                    inputs = [:]
                }
                
                let (result, evidence) = try await executeTool(
                    op,
                    inputs: inputs,
                    caller: .planner,
                    parentEvidenceId: parentEvidence.evidenceId
                )
                
                if result.success {
                    // Extract spans from results
                    // This is a simplification
                    if let ids = result.output["span_refs"]?.getValue(as: [String].self) {
                        // Normally we'd convert these to SpanRef
                    }
                }
            } catch {
                print("[RLM] Exploration tool call failed: \(error)")
            }
        }
        
        // Record phase evidence
        let duration = Date().timeIntervalSince(startTime)
        let payload = RLMEvidence.phasePayload(
            phase: .explorationPhase,
            duration: duration,
            resourcesConsumed: ToolResources(toolCalls: plan.toolCalls.count),
            spanRefs: sampledSpans
        )
        _ = try await evidenceRecorder.record(operationType: .explorationPhase, payload: payload)
        
        return ExplorationPhaseResult(
            directory: directory,
            sampledSpans: sampledSpans,
            evidence: parentEvidence
        )
    }
    
    private func executeDecompositionPhase(
        explorationResult: ExplorationPhaseResult,
        plannerModel: any RLMPlannerModel,
        parentEvidence: EvidenceRecord
    ) async throws -> DecompositionPhaseResult {
        let startTime = Date()
        
        // 1. Ask planner to decompose exploration results into tasks
        let explorationResults = ExplorationResults(
            sampledData: [:], // Would contain data from exploration phase
            insights: []      // Would contain insights from exploration phase
        )
        
        let subtasks = try await plannerModel.decomposeIntoTasks(
            explorationResults: explorationResults
        )
        
        // 2. Record phase evidence
        let duration = Date().timeIntervalSince(startTime)
        let payload = RLMEvidence.phasePayload(
            phase: .decompositionPhase,
            duration: duration,
            resourcesConsumed: ToolResources(toolCalls: subtasks.count),
            spanRefs: []
        )
        _ = try await evidenceRecorder.record(operationType: .decompositionPhase, payload: payload)
        
        return DecompositionPhaseResult(
            subtasks: subtasks,
            evidence: parentEvidence
        )
    }
    
    private func executeSubtasksPhase(
        subtasks: [RLMSubtask],
        workerModel: any RLMWorkerModel,
        parentEvidence: EvidenceRecord
    ) async throws -> ExecutionPhaseResult {
        let startTime = Date()
        
        // Execute subtasks (potentially in parallel)
        var results: [RLMSubtaskResult] = []
        
        if policy.allowParallelSubtasks && subtasks.count > 1 {
            // Parallel execution using TaskGroup
            results = try await withThrowingTaskGroup(of: RLMSubtaskResult.self) { group in
                for subtask in subtasks {
                    group.addTask {
                        try await self.executeSubtask(subtask, workerModel: workerModel)
                    }
                }
                
                var subresults: [RLMSubtaskResult] = []
                for try await result in group {
                    subresults.append(result)
                }
                return subresults
            }
        } else {
            // Sequential execution
            for subtask in subtasks {
                let result = try await executeSubtask(subtask, workerModel: workerModel)
                results.append(result)
            }
        }
        
        // Record phase evidence
        let duration = Date().timeIntervalSince(startTime)
        let payload = RLMEvidence.phasePayload(
            phase: .executionPhase,
            duration: duration,
            resourcesConsumed: ToolResources(toolCalls: subtasks.count),
            spanRefs: []
        )
        _ = try await evidenceRecorder.record(operationType: .executionPhase, payload: payload)
        
        return ExecutionPhaseResult(
            subtaskResults: results,
            evidence: parentEvidence
        )
    }
    
    private func executeSynthesisPhase(
        executionResults: ExecutionPhaseResult,
        plannerModel: any RLMPlannerModel,
        parentEvidence: EvidenceRecord
    ) async throws -> RLMArtifact {
        let startTime = Date()
        
        // 1. Ask planner to synthesize results
        let synthesisResult = try await plannerModel.synthesizeArtifact(
            subtaskResults: executionResults.subtaskResults
        )
        
        // 2. Record phase evidence
        let duration = Date().timeIntervalSince(startTime)
        let payload = RLMEvidence.phasePayload(
            phase: .synthesisPhase,
            duration: duration,
            resourcesConsumed: ToolResources(toolCalls: 1),
            spanRefs: synthesisResult.artifact.sourceSpans
        )
        _ = try await evidenceRecorder.record(operationType: .synthesisPhase, payload: payload)
        
        return synthesisResult.artifact
    }
    
    private func executeVerificationPhase(
        artifact: RLMArtifact,
        plannerModel: any RLMPlannerModel,
        parentEvidence: EvidenceRecord
    ) async throws -> VerificationPhaseResult {
        // Verify artifact against sources
        // For now, return success
        return VerificationPhaseResult(
            success: true,
            errorMessage: nil,
            evidence: parentEvidence
        )
    }
    
    private func executeSubtask(
        _ subtask: RLMSubtask,
        workerModel: any RLMWorkerModel
    ) async throws -> RLMSubtaskResult {
        // 1. Retrieve span contents for context
        let contentMap = try await environment.slice(spanRefs: subtask.spanRefs)
        let contextSpans = subtask.spanRefs.compactMap { contentMap[$0.referenceId] }
        
        // 2. Execute worker model
        let result = try await workerModel.executeSubtask(
            subtask: subtask,
            contextSpans: contextSpans
        )
        
        return result
    }
    
    private func spawnSubtask(
        inputs: [String: AnyCodable],
        caller: ToolCaller
    ) async throws -> (ToolResult, [SpanRef]) {
        // Create and register a subtask
        guard let description = inputs["description"]?.getValue(as: String.self),
              let spanRefsData = inputs["span_refs"]?.getValue(as: [Any].self) else {
            throw RLMError.invalidInput("Missing required inputs for spawn_subtask")
        }
        
        let subtaskId = UUID().uuidString
        let subtask = RLMSubtask(
            subtaskId: subtaskId,
            description: description,
            spanRefs: [], // Would need to parse span refs
            priority: inputs["priority"]?.getValue(as: Int.self) ?? 0
        )
        
        spawnedSubtasks[subtaskId] = subtask
        
        return (
            ToolResult(
                success: true,
                output: ["subtask_id": AnyCodable(subtaskId)],
                errorMessage: nil,
                evidenceHash: "",
                duration: 0,
                resourcesConsumed: ToolResources(toolCalls: 1)
            ),
            []
        )
    }
    
    private func getSubtaskResult(
        inputs: [String: AnyCodable]
    ) async throws -> (ToolResult, [SpanRef]) {
        guard let subtaskId = inputs["subtask_id"]?.getValue(as: String.self) else {
            throw RLMError.invalidInput("Missing subtask_id")
        }
        
        guard let subtask = spawnedSubtasks[subtaskId] else {
            throw RLMError.subtaskNotFound("Subtask not found: \(subtaskId)")
        }
        
        // In a real implementation, this would fetch the actual result
        // For now, return stub result
        return (
            ToolResult(
                success: true,
                output: [
                    "subtask_id": AnyCodable(subtaskId),
                    "status": AnyCodable("completed"),
                    "result": AnyCodable("Stub result")
                ],
                errorMessage: nil,
                evidenceHash: "",
                duration: 0,
                resourcesConsumed: ToolResources(toolCalls: 1)
            ),
            subtask.spanRefs
        )
    }
    
    private func synthesizeArtifact(
        inputs: [String: AnyCodable]
    ) async throws -> (ToolResult, [SpanRef]) {
        // Stub implementation
        return (
            ToolResult(
                success: true,
                output: ["artifact_id": AnyCodable(UUID().uuidString)],
                errorMessage: nil,
                evidenceHash: "",
                duration: 0,
                resourcesConsumed: ToolResources(toolCalls: 1)
            ),
            []
        )
    }
    
    private func generateProvenance(
        inputs: [String: AnyCodable]
    ) async throws -> (ToolResult, [SpanRef]) {
        // Stub implementation
        return (
            ToolResult(
                success: true,
                output: ["provenance": AnyCodable("Stub provenance graph")],
                errorMessage: nil,
                evidenceHash: "",
                duration: 0,
                resourcesConsumed: ToolResources(toolCalls: 1)
            ),
            []
        )
    }
}

// MARK: - Supporting Types

/// State of an RLM runtime loop.
public struct RLMState: Sendable {
    public let sessionId: String
    public var currentDepth: Int
    public var remainingToolCalls: Int
    public var remainingPlannerTokens: Int
    public var remainingWorkerTokens: Int
    public let startTime: Date
    public var lastEnvironmentCheck: Date?
    
    public init(
        sessionId: String,
        currentDepth: Int,
        remainingToolCalls: Int,
        remainingPlannerTokens: Int,
        remainingWorkerTokens: Int,
        startTime: Date
    ) {
        self.sessionId = sessionId
        self.currentDepth = currentDepth
        self.remainingToolCalls = remainingToolCalls
        self.remainingPlannerTokens = remainingPlannerTokens
        self.remainingWorkerTokens = remainingWorkerTokens
        self.startTime = startTime
    }
}

/// Who is calling a tool.
public enum ToolCaller: Sendable {
    case planner
    case worker
}

/// RLM subtask for decomposition.
public struct RLMSubtask: Sendable {
    public let subtaskId: String
    public let description: String
    public let spanRefs: [SpanRef]
    public let priority: Int
    
    public init(
        subtaskId: String,
        description: String,
        spanRefs: [SpanRef],
        priority: Int = 0
    ) {
        self.subtaskId = subtaskId
        self.description = description
        self.spanRefs = spanRefs
        self.priority = priority
    }
}

/// RLM subtask result.
public struct RLMSubtaskResult: Sendable {
    public let subtaskId: String
    public let success: Bool
    public let output: [String: AnyCodable]
    public let evidence: EvidenceRecord?
    
    public init(
        subtaskId: String,
        success: Bool,
        output: [String: AnyCodable],
        evidence: EvidenceRecord?
    ) {
        self.subtaskId = subtaskId
        self.success = success
        self.output = output
        self.evidence = evidence
    }
}

/// Phase results (stubs for now).
public struct ExplorationPhaseResult: Sendable {
    public let directory: [SourceMetadata]
    public let sampledSpans: [SpanRef]
    public let evidence: EvidenceRecord
}

public struct DecompositionPhaseResult: Sendable {
    public let subtasks: [RLMSubtask]
    public let evidence: EvidenceRecord
}

public struct ExecutionPhaseResult: Sendable {
    public let subtaskResults: [RLMSubtaskResult]
    public let evidence: EvidenceRecord
}

public struct VerificationPhaseResult: Sendable {
    public let success: Bool
    public let errorMessage: String?
    public let evidence: EvidenceRecord
}

// MARK: - Model Interfaces

/// Interface for planner models (high-level strategy).
public protocol RLMPlannerModel: Sendable {
    /// Generate exploration plan based on directory and request.
    func planExploration(
        request: String,
        directory: [SourceMetadata],
        initialContext: [SpanRef]
    ) async throws -> ExplorationPlan
    
    /// Decompose exploration results into subtasks.
    func decomposeIntoTasks(
        explorationResults: ExplorationResults
    ) async throws -> [RLMSubtask]
    
    /// Synthesize final artifact from subtask results.
    func synthesizeArtifact(
        subtaskResults: [RLMSubtaskResult]
    ) async throws -> SynthesisResult
}

/// Interface for worker models (detailed execution).
public protocol RLMWorkerModel: Sendable {
    /// Execute a subtask with focused context.
    func executeSubtask(
        subtask: RLMSubtask,
        contextSpans: [String] // Span contents
    ) async throws -> RLMSubtaskResult
}

// MARK: - Stub Types for Model Interfaces

public struct ExplorationPlan: Sendable {
    public let toolCalls: [ToolOperation]
    public let priorities: [String: Int]
}

public struct ExplorationResults: Sendable {
    public let sampledData: [String: AnyCodable]
    public let insights: [String]
}

public struct SynthesisResult: Sendable {
    public let artifact: RLMArtifact
    public let confidence: Double
}

// MARK: - Errors

public enum RLMError: Error, Sendable {
    case operationNotAllowed(String)
    case budgetExceeded(String)
    case recursionLimitExceeded(String)
    case toolExecutionFailed(String, underlyingError: Error?)
    case invalidInput(String)
    case subtaskNotFound(String)
    case verificationFailed(String)
    
    public var description: String {
        switch self {
        case .operationNotAllowed(let msg): return "Operation not allowed: \(msg)"
        case .budgetExceeded(let msg): return "Budget exceeded: \(msg)"
        case .recursionLimitExceeded(let msg): return "Recursion limit exceeded: \(msg)"
        case .toolExecutionFailed(let msg, _): return "Tool execution failed: \(msg)"
        case .invalidInput(let msg): return "Invalid input: \(msg)"
        case .subtaskNotFound(let msg): return "Subtask not found: \(msg)"
        case .verificationFailed(let msg): return "Verification failed: \(msg)"
        }
    }
}