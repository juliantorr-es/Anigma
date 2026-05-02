@_exported import HarmoniaV2Surface

import AnigmaPrimitives
import ExecutionCore
import Foundation
import HarmoniaV2Contracts
import TelemetryCore

public enum HarmoniaRuntime {
    public static func makeService() -> HarmoniaService {
        HarmoniaService()
    }

    @discardableResult
    public static func remember(
        content: String,
        userId: String? = nil,
        source: String = "harmonia-runtime",
        metadata: [String: String] = [:]
    ) async throws -> String {
        try await HarmoniaService().remember(
            content: content,
            userId: userId,
            source: source,
            metadata: metadata
        )
    }

    public static func authorityMatrix(
        for action: HarmoniaV2Contracts.HarmoniaRuntimeAction,
        stage: HarmoniaV2Contracts.HarmoniaAuthorityStage
    ) -> HarmoniaV2Contracts.HarmoniaAuthorityMatrixEntry {
        HarmoniaV2Contracts.HarmoniaAuthorityMatrix.entry(action: action, stage: stage)
    }

    public static func traceContext(
        action: HarmoniaRuntimeAction,
        actor: String,
        policyContext: String,
        evidenceReference: String? = nil,
        parentSpanID: String? = nil
    ) -> HarmoniaRuntimeTraceContext {
        HarmoniaRuntimeTraceContext(
            correlationID: TelemetryHash(input: "\(action.rawValue)|\(actor)|\(policyContext)|\(evidenceReference ?? "-")").hex,
            spanID: TelemetryHash(input: "\(action.rawValue)|\(policyContext)|span").hex,
            parentSpanID: parentSpanID,
            actor: actor,
            policyContext: policyContext,
            evidenceReference: evidenceReference,
            action: action.rawValue
        )
    }

    public static func query(_ text: String, userId: String? = nil) async throws -> QueryResponse {
        let actor = userId ?? "system"
        let policyContext = Self.queryPolicyContext

        do {
            let response = try await HarmoniaService().query(text, userId: userId)
            let receipt = generateReceipt(
                action: .queryExecution,
                decision: .allowed,
                reasonCode: .success,
                input: text,
                capabilityArea: .ready,
                policyContext: policyContext,
                outputsHash: Self.queryResponseHash(for: response)
            )
            let trace = traceContext(
                action: .queryExecution,
                actor: actor,
                policyContext: policyContext,
                evidenceReference: receipt.receiptID
            )
            let auditEvent = emitAuditEvent(
                action: .queryExecution,
                outcome: .allowed,
                reasonCode: .success,
                actor: actor,
                policyContext: policyContext,
                evidenceReference: receipt.receiptID,
                timestampMs: receipt.timestampMs,
                correlationID: trace.correlationID,
                metadata: trace.metadata
            )
            try persistRuntimeArtifacts(receipt: receipt, auditEvent: auditEvent)
            return response
        } catch let error as HarmoniaError {
            switch error {
            case .notImplemented(let message):
                let failureReceipt = generateReceipt(
                    action: .queryExecution,
                    decision: .error,
                    reasonCode: .notConfigured,
                    input: text,
                    capabilityArea: .deferred,
                    policyContext: policyContext
                )
                let trace = traceContext(
                    action: .queryExecution,
                    actor: actor,
                    policyContext: policyContext,
                    evidenceReference: failureReceipt.receiptID
                )
                let failureEvent = emitAuditEvent(
                    action: .queryExecution,
                    outcome: .error,
                    reasonCode: .notConfigured,
                    actor: actor,
                    policyContext: policyContext,
                    evidenceReference: failureReceipt.receiptID,
                    timestampMs: failureReceipt.timestampMs,
                    correlationID: trace.correlationID,
                    metadata: trace.metadata
                )
                try persistRuntimeArtifacts(receipt: failureReceipt, auditEvent: failureEvent)

                let actionableError = createActionableError(
                    from: HarmoniaRuntimeError.notConfigured(
                        capability: "query/session",
                        reason: message
                    ),
                    action: .queryExecution,
                    reasonCode: .notConfigured
                )
                throw actionableError
            case .internalError, .vaultError:
                let failureReceipt = generateReceipt(
                    action: .queryExecution,
                    decision: .error,
                    reasonCode: .backendFailure,
                    input: text,
                    capabilityArea: .deferred,
                    policyContext: policyContext
                )
                let trace = traceContext(
                    action: .queryExecution,
                    actor: actor,
                    policyContext: policyContext,
                    evidenceReference: failureReceipt.receiptID
                )
                let failureEvent = emitAuditEvent(
                    action: .queryExecution,
                    outcome: .error,
                    reasonCode: .backendFailure,
                    actor: actor,
                    policyContext: policyContext,
                    evidenceReference: failureReceipt.receiptID,
                    timestampMs: failureReceipt.timestampMs,
                    correlationID: trace.correlationID,
                    metadata: trace.metadata
                )
                try persistRuntimeArtifacts(receipt: failureReceipt, auditEvent: failureEvent)
                throw error
            }
        }
    }

    public static func executePhase9(
        objective: String,
        userId: String? = nil,
        policyContext: String? = nil
    ) async throws -> HarmoniaPhase9ExecutionResult {
        let trimmedObjective = objective.trimmingCharacters(in: .whitespacesAndNewlines)
        let actor = userId ?? "cli-user"
        let effectivePolicyContext = Self.phase9PolicyContext(policyContext)
        let conductorResult = try await HarmoniaService().executeDocumentAnalysis(
            objective: trimmedObjective,
            userId: userId,
            policyContext: effectivePolicyContext
        )

        let reasonCode = runtimeReasonCode(from: conductorResult.reasonCode)
        let receiptDecision: ReceiptDecision = conductorResult.disposition == .failed ? .error : .allowed
        let receipt = generateReceipt(
            action: .phase9Execution,
            decision: receiptDecision,
            reasonCode: reasonCode,
            input: conductorResult.objective,
            capabilityArea: conductorResult.disposition == .failed ? .partial : .ready,
            policyContext: effectivePolicyContext,
            outputsHash: conductorResult.disposition == .failed ? nil : TelemetryHash(input: conductorResult.summary)
        )
        let trace = traceContext(
            action: .phase9Execution,
            actor: actor,
            policyContext: effectivePolicyContext,
            evidenceReference: receipt.receiptID,
            parentSpanID: conductorResult.runIdentity.runID
        )
        let auditEvent = emitAuditEvent(
            action: .phase9Execution,
            outcome: receiptDecision,
            reasonCode: reasonCode,
            actor: actor,
            policyContext: effectivePolicyContext,
            evidenceReference: receipt.receiptID,
            timestampMs: receipt.timestampMs,
            correlationID: trace.correlationID,
            spanID: trace.spanID,
            parentSpanID: trace.parentSpanID,
            metadata: trace.metadata.merging(phase9Metadata(
                objective: conductorResult.objective.isEmpty ? nil : conductorResult.objective,
                policyContext: effectivePolicyContext,
                disposition: phase9Disposition(from: conductorResult.disposition),
                laneName: conductorResult.laneName,
                runID: conductorResult.runIdentity.runID,
                reasonCode: conductorResult.reasonCode.rawValue
            )) { _, new in new }
        )
        try persistRuntimeArtifacts(receipt: receipt, auditEvent: auditEvent)
        return HarmoniaPhase9ExecutionResult(
            objective: conductorResult.objective,
            userId: userId,
            policyContext: effectivePolicyContext,
            disposition: phase9Disposition(from: conductorResult.disposition),
            summary: conductorResult.summary,
            nextActions: conductorResult.nextActions,
            receipt: receipt,
            auditEvent: auditEvent,
            reasonCode: reasonCode,
            errorDescription: conductorResult.errorDescription,
            recoverySuggestion: conductorResult.recoverySuggestion
        )
    }

    public static func executeTool(
        name: String,
        arguments: [String: Any],
        userId: String? = nil,
        policyContext: String? = nil
    ) async throws -> HarmoniaToolResult {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let actor = userId ?? "cli-user"
        let effectivePolicyContext = Self.toolPolicyContext(policyContext)
        let result: HarmoniaToolResult
        let reasonCode: HarmoniaRuntimeReasonCode
        let evaluateEntry = authorityMatrix(for: .toolExecution, stage: .evaluate)
        let submitEntry = authorityMatrix(for: .toolExecution, stage: .submit)
        let receiptEntry = authorityMatrix(for: .toolExecution, stage: .receipt)
        if trimmedName.isEmpty {
            result = HarmoniaToolResult(
                toolName: trimmedName,
                output: "Tool execution requires a non-empty tool name.",
                success: false,
                error: "validationFailed; authority=\(evaluateEntry.authority); policyContext=\(effectivePolicyContext); arguments=\(arguments.count)"
            )
            reasonCode = .validationFailed
        } else {
            do {
                result = try await HarmoniaService().executeTool(
                    name: trimmedName,
                    arguments: arguments,
                    userId: userId,
                    policyContext: effectivePolicyContext
                )
                reasonCode = result.success ? .success : .notConfigured
            } catch {
                result = HarmoniaToolResult(
                    toolName: trimmedName,
                    output: "Tool execution failed before dispatch.",
                    success: false,
                    error: "backendFailure; authority=\(submitEntry.authority); policyContext=\(effectivePolicyContext); error=\(error.localizedDescription)"
                )
                reasonCode = .backendFailure
            }
        }

        let receipt = generateReceipt(
            action: .toolExecution,
            decision: result.success ? .allowed : .error,
            reasonCode: reasonCode,
            input: Self.toolInputFingerprint(name: trimmedName, arguments: arguments),
            capabilityArea: result.success ? .ready : .deferred,
            policyContext: effectivePolicyContext,
            outputsHash: Self.toolOutputHash(for: result)
        )
        let trace = traceContext(
            action: .toolExecution,
            actor: actor,
            policyContext: effectivePolicyContext,
            evidenceReference: receipt.receiptID
        )
        let auditEvent = emitAuditEvent(
            action: .toolExecution,
            outcome: result.success ? .allowed : .error,
            reasonCode: reasonCode,
            actor: actor,
            policyContext: effectivePolicyContext,
            evidenceReference: receipt.receiptID,
            timestampMs: receipt.timestampMs,
            correlationID: trace.correlationID,
            spanID: trace.spanID,
            parentSpanID: trace.parentSpanID,
            metadata: toolMetadata(
                toolName: trimmedName,
                arguments: arguments,
                result: result,
                policyContext: effectivePolicyContext,
                receiptAuthority: receiptEntry.authority
            )
        )
        try persistRuntimeArtifacts(receipt: receipt, auditEvent: auditEvent)
        return result
    }

    public static func evaluatePolicy(
        principal: String,
        resource: String,
        action: String,
        userId: String? = nil,
        policyContext: String? = nil,
        attributes: [String: String] = [:]
    ) async throws -> HarmoniaPolicyEvaluationResult {
        let effectivePolicyContext = Self.policyEvaluationContext(policyContext)
        let actor = userId ?? principal
        let normalizedAttributes = Self.normalizedPolicyAttributes(attributes)
        let conductorResult = try await HarmoniaService().executePolicyEvaluation(
            principal: principal,
            resource: resource,
            action: action,
            policyContext: effectivePolicyContext,
            attributes: normalizedAttributes
        )

        let decision = policyDecision(from: conductorResult)
        let reasonCode = runtimeReasonCode(from: conductorResult.reasonCode)
        let receiptDecision: ReceiptDecision = decision == .allow ? .allowed : .error
        let receipt = generateReceipt(
            action: .policyEvaluation,
            decision: receiptDecision,
            reasonCode: reasonCode,
            input: Self.policyInputFingerprint(
                principal: principal,
                resource: resource,
                action: action,
                attributes: normalizedAttributes
            ),
            capabilityArea: .ready,
            policyContext: effectivePolicyContext,
            outputsHash: TelemetryHash(input: conductorResult.summary)
        )
        let trace = traceContext(
            action: .policyEvaluation,
            actor: actor.isEmpty ? "system" : actor,
            policyContext: effectivePolicyContext,
            evidenceReference: receipt.receiptID,
            parentSpanID: conductorResult.runIdentity.runID
        )
        let metadata = trace.metadata.merging(policyMetadata(
            principal: principal,
            resource: resource,
            action: action,
            decision: decision,
            result: conductorResult,
            attributes: normalizedAttributes
        )) { _, new in new }
        let auditEvent = emitAuditEvent(
            action: .policyEvaluation,
            outcome: receiptDecision,
            reasonCode: reasonCode,
            actor: actor.isEmpty ? "system" : actor,
            policyContext: effectivePolicyContext,
            evidenceReference: receipt.receiptID,
            timestampMs: receipt.timestampMs,
            correlationID: trace.correlationID,
            spanID: trace.spanID,
            parentSpanID: trace.parentSpanID,
            metadata: metadata
        )
        try persistRuntimeArtifacts(receipt: receipt, auditEvent: auditEvent)

        return HarmoniaPolicyEvaluationResult(
            principal: principal,
            resource: resource,
            action: action,
            policyContext: effectivePolicyContext,
            decision: decision,
            reasonCode: reasonCode,
            summary: conductorResult.summary,
            nextActions: conductorResult.nextActions,
            regulatedDecision: normalizedAttributes["regulated_decision"] == "true",
            attributes: normalizedAttributes,
            receipt: receipt,
            auditEvent: auditEvent,
            errorDescription: conductorResult.errorDescription,
            recoverySuggestion: conductorResult.recoverySuggestion
        )
    }
    
    /// Execute speculative tree verification (Phase 4 API)
    public static func verifySpeculativeTree(
        draftTokens: [String],
        verifierModelID: String,
        userId: String? = nil,
        policyContext: String? = nil
    ) async throws -> HarmoniaSpeculativeTreeVerificationResult {
        let actor = userId ?? "system"
        let effectivePolicyContext = policyContext ?? "harmonia.runtime.speculative-verification"
        let reasonCode: HarmoniaRuntimeReasonCode
        
        let result = try await HarmoniaService().verifySpeculativeTree(
            draftTokens: draftTokens,
            verifierModelID: verifierModelID
        )
        reasonCode = result.isValid ? .success : .validationFailed
        
        let receipt = generateReceipt(
            action: .capabilityCheck,
            decision: result.isValid ? .allowed : .error,
            reasonCode: reasonCode,
            input: "speculative_tree_verification|\(draftTokens.count)_tokens|\(verifierModelID)",
            capabilityArea: .ready,
            policyContext: effectivePolicyContext,
            outputsHash: TelemetryHash(input: result.metadata.treeHash)
        )
        
        let auditEvent = emitAuditEvent(
            action: .capabilityCheck,
            outcome: result.isValid ? .allowed : .error,
            reasonCode: reasonCode,
            actor: actor,
            policyContext: effectivePolicyContext,
            evidenceReference: receipt.receiptID,
            timestampMs: receipt.timestampMs,
            metadata: [
                "speculative_depth": "\(result.metadata.depthLevel)",
                "speculative_nodes": "\(result.metadata.nodeCount)",
                "speculative_tree_hash": result.metadata.treeHash,
                "tokens_accepted": "\(result.speculativeTokensAccepted)",
                "verifier_model": verifierModelID
            ]
        )
        
        try persistRuntimeArtifacts(receipt: receipt, auditEvent: auditEvent)
        
        return result
    }

    public static func status() -> HarmoniaRuntimeStatus {
        HarmoniaRuntimeStatus(
            health: .degraded,
            summary: "HarmoniaRuntime is compile-stable with durable receipt/audit journaling and conductor-backed query, document-analysis, and tool entrypoints.",
            querySession: .ready,
            memoryContext: .partial,
            receiptsObservability: .partial,
            orchestration: .ready,
            notes: [
                "The executable imports HarmoniaRuntime instead of legacy HarmoniaModule.",
                "HarmoniaV2Surface stays behind the facade.",
                "Query/session routes through deterministic symbolic inference, memory retrieval, receipts, and audit metadata.",
                "Phase9 execution routes through HarmoniaConductor and a deterministic local document-analysis lane by default.",
                "Tool execution routes through the governed HarmoniaRuntime tool gateway.",
                "Runtime actions are journaled to a durable file-backed receipt/audit sink under Application Support.",
                "Actionable error codes provide clear failure reasons and recovery suggestions."
            ]
        )
    }

    private static let queryPolicyContext = "harmonia.runtime.query-session"
    private static let defaultPhase9PolicyContext = "harmonia.runtime.phase9"
    private static let defaultToolPolicyContext = "harmonia.runtime.tool-dispatch"
    private static let defaultPolicyEvaluationContext = "harmonia.runtime.policy-evaluation"

    private static func queryResponseHash(for response: QueryResponse) -> TelemetryHash {
        let fingerprint = QueryResponseFingerprint(
            answer: response.answer,
            sources: response.sources,
            confidence: response.confidence
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard
            let data = try? encoder.encode(fingerprint),
            let text = String(data: data, encoding: .utf8)
        else {
            return TelemetryHash(
                input: "\(response.answer)|\(response.sources.count)|\(response.confidence)"
            )
        }

        return TelemetryHash(input: text)
    }

    private static func phase9PolicyContext(_ policyContext: String?) -> String {
        guard let policyContext, !policyContext.isEmpty else {
            return defaultPhase9PolicyContext
        }
        return policyContext
    }

    private static func persistRuntimeArtifacts(
        receipt: ReceiptWire,
        auditEvent: DiagnosticEvent
    ) throws {
        try HarmoniaRuntimeJournal.shared.record(receipt: receipt)
        try HarmoniaRuntimeJournal.shared.record(auditEvent: auditEvent)
    }

    private static func phase9Metadata(
        objective: String?,
        policyContext: String,
        disposition: HarmoniaPhase9Disposition,
        laneName: String,
        runID: String,
        reasonCode: String
    ) -> [String: String] {
        var metadata: [String: String] = [
            "disposition": disposition.rawValue,
            "policy_context": policyContext,
            "lane_name": laneName,
            "run_id": runID,
            "reason_code": reasonCode
        ]

        if let objective, !objective.isEmpty {
            metadata["objective"] = objective
        }

        return metadata
    }

    private static func phase9Disposition(from disposition: HarmoniaConductorDisposition) -> HarmoniaPhase9Disposition {
        switch disposition {
        case .completed:
            return .completed
        case .deferred:
            return .deferred
        case .failed:
            return .failed
        }
    }

    private static func toolPolicyContext(_ policyContext: String?) -> String {
        guard let policyContext, !policyContext.isEmpty else {
            return defaultToolPolicyContext
        }
        return policyContext
    }

    private static func policyEvaluationContext(_ policyContext: String?) -> String {
        guard let policyContext, !policyContext.isEmpty else {
            return defaultPolicyEvaluationContext
        }
        return policyContext
    }

    private static func policyDecision(from result: HarmoniaConductorLaneResult) -> HarmoniaPolicyDecision {
        if result.reasonCode == .validationFailed || result.policyCheckpoints.contains(where: { checkpoint in
            checkpoint.metadata["decision"] == "escalate"
        }) {
            return .escalate
        }
        if result.disposition == .completed && result.reasonCode == .success {
            return .allow
        }
        return .deny
    }

    private static func normalizedPolicyAttributes(_ attributes: [String: String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: attributes.map { key, value in
            (key, value.trimmingCharacters(in: .whitespacesAndNewlines))
        })
    }

    private static func policyInputFingerprint(
        principal: String,
        resource: String,
        action: String,
        attributes: [String: String]
    ) -> String {
        let encodedAttributes = attributes.keys.sorted().map { key in
            "\(key)=\(attributes[key] ?? "")"
        }.joined(separator: "|")
        return "principal=\(principal)|resource=\(resource)|action=\(action)|attributes=\(encodedAttributes)"
    }

    private static func policyMetadata(
        principal: String,
        resource: String,
        action: String,
        decision: HarmoniaPolicyDecision,
        result: HarmoniaConductorLaneResult,
        attributes: [String: String]
    ) -> [String: String] {
        var metadata: [String: String] = [
            "principal": principal,
            "resource": resource,
            "policy_action": action,
            "decision": decision.rawValue,
            "reason_code": result.reasonCode.rawValue,
            "disposition": result.disposition.rawValue,
            "lane_name": result.laneName,
            "run_id": result.runIdentity.runID,
            "regulated_decision": attributes["regulated_decision"] ?? "false",
            "attribute_count": "\(attributes.count)"
        ]
        if !attributes.isEmpty {
            metadata["attribute_keys"] = attributes.keys.sorted().joined(separator: ",")
        }
        if let checkpoint = result.policyCheckpoints.first {
            metadata["checkpoint_decision"] = checkpoint.metadata["decision"] ?? decision.rawValue
        }
        return metadata
    }

    private static func toolInputFingerprint(
        name: String,
        arguments: [String: Any]
    ) -> String {
        let canonicalArguments: String
        if JSONSerialization.isValidJSONObject(arguments),
           let data = try? JSONSerialization.data(withJSONObject: arguments, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            canonicalArguments = string
        } else {
            canonicalArguments = arguments.keys.sorted().map { key in
                let value = arguments[key].map { String(describing: $0) } ?? "<nil>"
                return "\(key)=\(value)"
            }.joined(separator: "|")
        }

        return "tool=\(name)|arguments=\(canonicalArguments)"
    }

    private static func toolOutputHash(for result: HarmoniaToolResult) -> TelemetryHash {
        TelemetryHash(
            input: [
                "tool=\(result.toolName)",
                "output=\(result.output)",
                "success=\(result.success)",
                "error=\(result.error ?? "-")"
            ].joined(separator: "|")
        )
    }

    private static func toolMetadata(
        toolName: String,
        arguments: [String: Any],
        result: HarmoniaToolResult,
        policyContext: String,
        receiptAuthority: String
    ) -> [String: String] {
        var metadata: [String: String] = [
            "tool_name": toolName,
            "argument_count": "\(arguments.count)",
            "success": "\(result.success)",
            "policy_context": policyContext,
            "receipt_authority": receiptAuthority
        ]

        if !arguments.isEmpty {
            metadata["argument_keys"] = arguments.keys.sorted().joined(separator: ",")
        }

        if let error = result.error, !error.isEmpty {
            metadata["tool_error"] = error
        }

        return metadata
    }

    private static func runtimeReasonCode(from reasonCode: HarmoniaConductorReasonCode) -> HarmoniaRuntimeReasonCode {
        switch reasonCode {
        case .success:
            return .success
        case .validationFailed:
            return .validationFailed
        case .integrationPending:
            return .integrationPending
        case .notConfigured:
            return .notConfigured
        case .policyDenied:
            return .policyDenied
        case .backendFailure:
            return .backendFailure
        case .laneUnavailable:
            return .capabilityUnavailable
        }
    }
}

public struct HarmoniaRuntimeTraceContext: Sendable, Codable {
    public let correlationID: String
    public let spanID: String
    public let parentSpanID: String?
    public let actor: String
    public let policyContext: String
    public let evidenceReference: String?
    public let action: String

    public init(
        correlationID: String,
        spanID: String,
        parentSpanID: String?,
        actor: String,
        policyContext: String,
        evidenceReference: String?,
        action: String
    ) {
        self.correlationID = correlationID
        self.spanID = spanID
        self.parentSpanID = parentSpanID
        self.actor = actor
        self.policyContext = policyContext
        self.evidenceReference = evidenceReference
        self.action = action
    }

    public var metadata: [String: String] {
        var metadata: [String: String] = [
            "actor": actor,
            "policy_context": policyContext,
            "action": action
        ]
        if let evidenceReference {
            metadata["evidence_reference"] = evidenceReference
        }
        if let parentSpanID {
            metadata["parent_span_id"] = parentSpanID
        }
        return metadata
    }
}

public enum HarmoniaRuntimeCapabilityState: String, Sendable, Codable {
    case ready
    case partial
    case deferred
}

public struct HarmoniaRuntimeStatus: Sendable, Codable {
    public let health: HealthStatus
    public let summary: String
    public let querySession: HarmoniaRuntimeCapabilityState
    public let memoryContext: HarmoniaRuntimeCapabilityState
    public let receiptsObservability: HarmoniaRuntimeCapabilityState
    public let orchestration: HarmoniaRuntimeCapabilityState
    public let notes: [String]

    public init(
        health: HealthStatus,
        summary: String,
        querySession: HarmoniaRuntimeCapabilityState,
        memoryContext: HarmoniaRuntimeCapabilityState,
        receiptsObservability: HarmoniaRuntimeCapabilityState,
        orchestration: HarmoniaRuntimeCapabilityState,
        notes: [String]
    ) {
        self.health = health
        self.summary = summary
        self.querySession = querySession
        self.memoryContext = memoryContext
        self.receiptsObservability = receiptsObservability
        self.orchestration = orchestration
        self.notes = notes
    }
}

public enum HarmoniaPhase9Disposition: String, Sendable, Codable, Equatable {
    case completed
    case deferred
    case failed
}

public struct HarmoniaPhase9ExecutionResult: Sendable, Codable {
    public let objective: String
    public let userId: String?
    public let policyContext: String?
    public let disposition: HarmoniaPhase9Disposition
    public let summary: String
    public let nextActions: [String]
    public let receipt: ReceiptWire
    public let auditEvent: DiagnosticEvent
    public let reasonCode: HarmoniaRuntimeReasonCode
    public let errorDescription: String?
    public let recoverySuggestion: String?

    public init(
        objective: String,
        userId: String?,
        policyContext: String?,
        disposition: HarmoniaPhase9Disposition,
        summary: String,
        nextActions: [String],
        receipt: ReceiptWire,
        auditEvent: DiagnosticEvent,
        reasonCode: HarmoniaRuntimeReasonCode,
        errorDescription: String?,
        recoverySuggestion: String?
    ) {
        self.objective = objective
        self.userId = userId
        self.policyContext = policyContext
        self.disposition = disposition
        self.summary = summary
        self.nextActions = nextActions
        self.receipt = receipt
        self.auditEvent = auditEvent
        self.reasonCode = reasonCode
        self.errorDescription = errorDescription
        self.recoverySuggestion = recoverySuggestion
    }
}

public enum HarmoniaPolicyDecision: String, Sendable, Codable, Equatable {
    case allow
    case deny
    case escalate
}

public struct HarmoniaPolicyEvaluationResult: Sendable, Codable {
    public let principal: String
    public let resource: String
    public let action: String
    public let policyContext: String
    public let decision: HarmoniaPolicyDecision
    public let reasonCode: HarmoniaRuntimeReasonCode
    public let summary: String
    public let nextActions: [String]
    public let regulatedDecision: Bool
    public let attributes: [String: String]
    public let receipt: ReceiptWire
    public let auditEvent: DiagnosticEvent
    public let errorDescription: String?
    public let recoverySuggestion: String?

    public init(
        principal: String,
        resource: String,
        action: String,
        policyContext: String,
        decision: HarmoniaPolicyDecision,
        reasonCode: HarmoniaRuntimeReasonCode,
        summary: String,
        nextActions: [String],
        regulatedDecision: Bool,
        attributes: [String: String],
        receipt: ReceiptWire,
        auditEvent: DiagnosticEvent,
        errorDescription: String?,
        recoverySuggestion: String?
    ) {
        self.principal = principal
        self.resource = resource
        self.action = action
        self.policyContext = policyContext
        self.decision = decision
        self.reasonCode = reasonCode
        self.summary = summary
        self.nextActions = nextActions
        self.regulatedDecision = regulatedDecision
        self.attributes = attributes
        self.receipt = receipt
        self.auditEvent = auditEvent
        self.errorDescription = errorDescription
        self.recoverySuggestion = recoverySuggestion
    }
}

public enum HarmoniaRuntimeError: LocalizedError, Sendable {
    case notConfigured(capability: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured(let capability, let reason):
            return "\(capability) not configured: \(reason)"
        }
    }
}

private struct QueryResponseFingerprint: Codable, Sendable {
    let answer: String
    let sources: [String]
    let confidence: Double
}
