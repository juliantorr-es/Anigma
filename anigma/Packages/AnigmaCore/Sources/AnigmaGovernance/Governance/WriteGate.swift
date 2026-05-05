import Foundation
import GovernanceContracts
import AnigmaPrimitives
import GovernanceCore
import SecurityEventsManager

/// The Write Gate ensures quality checks pass before writes are allowed.
/// This actor lives in Tier 2 (Platform Runtime) as it manages state.
public actor WriteGate: RuntimeWriteGateAPI {
    private var checks: [GovernanceContracts.WriteCheck] = []
    private var auditLog: AuditLogging?

    public init() {}

    public func setAuditLog(_ log: any AuditLogging) async {
        self.auditLog = log
    }

    public func registerCheck(_ check: any GovernanceContracts.WriteCheck) async {
        checks.append(check)
    }

    public func removeCheck(id: String) {
        checks.removeAll { $0.id == id }
    }

    public func evaluate(_ proposal: GovernanceContracts.WriteProposal) async -> GovernanceContracts.WriteGateDecision {
        var results: [GovernanceContracts.WriteCheckResult] = []
        var allPassed = true

        for check in checks {
            guard check.appliesTo(proposal) else { continue }

            let result = await check.evaluate(proposal)
            results.append(result)

            if !result.passed && check.isBlocking {
                allPassed = false
            }
        }

        let decision = GovernanceContracts.WriteGateDecision(
            allowed: allPassed,
            checkResults: results,
            evaluatedAt: Date()
        )

        // Log to SecurityEventsManager (if available)
        // if !allPassed, let manager = SecurityEventingService.shared {
        //     manager.logCapabilityDecision(
        //         engineId: "write-gate",
        //         capability: "write_operation",
        //         granted: false,
        //         trustTier: "unknown",
        //         zone: "write-zone",
        //         reason: results.first(where: { !$0.passed })?.message ?? "Write gate policy violation"
        //     )
        // }

        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: allPassed ? .policyEvaluated : .policyViolation,
                principal: proposal.principal,
                module: "WriteGate",
                description: allPassed ? "Policy evaluation passed" : "Policy evaluation failed",
                metadata: [
                    "result": allPassed ? "passed" : "failed",
                    "operation": proposal.operation,
                    "module": proposal.module
                ]
            )
        }

        return decision
    }
}
