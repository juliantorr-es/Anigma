import Foundation
import HarmoniaV2Orchestration

public actor FunctionalPolicyEvaluationLane: PolicyEvaluationLane {
    public init() {}

    public func execute(
        request: HarmoniaPolicyEvaluationRequest,
        context: HarmoniaConductorExecutionContext
    ) async throws -> HarmoniaConductorLaneResult {
        let validationFailure = request.principal.isEmpty || request.resource.isEmpty || request.action.isEmpty
        let explicitDecision = request.attributes["decision"]?.lowercased()
        let writeGate = request.attributes["write_gate"]?.lowercased()
        let regulatedDecision = request.attributes["regulated_decision"]?.lowercased() == "true"
        let reviewState = request.attributes["human_review"]?.lowercased()
        let normalizedAction = request.action.lowercased()
        let modifiesState = ["write", "delete", "mutate", "update"].contains(normalizedAction)
        let escalated = !validationFailure && regulatedDecision && reviewState != "approved"

        let allowed = !validationFailure
            && !escalated
            && explicitDecision != "deny"
            && (!modifiesState || writeGate == "open" || writeGate == "allow")
        let reasonCode: HarmoniaConductorReasonCode = validationFailure
            ? .validationFailed
            : (escalated ? .policyDenied : (allowed ? .success : .policyDenied))
        let disposition: HarmoniaConductorDisposition = validationFailure
            ? .failed
            : (allowed ? .completed : .failed)
        let decision = escalated ? "escalate" : (allowed ? "allow" : "deny")

        let checkpoint = HarmoniaConductorPolicyCheckpoint(
            runIdentity: context.runIdentity,
            summary: "Policy evaluation \(decision) for \(request.action) on \(request.resource).",
            reasonCode: reasonCode,
            metadata: [
                "lane": context.laneName,
                "policy_context": context.policyContext,
                "principal": request.principal,
                "resource": request.resource,
                "action": request.action,
                "decision": decision,
                "regulated_decision": "\(regulatedDecision)",
                "attribute_count": "\(request.attributes.count)"
            ]
        )

        let receiptHook = HarmoniaConductorReceiptHook(
            runIdentity: context.runIdentity,
            actionName: "harmonia.conductor.policy-evaluation",
            reasonCode: reasonCode,
            metadata: [
                "lane": context.laneName,
                "policy_context": context.policyContext,
                "principal": request.principal,
                "resource": request.resource,
                "action": request.action,
                "decision": decision,
                "regulated_decision": "\(regulatedDecision)"
            ]
        )

        let telemetryHook = HarmoniaConductorTelemetryHook(
            runIdentity: context.runIdentity,
            category: "harmonia.conductor",
            message: "Policy evaluation completed through local deterministic Harmonia policy lane.",
            metadata: [
                "lane": context.laneName,
                "policy_context": context.policyContext,
                "decision": decision,
                "reason_code": reasonCode.rawValue
            ]
        )

        return HarmoniaConductorLaneResult(
            runIdentity: context.runIdentity,
            laneName: context.laneName,
            objective: context.objective,
            disposition: disposition,
            summary: validationFailure
                ? "Policy evaluation requires principal, resource, and action."
                : "Policy evaluation \(decision) for \(request.action) on \(request.resource).",
            nextActions: allowed
                ? ["Proceed with governed action."]
                : [escalated ? "Escalate to explicit human review before action." : "Stop governed action and surface policy receipt."],
            policyCheckpoints: [checkpoint],
            receiptHooks: [receiptHook],
            telemetryHooks: [telemetryHook],
            reasonCode: reasonCode,
            errorDescription: allowed ? nil : (escalated ? "Policy evaluation requires human review for a regulated decision." : "Policy evaluation denied the requested action."),
            recoverySuggestion: allowed ? nil : (escalated ? "Add human_review=approved after review, or route to a reviewer." : "Review attributes, write gate, and explicit decision policy.")
        )
    }
}
