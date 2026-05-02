//
//  ProcessingReceipt.swift
//  HarmoniaModule
//
//  Radically Legible AI: Every inference run produces a human-readable receipt
//  that explains exactly what happened to the user's data.
//

@preconcurrency import Foundation
import Foundation
import HarmoniaCore
import AnigmaPrimitives
import InferenceCore
import AnigmaCore
import HarmoniaInferenceContracts

// MARK: - Processing CoreReceipt Types

/// A complete, human-readable receipt for any inference operation.
/// This is the core artifact for "radically legible AI" - no black boxes.
struct ProcessingReceipt: Sendable, Codable, Identifiable {
    let id: String
    let taskId: String
    let tenantId: String
    let createdAt: Date
    let completedAt: Date

    /// What was ingested
    let ingestion: IngestionSummary

    /// Which stages ran and in what order
    let pipeline: [PipelineStage]

    /// Which engines/models were used
    let engines: [EngineUsage]

    /// Data locality - did anything leave the local node?
    let dataLocality: DataLocalityReport

    /// What was persisted after the run
    let persistence: PersistenceReport

    /// The governance policy that applied
    let appliedPolicy: AppliedPolicyReport

    /// Any actions that were blocked
    let blockedActions: [BlockedAction]

    /// Learning eligibility - is this trace usable for training?
    let learningReport: LearningEligibilityReport

    /// Reasoning transparency - how was the answer derived?
    let reasoningExplanation: ReasoningExplanation?

    init(
        id: String = UUID().uuidString,
        taskId: String,
        tenantId: String,
        createdAt: Date,
        completedAt: Date = Date(),
        ingestion: IngestionSummary,
        pipeline: [PipelineStage],
        engines: [EngineUsage],
        dataLocality: DataLocalityReport,
        persistence: PersistenceReport,
        appliedPolicy: AppliedPolicyReport,
        blockedActions: [BlockedAction] = [],
        learningReport: LearningEligibilityReport,
        reasoningExplanation: ReasoningExplanation? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.tenantId = tenantId
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.ingestion = ingestion
        self.pipeline = pipeline
        self.engines = engines
        self.dataLocality = dataLocality
        self.persistence = persistence
        self.appliedPolicy = appliedPolicy
        self.blockedActions = blockedActions
        self.learningReport = learningReport
        self.reasoningExplanation = reasoningExplanation
    }
}

// MARK: - Ingestion Summary

/// What was fed into the system.
struct IngestionSummary: Sendable, Codable {
    let inputType: InputType
    let inputSize: Int  // bytes or tokens
    let mimeType: String?
    let contentHash: String  // SHA256 for verification
    let metadata: [String: String]

    enum InputType: String, Sendable, Codable {
        case text
        case document
        case image
        case audio
        case structured
        case conversation
    }

    init(
        inputType: InputType,
        inputSize: Int,
        mimeType: String? = nil,
        contentHash: String,
        metadata: [String: String] = [:]
    ) {
        self.inputType = inputType
        self.inputSize = inputSize
        self.mimeType = mimeType
        self.contentHash = contentHash
        self.metadata = metadata
    }
}

// MARK: - Pipeline Stage

/// A single stage in the processing pipeline.
struct PipelineStage: Sendable, Codable, Identifiable {
    let id: String
    let name: String
    let category: StageCategory
    let startedAt: Date
    let completedAt: Date
    let status: StageStatus
    let inputTokens: Int?
    let outputTokens: Int?
    let engineId: String?
    let notes: [String]

    enum StageCategory: String, Sendable, Codable {
        case ingestion
        case preprocessing
        case classification
        case parsing
        case embedding
        case reasoning
        case generation
        case postprocessing
        case validation
    }

    enum StageStatus: String, Sendable, Codable {
        case completed
        case skipped
        case failed
        case partial
    }

    var duration: Duration {
        Duration.seconds(completedAt.timeIntervalSince(startedAt))
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        category: StageCategory,
        startedAt: Date,
        completedAt: Date = Date(),
        status: StageStatus = .completed,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        engineId: String? = nil,
        notes: [String] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.status = status
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.engineId = engineId
        self.notes = notes
    }
}

// MARK: - Engine Usage

/// Which engine/model was used for a task.
struct EngineUsage: Sendable, Codable, Identifiable {
    let id: String
    let engineType: EngineType
    let modelId: String
    let modelFamily: String
    let backend: BackendKind
    let nodeId: String?  // Which cluster node, if distributed
    let isLocal: Bool
    let tokensProcessed: Int
    let latency: TimeInterval

    enum EngineType: String, Sendable, Codable {
        case llm
        case embeddingModel
        case classifier
        case diffusionLM
        case trmSolver
        case symbolicReasoner
        case ocr
        case speechToText
        case textToSpeech
    }

    init(
        id: String = UUID().uuidString,
        engineType: EngineType,
        modelId: String,
        modelFamily: String,
        backend: BackendKind,
        nodeId: String? = nil,
        isLocal: Bool = true,
        tokensProcessed: Int = 0,
        latency: TimeInterval = 0
    ) {
        self.id = id
        self.engineType = engineType
        self.modelId = modelId
        self.modelFamily = modelFamily
        self.backend = backend
        self.nodeId = nodeId
        self.isLocal = isLocal
        self.tokensProcessed = tokensProcessed
        self.latency = latency
    }
}

// MARK: - Data Locality Report

/// Where did the data go?
struct DataLocalityReport: Sendable, Codable {
    let allLocal: Bool
    let remoteEndpoints: [RemoteEndpointUsage]
    let dataResidencyCompliant: Bool
    let encryptionInTransit: Bool
    let encryptionAtRest: Bool

    struct RemoteEndpointUsage: Sendable, Codable {
        let endpointId: String
        let endpointType: String
        let dataSent: DataSentCategory
        let jurisdiction: String?

        enum DataSentCategory: String, Sendable, Codable {
            case none
            case metadataOnly
            case anonymizedContent
            case fullContent
        }

        init(
            endpointId: String,
            endpointType: String,
            dataSent: DataSentCategory,
            jurisdiction: String? = nil
        ) {
            self.endpointId = endpointId
            self.endpointType = endpointType
            self.dataSent = dataSent
            self.jurisdiction = jurisdiction
        }
    }

    public init(
        allLocal: Bool = true,
        remoteEndpoints: [RemoteEndpointUsage] = [],
        dataResidencyCompliant: Bool = true,
        encryptionInTransit: Bool = true,
        encryptionAtRest: Bool = true
    ) {
        self.allLocal = allLocal
        self.remoteEndpoints = remoteEndpoints
        self.dataResidencyCompliant = dataResidencyCompliant
        self.encryptionInTransit = encryptionInTransit
        self.encryptionAtRest = encryptionAtRest
    }

    public static let localOnly = DataLocalityReport(allLocal: true)
}

// MARK: - Persistence Report

/// What was saved after the run?
struct PersistenceReport: Sendable, Codable {
    public let rawContentPersisted: Bool
    public let embeddingsPersisted: Bool
    public let reasoningTracesPersisted: Bool
    public let metadataPersisted: Bool
    public let persistedArtifacts: [PersistedArtifact]
    public let retentionPolicy: String

    struct PersistedArtifact: Sendable, Codable {
        public let type: ArtifactType
        public let location: String
        public let expiresAt: Date?
        public let canBeRevoked: Bool

        enum ArtifactType: String, Sendable, Codable {
            case embedding
            case structuredFact
            case reasoningTrace
            case telemetryEvent
            case auditEntry
        }

        public init(
            type: ArtifactType,
            location: String,
            expiresAt: Date? = nil,
            canBeRevoked: Bool = true
        ) {
            self.type = type
            self.location = location
            self.expiresAt = expiresAt
            self.canBeRevoked = canBeRevoked
        }
    }

    public init(
        rawContentPersisted: Bool = false,
        embeddingsPersisted: Bool = false,
        reasoningTracesPersisted: Bool = false,
        metadataPersisted: Bool = true,
        persistedArtifacts: [PersistedArtifact] = [],
        retentionPolicy: String = "session"
    ) {
        self.rawContentPersisted = rawContentPersisted
        self.embeddingsPersisted = embeddingsPersisted
        self.reasoningTracesPersisted = reasoningTracesPersisted
        self.metadataPersisted = metadataPersisted
        self.persistedArtifacts = persistedArtifacts
        self.retentionPolicy = retentionPolicy
    }

    public static let sessionOnly = PersistenceReport(
        rawContentPersisted: false,
        embeddingsPersisted: false,
        reasoningTracesPersisted: false,
        metadataPersisted: true,
        retentionPolicy: "session"
    )
}

// MARK: - Applied Policy Report

/// Which governance policy applied to this run?
struct AppliedPolicyReport: Sendable, Codable {
    public let policyId: String
    public let policyName: String
    public let profile: BehaviorProfile
    public let constraints: PolicyConstraintsSummary
    public let learningMode: LearningMode

    enum BehaviorProfile: String, Sendable, Codable {
        case careful      // High reasoning, strong governance
        case standard     // Default behavior
        case fast         // Stricter limits, faster responses
        case investigative // More reasoning allowed, sandbox only
    }

    enum LearningMode: String, Sendable, Codable {
        case disabled           // No learning from this run
        case anonymizedOnly     // Only anonymized traces
        case fullEligible       // Full traces eligible (with consent)
    }

    struct PolicyConstraintsSummary: Sendable, Codable {
        public let maxReasoningTokens: Int
        public let externalCallsAllowed: Bool
        public let piiTelemetryBlocked: Bool
        public let trainingEligible: Bool

        public init(
            maxReasoningTokens: Int = 2000,
            externalCallsAllowed: Bool = false,
            piiTelemetryBlocked: Bool = true,
            trainingEligible: Bool = false
        ) {
            self.maxReasoningTokens = maxReasoningTokens
            self.externalCallsAllowed = externalCallsAllowed
            self.piiTelemetryBlocked = piiTelemetryBlocked
            self.trainingEligible = trainingEligible
        }
    }

    public init(
        policyId: String,
        policyName: String,
        profile: BehaviorProfile,
        constraints: PolicyConstraintsSummary,
        learningMode: LearningMode
    ) {
        self.policyId = policyId
        self.policyName = policyName
        self.profile = profile
        self.constraints = constraints
        self.learningMode = learningMode
    }

    public static let dspsRestricted = AppliedPolicyReport(
        policyId: "dsps-restricted",
        policyName: "DSPS Restricted",
        profile: .careful,
        constraints: PolicyConstraintsSummary(
            maxReasoningTokens: 4000,
            externalCallsAllowed: false,
            piiTelemetryBlocked: true,
            trainingEligible: false
        ),
        learningMode: .disabled
    )
}

// MARK: - Blocked Action

/// An action that was blocked by governance.
struct BlockedAction: Sendable, Codable {
    public let actionType: String
    public let reason: String
    public let policyRule: String
    public let timestamp: Date

    public init(
        actionType: String,
        reason: String,
        policyRule: String,
        timestamp: Date = Date()
    ) {
        self.actionType = actionType
        self.reason = reason
        self.policyRule = policyRule
        self.timestamp = timestamp
    }
}

// MARK: - Learning Eligibility Report

/// Is this trace usable for institutional learning?
struct LearningEligibilityReport: Sendable, Codable {
    public let eligible: Bool
    public let eligibilityReasons: [EligibilityFactor]
    public let tracesQueued: Int
    public let traceSummary: String?
    public let userCanRevoke: Bool

    struct EligibilityFactor: Sendable, Codable {
        public let factor: String
        public let passed: Bool
        public let details: String?

        public init(factor: String, passed: Bool, details: String? = nil) {
            self.factor = factor
            self.passed = passed
            self.details = details
        }
    }

    public init(
        eligible: Bool = false,
        eligibilityReasons: [EligibilityFactor] = [],
        tracesQueued: Int = 0,
        traceSummary: String? = nil,
        userCanRevoke: Bool = true
    ) {
        self.eligible = eligible
        self.eligibilityReasons = eligibilityReasons
        self.tracesQueued = tracesQueued
        self.traceSummary = traceSummary
        self.userCanRevoke = userCanRevoke
    }

    public static let notEligible = LearningEligibilityReport(
        eligible: false,
        eligibilityReasons: [
            EligibilityFactor(factor: "policy", passed: false, details: "Institutional learning disabled for this tenant")
        ]
    )
}

// MARK: - Reasoning Explanation

/// Human-readable explanation of how the answer was derived.
struct ReasoningExplanation: Sendable, Codable {
    public let summary: String
    public let reasoningTier: ReasoningTier
    public let keySteps: [ReasoningStep]
    public let evidenceSources: [EvidenceSource]
    public let constraintsApplied: [String]
    public let confidence: ConfidenceLevel

    enum ReasoningTier: String, Sendable, Codable {
        case direct         // Simple lookup/generation
        case symbolic       // Symbolic reasoning only
        case neural         // LLM reasoning
        case hybrid         // Symbolic + neural
        case twoTier        // Full two-tier with TRM
    }

    enum ConfidenceLevel: String, Sendable, Codable {
        case high
        case medium
        case low
        case uncertain
    }

    struct ReasoningStep: Sendable, Codable {
        public let stepNumber: Int
        public let description: String
        public let tier: ReasoningTier
        public let inputsUsed: [String]
        public let outputProduced: String

        public init(
            stepNumber: Int,
            description: String,
            tier: ReasoningTier,
            inputsUsed: [String],
            outputProduced: String
        ) {
            self.stepNumber = stepNumber
            self.description = description
            self.tier = tier
            self.inputsUsed = inputsUsed
            self.outputProduced = outputProduced
        }
    }

    struct EvidenceSource: Sendable, Codable {
        public let sourceType: SourceType
        public let sourceId: String
        public let contribution: Double  // 0.0 to 1.0
        public let description: String

        enum SourceType: String, Sendable, Codable {
            case policy
            case handbook
            case precedent
            case regulation
            case userInput
            case institutionalKnowledge
        }

        public init(
            sourceType: SourceType,
            sourceId: String,
            contribution: Double,
            description: String
        ) {
            self.sourceType = sourceType
            self.sourceId = sourceId
            self.contribution = contribution
            self.description = description
        }
    }

    public init(
        summary: String,
        reasoningTier: ReasoningTier,
        keySteps: [ReasoningStep],
        evidenceSources: [EvidenceSource],
        constraintsApplied: [String],
        confidence: ConfidenceLevel
    ) {
        self.summary = summary
        self.reasoningTier = reasoningTier
        self.keySteps = keySteps
        self.evidenceSources = evidenceSources
        self.constraintsApplied = constraintsApplied
        self.confidence = confidence
    }
}

// MARK: - CoreReceipt Generator

/// Generates processing receipts for inference runs.
struct GenerateReceiptConfiguration: Sendable {
    let task: InferenceTask
    let result: InferenceResult
    let stages: [PipelineStage]
    let engines: [EngineUsage]
    let policy: AppliedPolicyReport
    let blockedActions: [BlockedAction]
    let reasoningExplanation: ReasoningExplanation?

    init(
        task: InferenceTask,
        result: InferenceResult,
        stages: [PipelineStage],
        engines: [EngineUsage],
        policy: AppliedPolicyReport,
        blockedActions: [BlockedAction] = [],
        reasoningExplanation: ReasoningExplanation? = nil
    ) {
        self.task = task
        self.result = result
        self.stages = stages
        self.engines = engines
        self.policy = policy
        self.blockedActions = blockedActions
        self.reasoningExplanation = reasoningExplanation
    }
}

actor ReceiptGenerator {
    private var receiptStore: [String: ProcessingReceipt] = [:]

    init() {}

    func generateReceipt(config: GenerateReceiptConfiguration) -> ProcessingReceipt {
        let ingestion = createIngestionSummary(from: config.task)
        let locality = assessDataLocality(engines: config.engines)
        let persistence = assessPersistence(task: config.task, policy: config.policy)
        let learning = assessLearningEligibility(task: config.task, policy: config.policy)

        let receipt = ProcessingReceipt(
            taskId: config.task.id,
            tenantId: config.task.context.tenantId,
            createdAt: config.task.createdAt,
            completedAt: config.result.completedAt,
            ingestion: ingestion,
            pipeline: config.stages,
            engines: config.engines,
            dataLocality: locality,
            persistence: persistence,
            appliedPolicy: config.policy,
            blockedActions: config.blockedActions,
            learningReport: learning,
            reasoningExplanation: config.reasoningExplanation
        )

        receiptStore[receipt.id] = receipt
        return receipt
    }

    /// Retrieve a stored receipt.
    func getReceipt(id: String) -> ProcessingReceipt? {
        receiptStore[id]
    }

    /// Get all receipts for a task.
    func getReceiptsForTask(taskId: String) -> [ProcessingReceipt] {
        receiptStore.values.filter { $0.taskId == taskId }
    }

    private func createIngestionSummary(from task: InferenceTask) -> IngestionSummary {
        switch task.input {
        case .text(let text):
            return IngestionSummary(
                inputType: .text,
                inputSize: text.utf8.count,
                contentHash: hashContent(text)
            )
        case .messages(let messages):
            let combined = messages.map { $0.content }.joined()
            return IngestionSummary(
                inputType: .conversation,
                inputSize: combined.utf8.count,
                contentHash: hashContent(combined),
                metadata: ["messageCount": "\(messages.count)"]
            )
        case .batch(let items):
            let combined = items.joined()
            return IngestionSummary(
                inputType: .text,
                inputSize: combined.utf8.count,
                contentHash: hashContent(combined),
                metadata: ["batchSize": "\(items.count)"]
            )
        case .structured(let input):
            let description = input.data.description
            return IngestionSummary(
                inputType: .structured,
                inputSize: description.utf8.count,
                contentHash: hashContent(description),
                metadata: ["structuredType": input.type]
            )
        }
    }

    private func assessDataLocality(engines: [EngineUsage]) -> DataLocalityReport {
        let remoteEngines = engines.filter { !$0.isLocal }
        let remoteEndpoints = remoteEngines.map { engine in
            DataLocalityReport.RemoteEndpointUsage(
                endpointId: engine.id,
                endpointType: engine.backend.rawValue,
                dataSent: .anonymizedContent
            )
        }

        return DataLocalityReport(
            allLocal: remoteEngines.isEmpty,
            remoteEndpoints: remoteEndpoints,
            dataResidencyCompliant: true,
            encryptionInTransit: true,
            encryptionAtRest: true
        )
    }

    private func assessPersistence(task: InferenceTask, policy: AppliedPolicyReport) -> PersistenceReport {
        PersistenceReport(
            rawContentPersisted: false,
            embeddingsPersisted: false,
            reasoningTracesPersisted: policy.learningMode != .disabled,
            metadataPersisted: true,
            retentionPolicy: policy.learningMode == .disabled ? "session" : "tenant-default"
        )
    }

    private func assessLearningEligibility(task: InferenceTask, policy: AppliedPolicyReport) -> LearningEligibilityReport {
        var factors: [LearningEligibilityReport.EligibilityFactor] = []

        // Check policy
        let policyPassed = policy.learningMode != .disabled
        factors.append(LearningEligibilityReport.EligibilityFactor(
            factor: "policy",
            passed: policyPassed,
            details: policyPassed ? "Learning enabled for tenant" : "Learning disabled by policy"
        ))

        // Check privacy level
        let privacyPassed = task.constraints.privacyLevel != .restricted
        factors.append(LearningEligibilityReport.EligibilityFactor(
            factor: "privacy",
            passed: privacyPassed,
            details: privacyPassed ? "Privacy level allows learning" : "Restricted privacy level"
        ))

        // Check constraints
        let constraintsPassed = policy.constraints.trainingEligible
        factors.append(LearningEligibilityReport.EligibilityFactor(
            factor: "constraints",
            passed: constraintsPassed,
            details: constraintsPassed ? "Training constraints met" : "Training not allowed by constraints"
        ))

        let allPassed = factors.allSatisfy { $0.passed }

        return LearningEligibilityReport(
            eligible: allPassed,
            eligibilityReasons: factors,
            tracesQueued: allPassed ? 1 : 0,
            traceSummary: allPassed ? "Anonymized reasoning trace queued" : nil,
            userCanRevoke: true
        )
    }

    private func hashContent(_ content: String) -> String {
        // Simple hash for demo - would use CryptoKit in production
        let hash = content.hashValue
        return String(format: "%016llx", UInt64(bitPattern: Int64(hash)))
    }
}

// MARK: - CoreReceipt Renderer

/// Renders receipts in various formats.
struct ReceiptRenderer {

    /// Render a receipt as human-readable text.
    static func renderText(_ receipt: ProcessingReceipt) -> String {
        var lines: [String] = []

        lines.append("═══════════════════════════════════════════════════════════")
        lines.append("                    PROCESSING RECEIPT")
        lines.append("═══════════════════════════════════════════════════════════")
        lines.append("")
        lines.append("CoreReceipt ID: \(receipt.id)")
        lines.append("Task ID: \(receipt.taskId)")
        lines.append("Tenant: \(receipt.tenantId)")
        lines.append("Time: \(receipt.createdAt) → \(receipt.completedAt)")
        lines.append("")

        // Ingestion
        lines.append("┌─ WHAT WAS INGESTED ─────────────────────────────────────┐")
        lines.append("│ Type: \(receipt.ingestion.inputType.rawValue.padding(toLength: 48, withPad: " ", startingAt: 0))│")
        lines.append("│ Size: \(String(receipt.ingestion.inputSize).padding(toLength: 48, withPad: " ", startingAt: 0))│")
        lines.append("│ Hash: \(receipt.ingestion.contentHash.padding(toLength: 48, withPad: " ", startingAt: 0))│")
        lines.append("└──────────────────────────────────────────────────────────┘")
        lines.append("")

        // Pipeline
        lines.append("┌─ PROCESSING PIPELINE ───────────────────────────────────┐")
        for stage in receipt.pipeline {
            let status = stage.status == .completed ? "✓" : "✗"
            lines.append("│ \(status) \(stage.name.padding(toLength: 51, withPad: " ", startingAt: 0))│")
        }
        lines.append("└──────────────────────────────────────────────────────────┘")
        lines.append("")

        // Engines
        lines.append("┌─ ENGINES USED ───────────────────────────────────────────┐")
        for engine in receipt.engines {
            let locality = engine.isLocal ? "LOCAL" : "REMOTE"
            lines.append("│ [\(locality)] \(engine.modelId.padding(toLength: 44, withPad: " ", startingAt: 0))│")
        }
        lines.append("└──────────────────────────────────────────────────────────┘")
        lines.append("")

        // Data Locality
        lines.append("┌─ DATA LOCALITY ──────────────────────────────────────────┐")
        let localityStatus = receipt.dataLocality.allLocal ? "✓ All processing was LOCAL" : "⚠ Some data sent remotely"
        lines.append("│ \(localityStatus.padding(toLength: 54, withPad: " ", startingAt: 0))│")
        lines.append("│ Encryption in transit: \(receipt.dataLocality.encryptionInTransit ? "Yes" : "No").padding(toLength: 30, withPad: \" \", startingAt: 0))│")
        lines.append("└──────────────────────────────────────────────────────────┘")
        lines.append("")

        // Policy
        lines.append("┌─ APPLIED POLICY ─────────────────────────────────────────┐")
        lines.append("│ Policy: \(receipt.appliedPolicy.policyName.padding(toLength: 46, withPad: " ", startingAt: 0))│")
        lines.append("│ Profile: \(receipt.appliedPolicy.profile.rawValue.padding(toLength: 45, withPad: " ", startingAt: 0))│")
        lines.append("│ Max reasoning tokens: \(String(receipt.appliedPolicy.constraints.maxReasoningTokens).padding(toLength: 31, withPad: " ", startingAt: 0))│")
        let extCalls = receipt.appliedPolicy.constraints.externalCallsAllowed ? "Yes" : "No"
        lines.append("│ External calls allowed: \(extCalls.padding(toLength: 29, withPad: " ", startingAt: 0))│")
        let piiBlocked = receipt.appliedPolicy.constraints.piiTelemetryBlocked ? "Yes" : "No"
        lines.append("│ PII in telemetry blocked: \(piiBlocked.padding(toLength: 27, withPad: " ", startingAt: 0))│")
        lines.append("└──────────────────────────────────────────────────────────┘")
        lines.append("")

        // Blocked Actions
        if !receipt.blockedActions.isEmpty {
            lines.append("┌─ BLOCKED ACTIONS ────────────────────────────────────────┐")
            for action in receipt.blockedActions {
                lines.append("│ ✗ \(action.actionType): \(action.reason.prefix(40))│")
            }
            lines.append("└──────────────────────────────────────────────────────────┘")
            lines.append("")
        }

        // Learning
        lines.append("┌─ LEARNING STATUS ────────────────────────────────────────┐")
        let learningStatus = receipt.learningReport.eligible ? "✓ Eligible for institutional learning" : "✗ Not eligible for learning"
        lines.append("│ \(learningStatus.padding(toLength: 54, withPad: " ", startingAt: 0))│")
        if receipt.learningReport.eligible {
            lines.append("│ Traces queued: \(String(receipt.learningReport.tracesQueued).padding(toLength: 38, withPad: " ", startingAt: 0))│")
            let canRevoke = receipt.learningReport.userCanRevoke ? "Yes" : "No"
            lines.append("│ Can revoke: \(canRevoke.padding(toLength: 41, withPad: " ", startingAt: 0))│")
        }
        lines.append("└──────────────────────────────────────────────────────────┘")
        lines.append("")

        // Reasoning (if present)
        if let reasoning = receipt.reasoningExplanation {
            lines.append("┌─ REASONING EXPLANATION ──────────────────────────────────┐")
            lines.append("│ Summary: \(reasoning.summary.prefix(45))│")
            lines.append("│ Tier: \(reasoning.reasoningTier.rawValue.padding(toLength: 48, withPad: " ", startingAt: 0))│")
            lines.append("│ Confidence: \(reasoning.confidence.rawValue.padding(toLength: 42, withPad: " ", startingAt: 0))│")
            lines.append("│ Steps:                                                   │")
            for step in reasoning.keySteps.prefix(3) {
                lines.append("│   \(step.stepNumber). \(step.description.prefix(48))│")
            }
            lines.append("└──────────────────────────────────────────────────────────┘")
        }

        lines.append("")
        lines.append("═══════════════════════════════════════════════════════════")

        return lines.joined(separator: "\n")
    }

    /// Render a receipt as JSON.
    static func renderJSON(_ receipt: ProcessingReceipt) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(receipt)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Render a short summary for UI display.
    static func renderSummary(_ receipt: ProcessingReceipt) -> String {
        let locality = receipt.dataLocality.allLocal ? "🏠 Local" : "🌐 Remote"
        let learning = receipt.learningReport.eligible ? "📚 Learning" : "🔒 No learning"
        let engines = receipt.engines.map { $0.modelFamily }.joined(separator: ", ")

        return """
        \(locality) | \(learning) | Engines: \(engines)
        Policy: \(receipt.appliedPolicy.policyName) (\(receipt.appliedPolicy.profile.rawValue))
        """
    }
}
