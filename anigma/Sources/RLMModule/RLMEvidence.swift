import Foundation
import AnigmaCore
import AnigmaPrimitives

/// Evidence recording for RLM operations.
public enum RLMEvidence {
    
    // MARK: - RLM Operation Types
    
    /// RLM-specific operation types that extend the standard CoreOperationType.
    public enum RLMOperationType: String {
        case loopExecution = "rlm.loop_execution"
        case explorationPhase = "rlm.exploration_phase"
        case decompositionPhase = "rlm.decomposition_phase"
        case executionPhase = "rlm.execution_phase"
        case synthesisPhase = "rlm.synthesis_phase"
        case verificationPhase = "rlm.verification_phase"
        case toolOperation = "rlm.tool_operation"
        case subtaskSpawn = "rlm.subtask_spawn"
        case subtaskResult = "rlm.subtask_result"
        case artifactSynthesis = "rlm.artifact_synthesis"
        
        /// Convert to standard CoreOperationType.custom
        public var toOperationType: CoreOperationType {
            .custom
        }
        
        /// Get the custom type string for CoreOperationType.custom
        public var customType: String {
            rawValue
        }
    }
    
    // MARK: - Evidence Payloads
    
    /// Create evidence payload for RLM loop execution.
    public static func loopExecutionPayload(
        userRequest: String,
        policy: RLMGovernancePolicy,
        budgets: RLMResourceBudgets,
        initialContextSpans: Int
    ) -> EvidencePayload {
        .custom(
            type: RLMOperationType.loopExecution.rawValue,
            data: [
                "user_request": userRequest,
                "policy": policyDescription(policy),
                "budgets": budgetsDescription(budgets),
                "initial_context_spans": "\(initialContextSpans)"
            ]
        )
    }
    
    /// Create evidence payload for RLM tool operation.
    public static func toolOperationPayload(
        tool: ToolOperation,
        inputs: [String: AnyCodable],
        result: ToolResult,
        spanRefs: [SpanRef]
    ) -> EvidencePayload {
        .custom(
            type: RLMOperationType.toolOperation.rawValue,
            data: [
                "tool": tool.rawValue,
                "inputs": encodeInputs(inputs),
                "success": "\(result.success)",
                "error_message": result.errorMessage ?? "",
                "duration": "\(result.duration)",
                "resources": encodeResources(result.resourcesConsumed),
                "span_refs": "\(spanRefs.count)",
                "evidence_hash": result.evidenceHash
            ]
        )
    }
    
    /// Create evidence payload for subtask spawning.
    public static func subtaskSpawnPayload(
        taskDescription: String,
        subtaskType: String,
        parentSpanRefs: [SpanRef]
    ) -> EvidencePayload {
        .custom(
            type: RLMOperationType.subtaskSpawn.rawValue,
            data: [
                "task_description": taskDescription.truncated(to: 200),
                "subtask_type": subtaskType,
                "parent_spans": "\(parentSpanRefs.count)"
            ]
        )
    }
    
    /// Create evidence payload for subtask result.
    public static func subtaskResultPayload(
        subtaskId: String,
        status: String,
        result: [String: Any]? = nil
    ) -> EvidencePayload {
        var data: [String: String] = [
            "subtask_id": subtaskId,
            "status": status
        ]
        
        if let result = result {
            data["result_summary"] = String(describing: result).truncated(to: 200)
        }
        
        return .custom(
            type: RLMOperationType.subtaskResult.rawValue,
            data: data
        )
    }
    
    /// Create evidence payload for artifact synthesis.
    public static func artifactSynthesisPayload(
        artifactType: String,
        format: String,
        sourceSpans: Int,
        evidenceChainLength: Int
    ) -> EvidencePayload {
        .custom(
            type: RLMOperationType.artifactSynthesis.rawValue,
            data: [
                "artifact_type": artifactType,
                "format": format,
                "source_spans": "\(sourceSpans)",
                "evidence_chain_length": "\(evidenceChainLength)"
            ]
        )
    }
    
    /// Create evidence payload for phase execution.
    public static func phasePayload(
        phase: RLMOperationType,
        duration: TimeInterval,
        resourcesConsumed: ToolResources,
        spanRefs: [SpanRef]
    ) -> EvidencePayload {
        .custom(
            type: phase.rawValue,
            data: [
                "duration": "\(duration)",
                "resources": encodeResources(resourcesConsumed),
                "span_refs": "\(spanRefs.count)"
            ]
        )
    }
    
    // MARK: - Evidence Query Methods
    
    /// Filter evidence records for a specific session and operation.
    public static func filterEvidence(
        in chain: [EvidenceRecord],
        operation: ToolOperation? = nil,
        successOnly: Bool = false
    ) -> [EvidenceRecord] {
        chain.filter { record in
            if let op = operation, record.operation != op {
                return false
            }
            if successOnly && !record.result.success {
                return false
            }
            return true
        }
    }
    
    /// Extract all span references from an evidence chain.
    public static func extractAllSpanRefs(from chain: [EvidenceRecord]) -> [SpanRef] {
        var allRefs: Set<SpanRef> = []
        for record in chain {
            for ref in record.spanRefs {
                allRefs.insert(ref)
            }
        }
        return Array(allRefs)
    }
    
    /// Summarize resource consumption from an evidence chain.
    public static func summarizeResources(from chain: [EvidenceRecord]) -> ToolResources {
        chain.reduce(ToolResources()) { total, record in
            total + record.result.resourcesConsumed
        }
    }
    
    // MARK: - Helper Methods
    
    private static func policyDescription(_ policy: RLMGovernancePolicy) -> String {
        "allowed_tools=\(policy.allowedTools.count), max_recursion=\(policy.maxRecursionDepth), require_verification=\(policy.requireVerification)"
    }
    
    private static func budgetsDescription(_ budgets: RLMResourceBudgets) -> String {
        "max_tool_calls=\(budgets.maxToolCalls), planner_tokens=\(budgets.plannerTokenBudget), worker_tokens=\(budgets.workerTokenBudget)"
    }
    
    private static func encodeInputs(_ inputs: [String: AnyCodable]) -> String {
        let keys = inputs.keys.sorted()
        let encoded = keys.map { "\($0)" }.joined(separator: ",")
        return encoded.truncated(to: 100)
    }
    
    private static func encodeResources(_ resources: ToolResources) -> String {
        "tokens=\(resources.tokensUsed), tool_calls=\(resources.toolCalls), bytes=\(resources.bytesRetrieved), spans=\(resources.spansReferenced)"
    }
}

// MARK: - String Extension

private extension String {
    func truncated(to length: Int) -> String {
        guard self.count > length else { return self }
        let endIndex = self.index(self.startIndex, offsetBy: length)
        return String(self[..<endIndex]) + "..."
    }
}

// MARK: - Evidence Recording Helper

/// Helper for recording RLM evidence with proper context.
public actor RLMEvidenceRecorder {
    private let evidenceAuthority: (any EvidenceAuthority)?
    private let sessionId: String
    private let principal: Principal
    
    public init(
        evidenceAuthority: (any EvidenceAuthority)?,
        sessionId: String = UUID().uuidString,
        principal: Principal = .system
    ) {
        self.evidenceAuthority = evidenceAuthority
        self.sessionId = sessionId
        self.principal = principal
    }
    
    /// Record RLM evidence with proper context.
    public func record(
        operationType: RLMEvidence.RLMOperationType,
        payload: EvidencePayload,
        context: ExecutionContext? = nil
    ) async throws -> CoreReceipt? {
        guard let evidenceAuthority = evidenceAuthority else {
            return nil
        }
        
        let executionContext = context ?? ExecutionContext(
            principal: principal,
            sessionId: sessionId,
            metadata: ["module": "RLMModule"]
        )
        
        return try await evidenceAuthority.record(
            operation: operationType.toOperationType,
            principal: executionContext.principal,
            payload: payload,
            governanceDecision: nil,
            context: executionContext
        )
    }
    
    /// Create child recorder with same session but different correlation ID.
    public func childRecorder(metadata: [String: String] = [:]) -> RLMEvidenceRecorder {
        RLMEvidenceRecorder(
            evidenceAuthority: evidenceAuthority,
            sessionId: sessionId,
            principal: principal
        )
    }
}