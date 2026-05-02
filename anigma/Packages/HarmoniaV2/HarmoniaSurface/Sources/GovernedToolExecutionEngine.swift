import AnigmaPrimitives
import AnigmaEvents
import TelemetryCore
import CryptoKit
import Foundation
import HarmoniaV2Core

public enum ToolPolicyDecision: String, Codable, Sendable {
    case allowed
    case denied
}

public struct ToolPolicyEvaluation: Codable, Sendable {
    public let decision: ToolPolicyDecision
    public let reasonCode: String
    public let message: String?

    public init(decision: ToolPolicyDecision, reasonCode: String, message: String? = nil) {
        self.decision = decision
        self.reasonCode = reasonCode
        self.message = message
    }
}

public struct ToolExecutionReceipt: Codable, Sendable {
    public let toolName: String
    public let userId: String?
    public let policyContext: String?
    public let registeredOrigin: ToolRegistrationOrigin?
    public let policyDecision: ToolPolicyDecision
    public let reasonCode: String
    public let success: Bool
    public let sandboxed: Bool
    public let outputDigest: String
    public let timestampMs: Int64

    public init(
        toolName: String,
        userId: String?,
        policyContext: String?,
        registeredOrigin: ToolRegistrationOrigin?,
        policyDecision: ToolPolicyDecision,
        reasonCode: String,
        success: Bool,
        sandboxed: Bool,
        outputDigest: String,
        timestampMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.toolName = toolName
        self.userId = userId
        self.policyContext = policyContext
        self.registeredOrigin = registeredOrigin
        self.policyDecision = policyDecision
        self.reasonCode = reasonCode
        self.success = success
        self.sandboxed = sandboxed
        self.outputDigest = outputDigest
        self.timestampMs = timestampMs
    }
}

public actor ToolReceiptJournal {
    private var receipts: [ToolExecutionReceipt] = []

    public init() {}

    public func append(_ receipt: ToolExecutionReceipt) {
        receipts.append(receipt)
    }

    public func snapshot() -> [ToolExecutionReceipt] {
        receipts
    }
}

public struct GovernedToolPolicyEvaluator: Sendable {
    public init() {}

    public func evaluate(
        contract: ToolContract?,
        policyContext: String?
    ) -> ToolPolicyEvaluation {
        guard let contract else {
            return ToolPolicyEvaluation(
                decision: .denied,
                reasonCode: "toolNotRegistered",
                message: "Tool is not registered in the shared registry."
            )
        }

        if contract.modifiesSystem, (policyContext == nil || policyContext?.isEmpty == true) {
            return ToolPolicyEvaluation(
                decision: .denied,
                reasonCode: "policyContextRequired",
                message: "System-modifying tools require an explicit policy context."
            )
        }

        return ToolPolicyEvaluation(
            decision: .allowed,
            reasonCode: contract.modifiesSystem ? "governed" : "registered"
        )
    }
}

public actor GovernedToolExecutionEngine {
    private let registry: ToolRegistry
    private let gateway: HarmoniaToolGateway
    private let policyEvaluator: GovernedToolPolicyEvaluator
    private let journal: ToolReceiptJournal

    public init(
        registry: ToolRegistry = .shared,
        gateway: HarmoniaToolGateway = HarmoniaToolGateway(),
        policyEvaluator: GovernedToolPolicyEvaluator = GovernedToolPolicyEvaluator(),
        journal: ToolReceiptJournal = ToolReceiptJournal()
    ) {
        self.registry = registry
        self.gateway = gateway
        self.policyEvaluator = policyEvaluator
        self.journal = journal
    }

    public func execute(
        name: String,
        arguments: [String: Any],
        context: HarmoniaV2Core.ExecutionContext,
        policyContext: String?
    ) async throws -> HarmoniaV2Orchestration.ToolResult {
        let contract = registry.contract(for: name)
        let evaluation = policyEvaluator.evaluate(contract: contract, policyContext: policyContext)
        let effectivePolicyContext = policyContext ?? context.userId ?? "global"
        let origin = registry.registrationRecord(for: name)?.origin

        guard evaluation.decision == .allowed else {
            let result = HarmoniaV2Orchestration.ToolResult(
                toolName: name,
                output: evaluation.message ?? "Tool execution denied.",
                success: false,
                error: "policyDenied; reasonCode=\(evaluation.reasonCode); policyContext=\(effectivePolicyContext)"
            )
            await journal.append(
                ToolExecutionReceipt(
                    toolName: name,
                    userId: context.userId,
                    policyContext: effectivePolicyContext,
                    registeredOrigin: origin,
                    policyDecision: .denied,
                    reasonCode: evaluation.reasonCode,
                    success: result.success,
                    sandboxed: true,
                    outputDigest: Self.digest(for: result)
                )
            )
            await publishEvidence(
                action: "tool.policy.denied",
                outcome: "denied",
                toolName: name,
                context: context,
                policyContext: effectivePolicyContext,
                reasonCode: evaluation.reasonCode,
                registeredOrigin: origin,
                payloadArtifactReferences: [],
                result: result
            )
            return result
        }

        let result = try await gateway.execute(
            name: name,
            arguments: arguments,
            context: context,
            policyContext: policyContext
        )

        await journal.append(
            ToolExecutionReceipt(
                toolName: name,
                userId: context.userId,
                policyContext: effectivePolicyContext,
                registeredOrigin: origin,
                policyDecision: .allowed,
                reasonCode: result.success ? evaluation.reasonCode : "executionFailed",
                success: result.success,
                sandboxed: true,
                outputDigest: Self.digest(for: result)
            )
        )

        await publishEvidence(
            action: "tool.execution",
            outcome: result.success ? "allowed" : "failed",
            toolName: name,
            context: context,
            policyContext: effectivePolicyContext,
            reasonCode: result.success ? evaluation.reasonCode : "executionFailed",
            registeredOrigin: origin,
            payloadArtifactReferences: [],
            result: result
        )

        return result
    }

    public func receipts() async -> [ToolExecutionReceipt] {
        await journal.snapshot()
    }

    private static func digest(for result: HarmoniaV2Orchestration.ToolResult) -> String {
        let payload = "\(result.toolName)|\(result.output)|\(result.success)|\(result.error ?? "")"
        return SHA256.hash(data: Data(payload.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    private func publishEvidence(
        action: String,
        outcome: String,
        toolName: String,
        context: HarmoniaV2Core.ExecutionContext,
        policyContext: String,
        reasonCode: String,
        registeredOrigin: ToolRegistrationOrigin?,
        payloadArtifactReferences: [AgentEvidenceArtifactReference],
        result: HarmoniaV2Orchestration.ToolResult
    ) async {
        let traceID = TelemetryHash(
            input: "\(toolName)|\(context.sessionId)|\(policyContext)|\(reasonCode)"
        ).hex
        let spanID = TelemetryHash(
            input: "\(action)|\(toolName)|\(context.sessionId)|span"
        ).hex
        let metadata: [String: String] = [
            "policy_context": policyContext,
            "reason_code": reasonCode,
            "success": String(result.success),
            "sandboxed": "true",
            "registered_origin": registeredOrigin?.rawValue ?? "unknown",
            "output_digest": Self.digest(for: result)
        ]
        let event = AgentEvidenceEvent.toolExecution(
            source: "GovernedToolExecutionEngine",
            action: action,
            outcome: outcome,
            traceID: traceID,
            spanID: spanID,
            runID: context.sessionId,
            sessionID: context.sessionId,
            toolID: toolName,
            requestID: context.sessionId,
            payloadArtifactReferences: payloadArtifactReferences,
            metadata: metadata
        )
        _ = await sharedEventBus.publishWithLogging(event, source: event.source)
    }
}
