//
//  AnigmaCLIOrchestrator.swift
//  AnigmaCLIOrchestrator
//
//  Orchestrator entry point for plan-mode CLI tasks.
//

import AnigmaCLICore
import AnigmaCLIEventing
import AnigmaCLIGovernance
import AnigmaCLIProviders
import AnigmaCLIRouter
import Foundation

public struct LocalContractBuilder: ContractBuilder {
    private let policy: ContractPolicy

    public init(policy: ContractPolicy = .default) {
        self.policy = policy
    }

    public func buildContract(for task: TaskIntent, context: TaskContext) async throws -> TaskContract {
        let requirements = [TaskRequirement(description: task.summary)]
        let acceptance = policy.bannedPatterns.map { pattern in
            "Output must not contain \(pattern.token.uppercased()) markers."
        } + ["All requested deliverables are completed in full."]

        return TaskContract(
            taskId: task.id,
            objective: task.summary,
            requirements: requirements,
            acceptanceCriteria: acceptance,
            builder: "local-contract-builder"
        )
    }
}

public struct PlanOutcome: Sendable, Codable {
    public let contract: TaskContract
    public let route: RouteDecision

    public init(contract: TaskContract, route: RouteDecision) {
        self.contract = contract
        self.route = route
    }
}

public struct RunOutcome: Sendable, Codable {
    public let plan: PlanOutcome
    public let governance: GovernanceDecision
    public let dryRun: Bool
    public let status: ExecutionStatus
    public let message: String

    public init(
        plan: PlanOutcome,
        governance: GovernanceDecision,
        dryRun: Bool,
        status: ExecutionStatus,
        message: String
    ) {
        self.plan = plan
        self.governance = governance
        self.dryRun = dryRun
        self.status = status
        self.message = message
    }
}

public actor AnigmaCLIOrchestrator {
    private let registry: ProviderRegistry
    private let router: TaskRouter
    private let contractBuilder: any ContractBuilder
    private let eventStream: CLIEventStream

    public init(
        registry: ProviderRegistry = ProviderRegistry(),
        router: TaskRouter? = nil,
        contractBuilder: any ContractBuilder = LocalContractBuilder(),
        eventStream: CLIEventStream = CLIEventStream()
    ) {
        self.registry = registry
        self.router = router ?? TaskRouter(registry: registry)
        self.contractBuilder = contractBuilder
        self.eventStream = eventStream
    }

    public func plan(
        task: TaskIntent,
        context: TaskContext,
        requiredCapabilities: Set<ProviderCapability> = [.chat, .tools]
    ) async throws -> PlanOutcome {
        await eventStream.emit(
            CLIEvent(
                kind: .info,
                message: "Building task contract.",
                metadata: ["taskId": task.id.uuidString]
            )
        )
        let contract = try await contractBuilder.buildContract(for: task, context: context)
        await eventStream.emit(
            CLIEvent(
                kind: .contractBuilt,
                message: "Contract created.",
                metadata: ["contractId": contract.id.uuidString]
            )
        )

        let decision = router.route(task: task, requiredCapabilities: requiredCapabilities)
        await eventStream.emit(
            CLIEvent(
                kind: .routeDecision,
                message: decision.reason,
                metadata: ["selected": decision.selected?.id ?? "none"]
            )
        )

        return PlanOutcome(contract: contract, route: decision)
    }

    public func planWithReview(
        task: TaskIntent,
        context: TaskContext,
        reviewers: Int,
        reviewMode: PlanReviewMode,
        requiredCapabilities: Set<ProviderCapability> = [.chat, .tools]
    ) async throws -> PlanReviewOutcome {
        let plan = try await plan(
            task: task,
            context: context,
            requiredCapabilities: requiredCapabilities
        )

        await eventStream.emit(
            CLIEvent(
                kind: .info,
                message: "Starting \(reviewers)-review \(reviewMode.rawValue) review.",
                metadata: [
                    "contractId": plan.contract.id.uuidString,
                    "taskId": task.id.uuidString
                ]
            )
        )

        let pipeline = PlanReviewPipeline()
        let outcome = try await pipeline.review(
            task: task,
            plan: plan,
            context: context,
            reviewers: reviewers,
            mode: reviewMode
        )

        await eventStream.emit(
            CLIEvent(
                kind: .info,
                message: "Review vault written.",
                metadata: [
                    "vault": outcome.vaultURL.path,
                    "merge": outcome.mergeURL.lastPathComponent
                ]
            )
        )

        return outcome
    }

    public func stream() -> CLIEventStream {
        eventStream
    }

    public func run(
        task: TaskIntent,
        context: TaskContext,
        requiredCapabilities: Set<ProviderCapability> = [.chat, .tools],
        dryRun: Bool = true,
        governance: GovernanceEngine = GovernanceEngine()
    ) async throws -> RunOutcome {
        await eventStream.emit(
            CLIEvent(
                kind: .execution,
                message: dryRun ? "Starting dry-run execution." : "Starting execution.",
                metadata: ["taskId": task.id.uuidString]
            )
        )

        let planOutcome = try await plan(
            task: task,
            context: context,
            requiredCapabilities: requiredCapabilities
        )

        let decision = governance.evaluate(
            task: task,
            contract: planOutcome.contract,
            provider: planOutcome.route.selected,
            requiredCapabilities: requiredCapabilities
        )

        await eventStream.emit(
            CLIEvent(
                kind: .governance,
                message: decision.allowed ? "Governance approved." : "Governance denied.",
                metadata: ["issues": "\(decision.issues.count)"]
            )
        )

        let status: ExecutionStatus
        let message: String
        if !decision.allowed {
            status = .failed
            message = "Governance denied execution."
        } else if dryRun {
            status = .planned
            message = "Dry-run complete. Execution not started."
        } else {
            status = .running
            message = "Execution requested but not yet implemented."
        }

        await eventStream.emit(
            CLIEvent(
                kind: .execution,
                message: message,
                metadata: ["status": status.rawValue]
            )
        )

        return RunOutcome(
            plan: planOutcome,
            governance: decision,
            dryRun: dryRun,
            status: status,
            message: message
        )
    }
}
