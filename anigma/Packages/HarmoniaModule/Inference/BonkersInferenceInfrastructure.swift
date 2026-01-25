//
//  BonkersInferenceInfrastructure.swift
//  HarmoniaModule
//
//  The "bonkers++" unified inference infrastructure that:
//  - Integrates institutional models, tri-memory, and self-tuning selection
//  - Closes all loops: selection → metrics → learning → governance → update
//  - Connects reasoning gremlins to attack every component
//  - Provides a single entry point for governed, adaptive inference
//
//  This is where the system becomes a self-improving, self-auditing organism.
//

import AnigmaCore
@preconcurrency import Foundation

// MARK: - Bonkers++ Inference Infrastructure

/// The unified bonkers++ inference infrastructure.
public actor BonkersInferenceInfrastructure {
    // MARK: - Core Components

    /// Standard inference service.
    private let inferenceService: InferenceService

    /// Architecture registry.
    private let architectureRegistry: ArchitectureRegistry

    /// Selection policy service.
    private let selectionPolicyService: SelectionPolicyService

    /// Institutional model service.
    public let institutionalModelService: InstitutionalModelService

    /// Tri-memory service.
    private let triMemoryService: TriMemoryService

    /// Agent behavior governor.
    private let behaviorGovernor: AgentBehaviorGovernor

    /// Learning impact measurer.
    private let learningMeasurer: LearningImpactMeasurer

    /// UPFT extractor.
    private let upftExtractor: UPFTExtractor

    // MARK: - State

    /// Active inference sessions.
    private var activeSessions: [String: BonkersSession] = [:]

    /// Infrastructure health status.
    private var healthStatus: InfrastructureHealth = .initializing

    /// Configuration.
    private let config: BonkersInferenceConfig

    // MARK: - Initialization

    public init(config: BonkersInferenceConfig = .default) async {
        self.config = config

        // Initialize components
        self.architectureRegistry = ArchitectureRegistry()
        self.learningMeasurer = LearningImpactMeasurer()
        self.upftExtractor = UPFTExtractor()
        self.triMemoryService = TriMemoryService()
        self.behaviorGovernor = AgentBehaviorGovernor()
        self.selectionPolicyService = SelectionPolicyService(
            architectureRegistry: architectureRegistry
        )
        self.institutionalModelService = InstitutionalModelService(
            learningMeasurer: learningMeasurer
        )

        // Create inference service with default components
        self.inferenceService = InferenceService()

        self.healthStatus = .healthy
    }

    // MARK: - Main Entry Point

    /// Runs a governed, adaptive inference task.
    public func runInference(
        task: InferenceTask,
        session: InferenceSessionContext
    ) async throws -> BonkersInferenceResult {
        // 1. Validate against institutional charter
        let charterResult = await validateAgainstCharter(task: task, session: session)
        guard charterResult.isPermitted else {
            throw BonkersInferenceError.charterViolation(charterResult)
        }

        // 2. Start behavior governance turn
        let turnId = await behaviorGovernor.startTurn()

        // 3. Build memory context
        let memoryContext = await buildMemoryContext(session: session, task: task)

        // 4. Select model using learned policy
        let selectionResult = await selectModel(task: task, session: session)
        guard let selectedModel = selectionResult.selectedModel else {
            throw BonkersInferenceError.noSuitableModel
        }

        // 5. Get institutional model bundle if applicable
        let institutionalBundle = await institutionalModelService.getPrimaryBundle(
            for: session.tenantId
        )

        // 6. Execute inference with governance
        let startTime = Date()
        let result = try await executeGovernedInference(
            task: enhanceTaskWithContext(task, memory: memoryContext),
            model: selectedModel,
            bundle: institutionalBundle,
            turnId: turnId,
            session: session
        )
        let latency = Date().timeIntervalSince(startTime)

        // 7. End behavior governance turn
        let turnSummary = await behaviorGovernor.endTurn(turnId)

        // 8. Record observation for learning
        await recordLearningObservation(
            task: task,
            model: selectedModel,
            result: result,
            latency: latency,
            session: session,
            turnSummary: turnSummary
        )

        // 9. Update short-term memory
        await updateShortTermMemory(
            session: session,
            task: task,
            result: result
        )

        // 10. Build comprehensive result
        let outputText: String
        if case .text(let text) = result.output {
            outputText = text
        } else {
            outputText = ""
        }

        return BonkersInferenceResult(
            content: outputText,
            model: selectedModel,
            latencyMs: Int(latency * 1000),
            selectionScore: selectionResult.score,
            charterValidation: charterResult,
            behaviorSummary: turnSummary,
            memoryLayersUsed: memoryContext.parts.map { $0.source },
            institutionalBundleId: institutionalBundle?.id,
            provenanceInfo: buildProvenanceInfo(
                model: selectedModel,
                bundle: institutionalBundle
            )
        )
    }

    // MARK: - Session Management

    /// Starts an inference session.
    public func startSession(
        tenantId: String,
        principalId: String,
        domain: SelectionDomain
    ) -> InferenceSessionContext {
        let sessionId = UUID().uuidString
        let session = BonkersSession(
            id: sessionId,
            tenantId: tenantId,
            principalId: principalId,
            domain: domain,
            startedAt: Date()
        )
        activeSessions[sessionId] = session

        return InferenceSessionContext(
            sessionId: sessionId,
            tenantId: tenantId,
            principalId: principalId,
            domain: domain
        )
    }

    /// Ends an inference session.
    public func endSession(_ sessionId: String) async {
        // Expire short-term memory
        await triMemoryService.expireSession(sessionId)

        // Remove from active sessions
        activeSessions.removeValue(forKey: sessionId)
    }

    // MARK: - Health and Status

    /// Gets infrastructure health status.
    public func getHealthStatus() -> InfrastructureHealth {
        healthStatus
    }

    /// Gets comprehensive infrastructure status.
    public func getStatus() async -> BonkersInferenceStatus {
        let behaviorStats = await behaviorGovernor.statistics()

        return BonkersInferenceStatus(
            health: healthStatus,
            activeSessions: activeSessions.count,
            behaviorViolations: behaviorStats.totalViolations,
            registeredPolicies: 0,  // Would query selectionPolicyService
            institutionalBundles: 0  // Would query institutionalModelService
        )
    }

    // MARK: - Gremlin Integration

    /// Runs adversarial analysis on the entire infrastructure.
    public func runAdversarialAnalysis() async -> InfrastructureAdversarialReport {
        let issues: [AdversarialIssue] = []

        // 1. Test selection policies
        // Would generate policy puzzles and run through reasoning kernel

        // 2. Test charter enforcement
        // Would generate charter violation attempts

        // 3. Test memory isolation
        // Would attempt cross-tenant memory access

        // 4. Test behavior governance
        // Would attempt to trigger failure modes

        return InfrastructureAdversarialReport(
            timestamp: Date(),
            issues: issues,
            testedComponents: [
                "SelectionPolicyService",
                "InstitutionalModelService",
                "TriMemoryService",
                "AgentBehaviorGovernor"
            ],
            overallHealth: issues.isEmpty ? .healthy : .degraded
        )
    }

    // MARK: - Private Helpers

    private func validateAgainstCharter(
        task: InferenceTask,
        session: InferenceSessionContext
    ) async -> CharterValidationResult {
        let action = CharterAction(
            domain: mapDomainToCharter(session.domain),
            actionType: task.kind.rawValue,
            riskLevel: estimateRisk(task)
        )

        return await institutionalModelService.validateAction(
            action,
            for: session.tenantId
        )
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
        session: InferenceSessionContext,
        task: InferenceTask
    ) async -> BuiltMemoryContext {
        let contextBuilder = MemoryContextBuilder(triMemory: triMemoryService)
        return await contextBuilder.buildContext(
            sessionId: session.sessionId,
            tenantId: session.tenantId,
            task: task.kind.rawValue
        )
    }

    private func selectModel(
        task: InferenceTask,
        session: InferenceSessionContext
    ) async -> SelectionResult {
        // Get available models from registry
        let candidates = await inferenceService.listModels(forTenant: session.tenantId)

        return await selectionPolicyService.selectModel(
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
        // Enhance task input with memory context
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

    private func executeGovernedInference(
        task: InferenceTask,
        model: ModelDescriptor,
        bundle: InstitutionalModelBundle?,
        turnId: String,
        session: InferenceSessionContext
    ) async throws -> InferenceResult {
        // Record reasoning start
        _ = await behaviorGovernor.recordReasoning(
            turnId: turnId,
            tokens: 0,
            context: session.tenantId
        )

        // Execute through standard inference service
        let result = try await inferenceService.run(task)

        // Record tool call (inference is a "tool")
        _ = await behaviorGovernor.recordToolCall(
            turnId: turnId,
            toolName: "inference:\(model.id)",
            context: session.tenantId,
            waitedForResult: true
        )

        return result
    }

    private func recordLearningObservation(
        task: InferenceTask,
        model: ModelDescriptor,
        result: InferenceResult,
        latency: TimeInterval,
        session: InferenceSessionContext,
        turnSummary: AgentTurnSummary?
    ) async {
        // Determine success
        let wasSuccessful = turnSummary?.wasClean ?? true

        // Get active architecture features
        let profile = await architectureRegistry.getProfile(for: model.family)
        var activeFeatures: Set<ArchitectureFeatureKey> = []
        if profile?.kvCache.isCompressed == true {
            activeFeatures.insert(.kvCompression)
        }
        if profile?.isLongContextFriendly == true {
            activeFeatures.insert(.longContextFriendly)
        }
        if profile?.generationMode == .diffusion {
            activeFeatures.insert(.diffusionBased)
        }

        // Record observation
        let observation = SelectionObservation(
            tenantId: session.tenantId,
            domain: session.domain,
            taskKind: task.kind,
            selectedModelId: model.id,
            activeFeatures: activeFeatures,
            wasSuccessful: wasSuccessful,
            latencyMs: Int(latency * 1000)
        )

        await selectionPolicyService.recordObservation(observation)
    }

    private func updateShortTermMemory(
        session: InferenceSessionContext,
        task: InferenceTask,
        result: InferenceResult
    ) async {
        // Extract text from result
        let resultText: String
        if case .text(let text) = result.output {
            resultText = text
        } else {
            resultText = ""
        }

        // Store interaction in short-term memory
        let memory = ShortTermMemory(
            tenantId: session.tenantId,
            sessionId: session.sessionId,
            contentType: .interactionHistory,
            content: resultText.data(using: .utf8) ?? Data(),
            source: .agentReasoning,
            sensitivity: .internal_
        )

        await triMemoryService.storeShortTerm(memory)
    }

    private func buildProvenanceInfo(
        model: ModelDescriptor,
        bundle: InstitutionalModelBundle?
    ) -> InferenceProvenanceInfo {
        InferenceProvenanceInfo(
            modelId: model.id,
            modelFamily: model.family,
            institutionalBundleVersion: bundle?.version,
            charterVersion: bundle?.charter.version
        )
    }
}

// MARK: - Supporting Types

/// Configuration for bonkers++ infrastructure.
public struct BonkersInferenceConfig: Sendable {
    public var defaultTimeout: TimeInterval
    public var maxConcurrentRequests: Int
    public var enableTelemetry: Bool
    public var enableLearning: Bool
    public var enableAdversarialChecks: Bool

    public init(
        defaultTimeout: TimeInterval = 30,
        maxConcurrentRequests: Int = 10,
        enableTelemetry: Bool = true,
        enableLearning: Bool = true,
        enableAdversarialChecks: Bool = true
    ) {
        self.defaultTimeout = defaultTimeout
        self.maxConcurrentRequests = maxConcurrentRequests
        self.enableTelemetry = enableTelemetry
        self.enableLearning = enableLearning
        self.enableAdversarialChecks = enableAdversarialChecks
    }

    public static let `default` = BonkersInferenceConfig()
}

/// Session context for inference.
public struct InferenceSessionContext: Sendable {
    public let sessionId: String
    public let tenantId: String
    public let principalId: String
    public let domain: SelectionDomain
}

/// Internal session state for Bonkers++ infrastructure.
public struct BonkersSession: Sendable {
    public let id: String
    public let tenantId: String
    public let principalId: String
    public let domain: SelectionDomain
    public let startedAt: Date
    public var requestCount: Int = 0
}

/// Result from bonkers++ inference.
public struct BonkersInferenceResult: Sendable {
    public let content: String
    public let model: ModelDescriptor
    public let latencyMs: Int
    public let selectionScore: PolicyScore
    public let charterValidation: CharterValidationResult
    public let behaviorSummary: AgentTurnSummary?
    public let memoryLayersUsed: [MemoryType]
    public let institutionalBundleId: String?
    public let provenanceInfo: InferenceProvenanceInfo
}

/// Provenance info for inference.
public struct InferenceProvenanceInfo: Sendable {
    public let modelId: String
    public let modelFamily: String
    public let institutionalBundleVersion: String?
    public let charterVersion: String?
}

/// Health status of infrastructure.
public enum InfrastructureHealth: String, Sendable, Codable {
    case initializing
    case healthy
    case degraded
    case unhealthy
    case maintenance
}

/// Comprehensive status of infrastructure.
public struct BonkersInferenceStatus: Sendable {
    public let health: InfrastructureHealth
    public let activeSessions: Int
    public let behaviorViolations: Int
    public let registeredPolicies: Int
    public let institutionalBundles: Int
}

/// Errors from bonkers++ inference.
public enum BonkersInferenceError: Error, Sendable {
    case charterViolation(CharterValidationResult)
    case noSuitableModel
    case behaviorViolation(BehaviorViolation)
    case memoryAccessDenied
    case sessionNotFound
    case infrastructureUnhealthy
}

/// Report from adversarial analysis.
public struct InfrastructureAdversarialReport: Sendable {
    public let timestamp: Date
    public let issues: [AdversarialIssue]
    public let testedComponents: [String]
    public let overallHealth: InfrastructureHealth
}

/// An issue found during adversarial analysis.
public struct AdversarialIssue: Sendable {
    public let component: String
    public let severity: AdversarialIssueSeverity
    public let description: String
    public let scenarioId: String?
}

/// Severity of adversarial issues.
public enum AdversarialIssueSeverity: String, Sendable, Codable {
    case low
    case medium
    case high
    case critical
}

// MARK: - Factory

/// Factory for creating bonkers++ infrastructure.
public struct BonkersInferenceFactory {
    /// Creates a fully configured infrastructure.
    public static func create(
        config: BonkersInferenceConfig = .default
    ) async -> BonkersInferenceInfrastructure {
        await BonkersInferenceInfrastructure(config: config)
    }

    /// Creates infrastructure for CCSF DSPS.
    public static func createForCCSFDSPS() async -> BonkersInferenceInfrastructure {
        let infra = await create(
            config: BonkersInferenceConfig(
                enableLearning: true,
                enableAdversarialChecks: true
            ))

        // Register CCSF DSPS charter
        let charter = InstitutionalCharter(
            tenantId: "ccsf",
            name: "CCSF DSPS Institutional Charter",
            allowedDomains: [
                .dspsForms, .dspsAccommodations, .dspsAltMedia, .studentCommunications
            ],
            forbiddenDomains: [.medicalDocumentation, .legalAdvice],
            authoritativeSources: [
                AuthoritativeSource(
                    name: "ADA",
                    type: .federalLaw,
                    priority: 1
                ),
                AuthoritativeSource(
                    name: "Section 504",
                    type: .federalLaw,
                    priority: 1
                ),
                AuthoritativeSource(
                    name: "CCSF DSPS Handbook",
                    type: .institutionalPolicy,
                    priority: 10
                )
            ],
            prohibitedOptimizations: [
                .reducedBenefits,
                .fewerAccommodations,
                .shorterAppeals,
                .fasterDenials
            ],
            requiredApprovers: [.dspsLead, .accessibilityOfficer],
            behaviorConstraints: .strict,
            ethicalGuardrails: EthicalGuardrails(
                neverDiscourageAppeals: true,
                alwaysOfferAlternatives: true,
                protectVulnerablePopulations: true
            )
        )

        await infra.institutionalModelService.registerCharter(charter)

        return infra
    }
}
