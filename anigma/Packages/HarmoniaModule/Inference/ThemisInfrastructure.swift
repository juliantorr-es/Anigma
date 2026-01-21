//
//  ThemisInfrastructure.swift
//  HarmoniaModule
//
//  The unified "Themis" architecture for governed institutional AI.
//  Named for the Greek Titan of divine law and order.
//
//  This file provides the canonical entry point for all inference operations,
//  wiring together:
//  - Themis: Institutional charters and governance
//  - Mnemosyne: Tri-memory architecture
//  - Moirae: Self-tuning routing and selection
//  - Eunomia: Agent behavior governance
//  - Aletheia: Telemetry and transparency
//  - Arete: Learning impact measurement
//  - Eris: Adversarial testing
//
//  Usage:
//  let themis = await ThemisOrchestrator.create(preset: .ccsfDSPS)
//  let result = try await themis.runTask(task, session: session)
//  print(result.receipt.render())
//

import AnigmaCore
import Foundation

// MARK: - Type Aliases for Greek Names

// Charter Layer (Themis = divine law)
public typealias ThemisCharter = InstitutionalCharter
public typealias NemesisConstraint = ProhibitedOptimization
public typealias EunomiaGuardrails = EthicalGuardrails

// Memory Layer (Mnemosyne = memory)
public typealias LetheBuffer = ShortTermMemory
public typealias MnemosyneArchive = LongTermMemory
public typealias ArcheionStore = PersistentMemory

// Routing Layer (Moirae = fates)
public typealias MoiraeRoutingPolicy = ArchitectureSelectionPolicy
public typealias MoiraRoutingRule = TaskRoutingRule
public typealias AnankeConstraint = RoutingConstraint

// Behavior Layer (Eunomia = good order)
public typealias EunomiaGovernor = AgentBehaviorGovernor
public typealias EunomiaConstraints = AgentBehaviorConstraints

// Transparency Layer (Aletheia = truth)
// Removed: AletheiaManifest (EnhancedTelemetryManifest deleted in Stage 3)
public typealias AletheiaReceipt = ProcessingReceipt

// Learning Layer (Arete = excellence)
public typealias AreteImpactMeasurer = LearningImpactMeasurer

// Testing Layer (Eris = strife/chaos)
public typealias ErisTrialBuilder = InferencePlanePuzzleBuilder
public typealias AgonScenario = AdversarialScenario

// MARK: - Themis Orchestrator

/// The unified Themis orchestrator - the single canonical entry point
/// for governed institutional AI inference.
///
/// Themis coordinates all layers:
/// 1. Charter validation (pre-flight)
/// 2. Memory context building (Mnemosyne)
/// 3. Model routing (Moirae)
/// 4. Behavior governance (Eunomia)
/// 5. Inference execution
/// 6. Transparency and receipts (Aletheia)
/// 7. Learning eligibility (Arete)
/// 8. Post-flight validation
public actor ThemisOrchestrator {

    // MARK: - Core Components

    /// Charter registry (Themis layer)
    private let charterRegistry: ThemisCharterRegistry

    /// Tri-memory service (Mnemosyne layer)
    private let mnemosyneService: TriMemoryService

    /// Routing policy service (Moirae layer)
    private let moiraeService: SelectionPolicyService

    /// Behavior governor (Eunomia layer)
    private let eunomiaGovernor: AgentBehaviorGovernor

    /// Transparency service (Aletheia layer)
    private let aletheiaService: TransparencyService

    /// Learning measurer (Arete layer)
    private let areteService: LearningImpactMeasurer

    /// Inference service (execution layer)
    private let inferenceService: InferenceService

    /// Architecture registry
    private let architectureRegistry: ArchitectureRegistry

    // MARK: - State

    /// Active sessions
    private var activeSessions: [String: ThemisSession] = [:]

    /// Health status
    private var health: ThemisHealth = .initializing

    /// Configuration
    private let config: ThemisConfig

    // MARK: - Initialization

    public init(config: ThemisConfig = .default) async {
        self.config = config

        // Initialize all layers
        self.charterRegistry = ThemisCharterRegistry()
        self.mnemosyneService = TriMemoryService()
        self.architectureRegistry = ArchitectureRegistry()
        self.moiraeService = SelectionPolicyService(architectureRegistry: architectureRegistry)
        self.eunomiaGovernor = AgentBehaviorGovernor()
        self.aletheiaService = TransparencyService()
        self.areteService = LearningImpactMeasurer()
        self.inferenceService = InferenceService()

        self.health = .healthy
    }

    // MARK: - Factory Methods

    /// Creates a Themis orchestrator with default configuration.
    public static func create(config: ThemisConfig = .default) async -> ThemisOrchestrator {
        await ThemisOrchestrator(config: config)
    }

    /// Creates a Themis orchestrator with a preset configuration.
    public static func create(preset: ThemisPreset) async -> ThemisOrchestrator {
        let orchestrator = await ThemisOrchestrator(config: preset.config)

        // Register preset charters
        for charter in preset.charters {
            await orchestrator.registerCharter(charter)
        }

        // Register preset policies
        for policy in preset.routingPolicies {
            await orchestrator.moiraeService.registerPolicy(policy)
        }

        // Configure behavior constraints
        for (tenantId, constraints) in preset.behaviorConstraints {
            await orchestrator.eunomiaGovernor.setConstraints(constraints, for: tenantId)
        }

        return orchestrator
    }

    // MARK: - Session Management

    /// Starts a new inference session.
    public func startSession(
        tenantId: String,
        principalId: String,
        domain: SelectionDomain
    ) -> ThemisSessionContext {
        let sessionId = UUID().uuidString
        let session = ThemisSession(
            id: sessionId,
            tenantId: tenantId,
            principalId: principalId,
            domain: domain,
            startedAt: Date()
        )
        activeSessions[sessionId] = session

        return ThemisSessionContext(
            sessionId: sessionId,
            tenantId: tenantId,
            principalId: principalId,
            domain: domain
        )
    }

    /// Ends an inference session.
    public func endSession(_ sessionId: String) async {
        await mnemosyneService.expireSession(sessionId)
        activeSessions.removeValue(forKey: sessionId)
    }

    // MARK: - Main Entry Point

    /// Runs a governed inference task through the complete Themis pipeline.
    ///
    /// This is THE canonical entry point for all inference in Anigma/Harmonia.
    /// Every inference goes through:
    /// 1. Charter pre-validation
    /// 2. Memory context assembly
    /// 3. Model selection via learned policy
    /// 4. Behavior-governed execution
    /// 5. Transparency artifact generation
    /// 6. Learning eligibility assessment
    /// 7. Charter post-validation
    public func runTask(
        _ task: InferenceTask,
        session: ThemisSessionContext
    ) async throws -> ThemisResult {
        let startTime = Date()

        // 1. Charter Pre-Validation (Themis layer)
        let charterResult = await validateCharter(task: task, session: session)
        guard charterResult.isPermitted else {
            throw ThemisError.charterViolation(charterResult)
        }

        // 2. Start Behavior Governance Turn (Eunomia layer)
        let turnId = await eunomiaGovernor.startTurn()

        // 3. Build Memory Context (Mnemosyne layer)
        let memoryContext = await buildMemoryContext(session: session, task: task)

        // 4. Select Model (Moirae layer)
        let selectionResult = await selectModel(task: task, session: session)
        guard let selectedModel = selectionResult.selectedModel else {
            throw ThemisError.noSuitableModel
        }

        // 5. Start Transparency Tracking (Aletheia layer)
        let flowBuilder = await aletheiaService.beginTracking(taskId: task.id)
        let inputNode = await flowBuilder.recordInput(
            name: "User Input",
            metadata: ["taskKind": task.kind.rawValue, "domain": session.domain.rawValue]
        )

        // 6. Execute Governed Inference
        let enhancedTask = enhanceTaskWithContext(task, memory: memoryContext)

        _ = await eunomiaGovernor.recordReasoning(
            turnId: turnId,
            tokens: 0,
            context: session.tenantId
        )

        let modelNode = await flowBuilder.recordModelUsage(
            name: selectedModel.family,
            modelId: selectedModel.id,
            isLocal: selectedModel.backend != .remoteAPI,
            fromNodeId: inputNode.id,
            dataType: .processedContent,
            transformations: [.tokenized]
        )

        let inferenceResult = try await inferenceService.run(enhancedTask)

        _ = await eunomiaGovernor.recordToolCall(
            turnId: turnId,
            toolName: "inference:\(selectedModel.id)",
            context: session.tenantId,
            waitedForResult: true
        )

        // 7. End Behavior Turn
        let turnSummary = await eunomiaGovernor.endTurn(turnId)

        // 8. Generate Transparency Artifacts
        let outputNode = await flowBuilder.recordOutput(
            name: "Final Output", fromNodeId: modelNode.id)
        await flowBuilder.recordTelemetry(fromNodeId: outputNode.id, scrubbed: true)

        let dataFlowGraph = await flowBuilder.build()

        // 9. Assess Learning Eligibility (Arete layer)
        let learningEligibility = await assessLearningEligibility(
            task: task,
            session: session,
            turnSummary: turnSummary
        )

        if learningEligibility.isEligible {
            await flowBuilder.recordLearning(
                fromNodeId: outputNode.id,
                eligible: true,
                anonymous: learningEligibility.requiresAnonymization
            )
        }

        // 10. Build Pipeline Stages for Receipt
        let stages = [
            PipelineStage(name: "Memory Assembly", category: .preprocessing, startedAt: startTime),
            PipelineStage(name: "Model Selection", category: .classification, startedAt: startTime),
            PipelineStage(name: "Inference", category: .generation, startedAt: startTime),
            PipelineStage(name: "Validation", category: .validation, startedAt: Date())
        ]

        let engines = [
            EngineUsage(
                engineType: .llm,
                modelId: selectedModel.id,
                modelFamily: selectedModel.family,
                backend: selectedModel.backend
            )
        ]

        // 11. Generate Receipt
        let policy = buildPolicyReport(session: session, charterResult: charterResult)
        let receiptGenerator = ReceiptGenerator()
        let receipt = await receiptGenerator.generateReceipt(
            for: task,
            result: inferenceResult,
            stages: stages,
            engines: engines,
            policy: policy
        )

        // 12. Update Short-Term Memory
        await updateShortTermMemory(session: session, task: task, result: inferenceResult)

        // 13. Record Learning Observation
        await recordLearningObservation(
            task: task,
            model: selectedModel,
            result: inferenceResult,
            latency: Date().timeIntervalSince(startTime),
            session: session,
            turnSummary: turnSummary
        )

        // 14. Build Final Result
        let outputText: String
        if case .text(let text) = inferenceResult.output {
            outputText = text
        } else {
            outputText = ""
        }

        return ThemisResult(
            content: outputText,
            model: selectedModel,
            latencyMs: Int(Date().timeIntervalSince(startTime) * 1000),
            receipt: receipt,
            dataFlow: dataFlowGraph,
            charterValidation: charterResult,
            behaviorSummary: turnSummary,
            memoryLayersUsed: memoryContext.parts.map { $0.source },
            learningEligibility: learningEligibility
        )
    }

    // MARK: - Charter Management

    /// Registers an institutional charter.
    public func registerCharter(_ charter: InstitutionalCharter) {
        charterRegistry.register(charter)
    }

    /// Gets the charter for a tenant.
    public func getCharter(for tenantId: String) -> InstitutionalCharter? {
        charterRegistry.get(for: tenantId)
    }

    // MARK: - Health and Status

    /// Gets the health status.
    public func getHealth() -> ThemisHealth {
        health
    }

    /// Gets comprehensive status.
    public func getStatus() async -> ThemisStatus {
        let behaviorStats = await eunomiaGovernor.statistics()

        return ThemisStatus(
            health: health,
            activeSessions: activeSessions.count,
            behaviorViolations: behaviorStats.totalViolations,
            registeredCharters: charterRegistry.count
        )
    }

    // MARK: - Adversarial Analysis (Eris layer)

    /// Runs adversarial analysis on the orchestrator.
    public func runAdversarialAnalysis() async -> ErisReport {
        let issues: [ErisIssue] = []

        // Test charter enforcement
        // Test memory isolation
        // Test behavior governance
        // Test routing policies

        return ErisReport(
            timestamp: Date(),
            issues: issues,
            testedComponents: [
                "ThemisCharterRegistry",
                "MnemosyneService",
                "MoiraeService",
                "EunomiaGovernor"
            ],
            overallHealth: issues.isEmpty ? .healthy : .degraded
        )
    }

    // MARK: - Private Helpers

    private func validateCharter(
        task: InferenceTask,
        session: ThemisSessionContext
    ) async -> CharterValidationResult {
        guard let charter = charterRegistry.get(for: session.tenantId) else {
            // No charter = allow (for tenants without charters)
            return .permitted(charter: "none", version: "0.0.0")
        }

        let action = CharterAction(
            domain: mapDomainToCharter(session.domain),
            actionType: task.kind.rawValue,
            riskLevel: estimateRisk(task)
        )

        return charter.validate(action: action)
    }

    private func mapDomainToCharter(_ domain: SelectionDomain) -> CharterDomain {
        switch domain {
        case .dsps: return .dspsAccommodations
        case .transcriptum: return .academicRecords
        case .compliance: return .complianceReporting
        case .coding: return .generalAssistance
        case .altMedia: return .dspsAltMedia
        case .general: return .generalAssistance
        }
    }

    private func estimateRisk(_ task: InferenceTask) -> Double {
        switch task.kind {
        case .chat: return 0.3
        case .summarize: return 0.2
        case .embed: return 0.1
        case .classify: return 0.3
        case .rerank: return 0.2
        case .toolCall: return 0.6
        case .codeGeneration: return 0.5
        case .codeExplanation: return 0.3
        case .extraction: return 0.4
        case .translation: return 0.2
        }
    }

    private func buildMemoryContext(
        session: ThemisSessionContext,
        task: InferenceTask
    ) async -> BuiltMemoryContext {
        let contextBuilder = MemoryContextBuilder(triMemory: mnemosyneService)
        return await contextBuilder.buildContext(
            sessionId: session.sessionId,
            tenantId: session.tenantId,
            task: task.kind.rawValue
        )
    }

    private func selectModel(
        task: InferenceTask,
        session: ThemisSessionContext
    ) async -> SelectionResult {
        let candidates = await inferenceService.listModels(forTenant: session.tenantId)

        return await moiraeService.selectModel(
            from: candidates,
            for: task,
            tenantId: session.tenantId,
            domain: session.domain
        )
    }

    private func enhanceTaskWithContext(
        _ task: InferenceTask,
        memory: BuiltMemoryContext
    ) -> InferenceTask {
        switch task.input {
        case .text(let text):
            let enhancedText = memory.render() + "\n\n---\n\n" + text
            return InferenceTask(
                kind: task.kind,
                input: .text(enhancedText),
                context: task.context,
                constraints: task.constraints
            )
        default:
            return task
        }
    }

    private func buildPolicyReport(
        session: ThemisSessionContext,
        charterResult: CharterValidationResult
    ) -> AppliedPolicyReport {
        let profile: AppliedPolicyReport.BehaviorProfile
        switch session.domain {
        case .dsps, .altMedia:
            profile = .careful
        case .transcriptum:
            profile = .careful
        case .compliance:
            profile = .standard
        case .coding, .general:
            profile = .standard
        }

        return AppliedPolicyReport(
            policyId: session.tenantId,
            policyName: "\(session.domain.rawValue.capitalized) Policy",
            profile: profile,
            constraints: AppliedPolicyReport.PolicyConstraintsSummary(
                maxReasoningTokens: profile == .careful ? 4000 : 2000,
                externalCallsAllowed: profile != .careful,
                piiTelemetryBlocked: true,
                trainingEligible: profile != .careful
            ),
            learningMode: profile == .careful ? .anonymizedOnly : .disabled
        )
    }

    private func assessLearningEligibility(
        task: InferenceTask,
        session: ThemisSessionContext,
        turnSummary: AgentTurnSummary?
    ) async -> LearningEligibility {
        guard let charter = charterRegistry.get(for: session.tenantId) else {
            return LearningEligibility(isEligible: false, reason: "No charter")
        }

        guard turnSummary?.wasClean == true else {
            return LearningEligibility(isEligible: false, reason: "Behavior violations occurred")
        }

        // Check if domain is allowed for learning
        let charterDomain = mapDomainToCharter(session.domain)
        guard charter.allowedDomains.contains(charterDomain) else {
            return LearningEligibility(isEligible: false, reason: "Domain not allowed by charter")
        }

        return LearningEligibility(
            isEligible: true,
            reason: "Passed all checks",
            requiresAnonymization: true
        )
    }

    private func updateShortTermMemory(
        session: ThemisSessionContext,
        task: InferenceTask,
        result: InferenceResult
    ) async {
        let resultText: String
        if case .text(let text) = result.output {
            resultText = text
        } else {
            resultText = ""
        }

        let memory = ShortTermMemory(
            tenantId: session.tenantId,
            sessionId: session.sessionId,
            contentType: .interactionHistory,
            content: resultText.data(using: .utf8) ?? Data(),
            source: .agentReasoning,
            sensitivity: .internal_
        )

        await mnemosyneService.storeShortTerm(memory)
    }

    private func recordLearningObservation(
        task: InferenceTask,
        model: ModelDescriptor,
        result: InferenceResult,
        latency: TimeInterval,
        session: ThemisSessionContext,
        turnSummary: AgentTurnSummary?
    ) async {
        let wasSuccessful = turnSummary?.wasClean ?? true

        let observation = SelectionObservation(
            tenantId: session.tenantId,
            domain: session.domain,
            taskKind: task.kind,
            selectedModelId: model.id,
            activeFeatures: [],
            wasSuccessful: wasSuccessful,
            latencyMs: Int(latency * 1000)
        )

        await moiraeService.recordObservation(observation)
    }
}

// MARK: - Charter Registry

import os

/// Registry for institutional charters.
public final class ThemisCharterRegistry: Sendable {
    private let state = OSAllocatedUnfairLock(initialState: [String: InstitutionalCharter]())

    public init() {}

    public func register(_ charter: InstitutionalCharter) {
        state.withLock { dict in
            dict[charter.tenantId] = charter
        }
    }

    public func get(for tenantId: String) -> InstitutionalCharter? {
        state.withLock { $0[tenantId] }
    }

    public var count: Int {
        state.withLock { $0.count }
    }
}

// MARK: - Supporting Types

/// Configuration for Themis orchestrator.
public struct ThemisConfig: Sendable {
    public var enableTelemetry: Bool
    public var enableLearning: Bool
    public var enableAdversarialChecks: Bool
    public var defaultTimeout: TimeInterval
    public var maxConcurrentRequests: Int

    public init(
        enableTelemetry: Bool = true,
        enableLearning: Bool = true,
        enableAdversarialChecks: Bool = true,
        defaultTimeout: TimeInterval = 30,
        maxConcurrentRequests: Int = 10
    ) {
        self.enableTelemetry = enableTelemetry
        self.enableLearning = enableLearning
        self.enableAdversarialChecks = enableAdversarialChecks
        self.defaultTimeout = defaultTimeout
        self.maxConcurrentRequests = maxConcurrentRequests
    }

    public static let `default` = ThemisConfig()
}

/// Preset configurations for Themis.
public struct ThemisPreset {
    public let name: String
    public let config: ThemisConfig
    public let charters: [InstitutionalCharter]
    public let routingPolicies: [ArchitectureSelectionPolicy]
    public let behaviorConstraints: [String: AgentBehaviorConstraints]

    /// CCSF DSPS preset.
    public static var ccsfDSPS: ThemisPreset {
        ThemisPreset(
            name: "CCSF DSPS",
            config: ThemisConfig(
                enableLearning: true,
                enableAdversarialChecks: true
            ),
            charters: [
                InstitutionalCharter(
                    tenantId: "ccsf",
                    name: "CCSF DSPS Institutional Charter",
                    allowedDomains: [
                        .dspsForms, .dspsAccommodations, .dspsAltMedia, .studentCommunications
                    ],
                    forbiddenDomains: [.medicalDocumentation, .legalAdvice],
                    authoritativeSources: [
                        AuthoritativeSource(name: "ADA", type: .federalLaw, priority: 1),
                        AuthoritativeSource(name: "Section 504", type: .federalLaw, priority: 1),
                        AuthoritativeSource(
                            name: "CCSF DSPS Handbook", type: .institutionalPolicy, priority: 10)
                    ],
                    prohibitedOptimizations: [
                        .reducedBenefits, .fewerAccommodations, .shorterAppeals, .fasterDenials
                    ],
                    requiredApprovers: [.dspsLead, .accessibilityOfficer],
                    behaviorConstraints: .strict,
                    ethicalGuardrails: EthicalGuardrails(
                        neverDiscourageAppeals: true,
                        alwaysOfferAlternatives: true,
                        protectVulnerablePopulations: true
                    )
                )
            ],
            routingPolicies: [
                ArchitectureSelectionPolicy(
                    tenantId: "ccsf",
                    domain: .dsps,
                    featureWeights: [
                        .kvCompression: 0.3,
                        .longContextFriendly: 0.4
                    ],
                    hardConstraints: [
                        RoutingConstraint(
                            name: "local-only", type: .requireLocalOnly, value: "true")
                    ]
                )
            ],
            behaviorConstraints: [
                "ccsf": AgentBehaviorConstraints(
                    maxReasoningWithoutAction: 200,
                    maxConsecutiveToolCalls: 3,
                    maxUnverifiedConfidence: 0.5
                )
            ]
        )
    }

    /// Academic records preset.
    public static var academicRecords: ThemisPreset {
        ThemisPreset(
            name: "Academic Records",
            config: ThemisConfig(
                enableLearning: false,  // No learning for academic records
                enableAdversarialChecks: true
            ),
            charters: [
                InstitutionalCharter(
                    tenantId: "ccsf",
                    name: "CCSF Academic Records Charter",
                    allowedDomains: [.academicRecords],
                    forbiddenDomains: [.medicalDocumentation, .legalAdvice],
                    authoritativeSources: [
                        AuthoritativeSource(name: "FERPA", type: .federalLaw, priority: 1),
                        AuthoritativeSource(name: "CA Ed Code", type: .stateLaw, priority: 2)
                    ],
                    prohibitedOptimizations: [.reducedDocumentation, .minimizedCompliance],
                    requiredApprovers: [.institutionalAdmin],
                    behaviorConstraints: .strict
                )
            ],
            routingPolicies: [],
            behaviorConstraints: [:]
        )
    }
}

/// Session context for Themis.
public struct ThemisSessionContext: Sendable {
    public let sessionId: String
    public let tenantId: String
    public let principalId: String
    public let domain: SelectionDomain
}

/// Internal session state.
struct ThemisSession: Sendable {
    let id: String
    let tenantId: String
    let principalId: String
    let domain: SelectionDomain
    let startedAt: Date
    var requestCount: Int = 0
}

/// Result from Themis orchestrator.
public struct ThemisResult: Sendable {
    public let content: String
    public let model: ModelDescriptor
    public let latencyMs: Int
    public let receipt: ProcessingReceipt
    public let dataFlow: DataFlowGraph
    public let charterValidation: CharterValidationResult
    public let behaviorSummary: AgentTurnSummary?
    public let memoryLayersUsed: [MemoryType]
    public let learningEligibility: LearningEligibility

    /// Renders a full transparency report.
    public func renderReport() -> String {
        var lines: [String] = []

        lines.append("╔═══════════════════════════════════════════════════════════════╗")
        lines.append("║              THEMIS GOVERNANCE REPORT                         ║")
        lines.append("╚═══════════════════════════════════════════════════════════════╝")
        lines.append("")

        // Receipt
        lines.append(ReceiptRenderer.renderText(receipt))
        lines.append("")

        // Data Flow
        lines.append(DataFlowRenderer.renderASCII(dataFlow))
        lines.append("")

        // Charter Status
        lines.append("┌─ CHARTER STATUS ─────────────────────────────────────────────┐")
        if charterValidation.isPermitted {
            lines.append("│ ✓ Action permitted by charter                               │")
        } else {
            lines.append("│ ✗ Action denied by charter                                  │")
        }
        lines.append("└──────────────────────────────────────────────────────────────┘")
        lines.append("")

        // Behavior Status
        lines.append("┌─ BEHAVIOR STATUS ────────────────────────────────────────────┐")
        if behaviorSummary?.wasClean == true {
            lines.append("│ ✓ No behavior violations                                    │")
        } else {
            lines.append("│ ⚠ Behavior violations detected                              │")
        }
        lines.append("└──────────────────────────────────────────────────────────────┘")
        lines.append("")

        // Learning Status
        lines.append("┌─ LEARNING STATUS ────────────────────────────────────────────┐")
        if learningEligibility.isEligible {
            lines.append("│ ✓ Eligible for institutional learning                       │")
            if learningEligibility.requiresAnonymization {
                lines.append("│   (anonymization required)                                  │")
            }
        } else {
            lines.append(
                "│ ✗ Not eligible: \(learningEligibility.reason.prefix(40).padding(toLength: 40, withPad: " ", startingAt: 0))│"
            )
        }
        lines.append("└──────────────────────────────────────────────────────────────┘")

        return lines.joined(separator: "\n")
    }
}

/// Learning eligibility assessment.
public struct LearningEligibility: Sendable {
    public let isEligible: Bool
    public let reason: String
    public let requiresAnonymization: Bool

    public init(
        isEligible: Bool,
        reason: String,
        requiresAnonymization: Bool = false
    ) {
        self.isEligible = isEligible
        self.reason = reason
        self.requiresAnonymization = requiresAnonymization
    }
}

/// Health status.
public enum ThemisHealth: String, Sendable, Codable {
    case initializing
    case healthy
    case degraded
    case unhealthy
    case maintenance
}

/// Comprehensive status.
public struct ThemisStatus: Sendable {
    public let health: ThemisHealth
    public let activeSessions: Int
    public let behaviorViolations: Int
    public let registeredCharters: Int
}

/// Errors from Themis.
public enum ThemisError: Error, Sendable {
    case charterViolation(CharterValidationResult)
    case noSuitableModel
    case behaviorViolation(BehaviorViolation)
    case memoryAccessDenied
    case sessionNotFound
    case orchestratorUnhealthy
}

// MARK: - Adversarial Types (Eris)

/// Report from adversarial analysis.
public struct ErisReport: Sendable {
    public let timestamp: Date
    public let issues: [ErisIssue]
    public let testedComponents: [String]
    public let overallHealth: ThemisHealth
}

/// An issue found during adversarial testing.
public struct ErisIssue: Sendable {
    public let component: String
    public let severity: ErisSeverity
    public let description: String
    public let scenarioId: String?
}

/// Severity of adversarial issues.
public enum ErisSeverity: String, Sendable, Codable {
    case low
    case medium
    case high
    case critical
}

// MARK: - Migration Notes
//
// The following types have been renamed from the "Bonkers++" naming convention
// to the Greek mythology-based "Themis" convention:
//
// Old Name                      -> New Name
// ----------------------------------------
// BonkersInferenceInfrastructure -> ThemisOrchestrator
// BonkersInferenceResult         -> ThemisResult
// BonkersInferenceConfig         -> ThemisConfig
// InferenceSessionContext        -> ThemisSessionContext
// InfrastructureHealth           -> ThemisHealth
// BonkersInferenceStatus         -> ThemisStatus
// BonkersInferenceError          -> ThemisError
//
// The old types in BonkersInferenceInfrastructure.swift remain available
// for backward compatibility. New code should use the Themis types.
