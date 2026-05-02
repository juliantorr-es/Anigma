//
//  RadicallyLegibleInfrastructure.swift
//  HarmoniaModule
//
//  The unified "Radically Legible AI" infrastructure.
//  Combines receipts, data flow, reasoning governance, and institutional learning
//  into a single, coherent system for institutional AI deployment.
//

@preconcurrency import Foundation
import Foundation
import HarmoniaCore
import AnigmaPrimitives
import InferenceCore
import HarmoniaInferenceContracts
import AnigmaCore

// MARK: - Radically Legible AI Service

/// The top-level service for radically legible AI operations.
/// Every inference is transparent, governed, and auditable.
actor RadicallyLegibleService {
    private let transparencyService: TransparencyService
    private let budgetRegistry: DomainBudgetRegistry
    private let learningService: InstitutionalLearningService
    private var activeGovernors: [String: ReasoningGovernor] = [:]

    init() {
        self.transparencyService = TransparencyService()
        self.budgetRegistry = DomainBudgetRegistry()
        self.learningService = InstitutionalLearningService()
    }

    // MARK: - Task Lifecycle

    /// Begin tracking a new inference task with full transparency.
    func beginTask(
        _ task: InferenceTask,
        domain: String,
        policy: AppliedPolicyReport
    ) async -> TaskContext {
        // Get the budget for this domain/tenant
        let budget = await budgetRegistry.getBudget(
            domain: domain,
            tenantId: task.context.tenantId
        )

        // Create a reasoning governor
        let governor = ReasoningGovernor(budget: budget, taskId: task.id)
        activeGovernors[task.id] = governor

        // Start transparency tracking
        let flowBuilder = await transparencyService.beginTracking(taskId: task.id)

        // Record input
        let inputNode = await flowBuilder.recordInput(
            name: "User Input",
            metadata: ["taskKind": task.kind.rawValue]
        )

        return TaskContext(
            task: task,
            domain: domain,
            policy: policy,
            budget: budget,
            governor: governor,
            flowBuilder: flowBuilder,
            inputNodeId: inputNode.id
        )
    }

    /// Record a model being used in the task.
    func recordModelUsage(
        context: TaskContext,
        modelId: String,
        modelFamily: String,
        backend: BackendKind,
        isLocal: Bool,
        fromNodeId: String
    ) async -> String {
        let node = await context.flowBuilder.recordModelUsage(
            name: modelFamily,
            modelId: modelId,
            isLocal: isLocal,
            fromNodeId: fromNodeId,
            dataType: .processedContent,
            transformations: [.tokenized]
        )
        return node.id
    }

    /// Record reasoning happening.
    func recordReasoning(
        context: TaskContext,
        tier: String,
        fromNodeId: String
    ) async -> String {
        let node = await context.flowBuilder.recordReasoning(
            name: "Reasoning (\(tier))",
            tier: tier,
            fromNodeId: fromNodeId
        )
        return node.id
    }

    /// Check if a reasoning step is allowed.
    func checkReasoningStep(
        context: TaskContext,
        tier: ReasoningBudget.ReasoningTier,
        estimatedTokens: Int
    ) async -> ReasoningGovernor.ReasoningDecision {
        await context.governor.canProceed(tier: tier, estimatedTokens: estimatedTokens)
    }

    /// Record a completed reasoning step.
    func recordReasoningStep(
        context: TaskContext,
        step: StructuredReasoningTrace.ReasoningStep
    ) async {
        await context.governor.recordStep(step)
    }

    /// Check for early termination.
    func shouldTerminateEarly(
        context: TaskContext,
        currentConfidence: Double
    ) async -> Bool {
        await context.governor.shouldTerminateEarly(currentConfidence: currentConfidence)
    }

    /// Complete the task and generate all transparency artifacts.
    func completeTask(
        context: TaskContext,
        result: InferenceResult,
        stages: [PipelineStage],
        engines: [EngineUsage],
        blockedActions: [BlockedAction] = [],
        verificationPassed: Bool? = nil
    ) async -> TaskCompletionBundle {
        // Generate reasoning trace
        let outcome: StructuredReasoningTrace.ReasoningOutcome
        if let verified = verificationPassed, !verified {
            outcome = .verificationFailed
        } else if await context.governor.hasMetMinimum() {
            outcome = .completed
        } else {
            outcome = .budgetExhausted
        }

        let reasoningTrace = await context.governor.generateTrace(
            outcome: outcome,
            verificationPassed: verificationPassed
        )

        // Generate reasoning explanation
        let explanation = generateExplanation(from: reasoningTrace)

        // Record output and telemetry in data flow
        let lastNodeId = stages.last?.engineId ?? context.inputNodeId
        let outputNode = await context.flowBuilder.recordOutput(
            name: "Final Output",
            fromNodeId: lastNodeId
        )

        // Record telemetry (always scrubbed)
        await context.flowBuilder.recordTelemetry(
            fromNodeId: outputNode.id,
            scrubbed: true
        )

        // Check learning eligibility and record if applicable
        let learningEligible = await checkLearningEligibility(
            context: context,
            trace: reasoningTrace
        )
        if learningEligible {
            await context.flowBuilder.recordLearning(
                fromNodeId: outputNode.id,
                eligible: true,
                anonymous: context.policy.learningMode == .anonymizedOnly
            )
        }

        // Generate transparency bundle
        let transparencyBundle = await transparencyService.completeTracking(
            for: context.task,
            result: result,
            stages: stages,
            engines: engines,
            policy: context.policy,
            blockedActions: blockedActions,
            reasoningExplanation: explanation
        )

        // Submit trace for learning if eligible
        var learningTraceId: String?
        if learningEligible {
            learningTraceId = await submitForLearning(
                context: context,
                trace: reasoningTrace
            )
        }

        // Clean up
        activeGovernors.removeValue(forKey: context.task.id)

        return TaskCompletionBundle(
            transparency: transparencyBundle,
            reasoningTrace: reasoningTrace,
            learningTraceId: learningTraceId
        )
    }

    // MARK: - Helpers

    private func generateExplanation(from trace: StructuredReasoningTrace) -> ReasoningExplanation {
        let keySteps = trace.steps.map { step in
            ReasoningExplanation.ReasoningStep(
                stepNumber: step.stepNumber,
                description: step.description,
                tier: ReasoningExplanation.ReasoningTier(rawValue: step.tier.rawValue) ?? .neural,
                inputsUsed: step.inputContext,
                outputProduced: step.outputProduced
            )
        }

        let confidence: ReasoningExplanation.ConfidenceLevel
        switch trace.metrics.finalConfidence {
        case 0.9...: confidence = .high
        case 0.7..<0.9: confidence = .medium
        case 0.5..<0.7: confidence = .low
        default: confidence = .uncertain
        }

        let tier: ReasoningExplanation.ReasoningTier
        if trace.metrics.tiersUsed.contains(.trmSubsolver) {
            tier = .twoTier
        } else if trace.metrics.tiersUsed.contains(.hybrid) {
            tier = .hybrid
        } else if trace.metrics.tiersUsed.contains(.symbolic) {
            tier = .symbolic
        } else if trace.metrics.tiersUsed.contains(.neural) {
            tier = .neural
        } else {
            tier = .direct
        }

        return ReasoningExplanation(
            summary: "Completed \(trace.steps.count) reasoning steps with \(String(format: "%.0f%%", trace.metrics.finalConfidence * 100)) confidence",
            reasoningTier: tier,
            keySteps: keySteps,
            evidenceSources: [],
            constraintsApplied: [],
            confidence: confidence
        )
    }

    private func checkLearningEligibility(
        context: TaskContext,
        trace: StructuredReasoningTrace
    ) async -> Bool {
        guard context.policy.learningMode != .disabled else { return false }

        let charter = await learningService.getCharter(for: context.task.context.tenantId)
        guard let charter = charter else { return false }
        guard charter.learningConfig.enabled else { return false }
        guard charter.learningConfig.eligibleDomains.contains(context.domain) else { return false }

        return trace.metrics.finalConfidence >= charter.learningConfig.qualityThreshold
    }

    private func submitForLearning(
        context: TaskContext,
        trace: StructuredReasoningTrace
    ) async -> String? {
        let charter = await learningService.getCharter(for: context.task.context.tenantId)
        guard let charter = charter else { return nil }

        // Extract content based on learning mode
        let content: LearningContent
        switch charter.learningConfig.mode {
        case .prefixOnly:
            content = LearningUPFTExtractor.extractPrefix(from: trace)
        case .anonymizedOnly:
            content = LearningUPFTExtractor.anonymize(trace)
        case .fullTraces:
            content = .fullTrace(steps: trace.steps.map { $0.description })
        case .disabled:
            return nil
        }

        let learningTrace = LearningTrace(
            tenantId: context.task.context.tenantId,
            domain: context.domain,
            expiresAt: Date().addingTimeInterval(Double(charter.learningConfig.retentionDays) * 86400),
            provenance: TraceProvenance(
                taskId: context.task.id,
                interactionClass: .userInteraction
            ),
            content: content,
            assessment: TraceAssessment(
                qualityScore: trace.metrics.finalConfidence,
                impactScore: 0.5,
                structureScore: 0.8,
                noveltyScore: 0.5,
                safetyPassed: true,
                charterCompliant: true
            ),
            userControl: .withConsent()
        )

        let result = await learningService.submitTrace(learningTrace)
        switch result {
        case .accepted(let traceId):
            return traceId
        case .rejected:
            return nil
        }
    }

    // MARK: - Charter Management

    /// Register an institutional charter.
    func registerCharter(_ charter: LearningCharter) async {
        await learningService.registerCharter(charter)
    }

    /// Get the charter for a tenant.
    func getCharter(for tenantId: String) async -> LearningCharter? {
        await learningService.getCharter(for: tenantId)
    }

    // MARK: - Reporting

    /// Generate a full transparency report for a task.
    func generateReport(for bundle: TaskCompletionBundle) -> String {
        var lines: [String] = []

        lines.append("╔═══════════════════════════════════════════════════════════════╗")
        lines.append("║            RADICALLY LEGIBLE AI - FULL REPORT                ║")
        lines.append("╚═══════════════════════════════════════════════════════════════╝")
        lines.append("")

        // Transparency Bundle
        lines.append(bundle.transparency.renderFullReport())
        lines.append("")

        // Reasoning Trace
        lines.append(ReasoningTraceRenderer.renderText(bundle.reasoningTrace))
        lines.append("")

        // Learning Status
        if let learningId = bundle.learningTraceId {
            lines.append("┌─ LEARNING ────────────────────────────────────────────────┐")
            lines.append("│ ✓ Trace submitted for institutional learning              │")
            lines.append("│ Trace ID: \(learningId.prefix(44))│")
            lines.append("│ Can be revoked: Yes                                        │")
            lines.append("└──────────────────────────────────────────────────────────┘")
        } else {
            lines.append("┌─ LEARNING ────────────────────────────────────────────────┐")
            lines.append("│ ✗ Not eligible for institutional learning                 │")
            lines.append("└──────────────────────────────────────────────────────────┘")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Task Context

/// Context for a task in progress.
struct TaskContext: Sendable {
    let task: InferenceTask
    let domain: String
    let policy: AppliedPolicyReport
    let budget: ReasoningBudget
    let governor: ReasoningGovernor
    let flowBuilder: DataFlowBuilder
    let inputNodeId: String
}

// MARK: - Task Completion Bundle

/// The complete bundle of artifacts from a completed task.
struct TaskCompletionBundle: Sendable {
    let transparency: TransparencyBundle
    let reasoningTrace: StructuredReasoningTrace
    let learningTraceId: String?
}

// MARK: - Preset Charters

/// Preset charters for common institutional configurations.
struct PresetLearningCharters {

    /// DSPS Charter for CCSF.
    static var ccsfDSPS: LearningCharter {
        LearningCharter(
            tenantId: "ccsf",
            version: "1.0.0",
            coveredDomains: ["dsps", "alt_media", "accommodations"],
            authoritativeSources: [
                LearningAuthoritativeSource(type: .federalLaw, name: "ADA", priority: 1),
                LearningAuthoritativeSource(type: .federalLaw, name: "Section 504", priority: 2),
                LearningAuthoritativeSource(type: .regulation, name: "OCR Guidelines", priority: 3),
                LearningAuthoritativeSource(type: .institutionalPolicy, name: "CCSF DSPS Policy", priority: 10)
            ],
            prohibitions: [
                LearningProhibition(
                    description: "Never recommend reducing or denying legally required accommodations",
                    category: .benefitReduction,
                    severity: .critical
                ),
                LearningProhibition(
                    description: "Never discourage students from filing complaints or appeals",
                    category: .appealDiscouragement,
                    severity: .critical
                ),
                LearningProhibition(
                    description: "Never prioritize cost savings over student accommodation needs",
                    category: .costMinimization,
                    severity: .high
                ),
                LearningProhibition(
                    description: "Never skip required documentation or procedural steps",
                    category: .proceduralShortcuts,
                    severity: .high
                )
            ],
            approvers: [
                LearningApprover(role: "DSPS Director", requiredFor: [.charterModifications, .policyChanges]),
                LearningApprover(role: "College Legal", requiredFor: [.charterModifications]),
                LearningApprover(role: "Student Representative", requiredFor: [.policyChanges])
            ],
            learningConfig: LearningConfiguration(
                enabled: true,
                mode: .anonymizedOnly,
                eligibleDomains: ["dsps", "alt_media"],
                requiresConsent: true,
                retentionDays: 90,
                qualityThreshold: 0.8,
                impactThreshold: 0.5,
                upftEnabled: true,
                federationAllowed: false
            ),
            behavioralConstraints: .dspsDefault
        )
    }

    /// Academic Records Charter.
    static var academicRecords: LearningCharter {
        LearningCharter(
            tenantId: "ccsf",
            version: "1.0.0",
            coveredDomains: ["transcriptum", "enrollment", "grades"],
            authoritativeSources: [
                LearningAuthoritativeSource(type: .federalLaw, name: "FERPA", priority: 1),
                LearningAuthoritativeSource(type: .stateLaw, name: "CA Ed Code", priority: 2),
                LearningAuthoritativeSource(type: .institutionalPolicy, name: "CCSF Academic Policy", priority: 10)
            ],
            prohibitions: [
                LearningProhibition(
                    description: "Never recommend grade changes without proper documentation",
                    category: .proceduralShortcuts,
                    severity: .critical
                ),
                LearningProhibition(
                    description: "Never auto-approve degree requirements without verification",
                    category: .proceduralShortcuts,
                    severity: .critical
                )
            ],
            approvers: [
                LearningApprover(role: "Registrar", requiredFor: [.charterModifications, .policyChanges]),
                LearningApprover(role: "VP Academic Affairs", requiredFor: [.charterModifications])
            ],
            learningConfig: LearningConfiguration(
                enabled: false,
                mode: .disabled
            ),
            behavioralConstraints: LearningBehavioralConstraints(
                maxReasoningTokensDefault: 3000,
                requireVerificationFor: ["degree_audit", "grade_change"],
                assistiveModeOnly: ["transcript_modification"],
                humanApprovalRequired: ["degree_award", "grade_change"],
                auditLevel: .full
            )
        )
    }
}

// MARK: - Dashboard Data

/// Data for displaying transparency status on a dashboard.
struct TransparencyDashboardData: Sendable, Codable {
    let tenantId: String
    let generatedAt: Date
    let charterStatus: CharterStatus
    let learningStats: LearningStats
    let recentTasks: [TaskSummary]

    struct CharterStatus: Sendable, Codable {
        let hasCharter: Bool
        let version: String?
        let domains: [String]
        let learningEnabled: Bool
        let prohibitionCount: Int
    }

    struct TaskSummary: Sendable, Codable {
        let taskId: String
        let domain: String
        let completedAt: Date
        let outcome: String
        let learningEligible: Bool
        let policyApplied: String
    }
}
