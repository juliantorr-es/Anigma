//
//  MakerContracts.swift
//  ContractsCore
//
//  Canonical contract types for MAKER step engine.
//  These are the stable, court-safe types that all step execution must use.
//

import Foundation
import AnigmaPrimitives

// MARK: - Core Step Identifiers

/// Unique identifier for a step within a workflow
public struct StepId: Sendable, Codable, Hashable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public static func generate() -> StepId {
        return StepId(UUID().uuidString)
    }
}

/// Kind of step with defined execution semantics
public enum StepKind: String, Sendable, Codable, CaseIterable {
    case analyze = "analyze"
    case transform = "transform"
    case validate = "validate"
    case generate = "generate"
    case ingest = "ingest"
    case export = "export"
    case migrate = "migrate"
    case test = "test"

    public var description: String {
        switch self {
        case .analyze: return "Analyze existing state"
        case .transform: return "Transform state to new form"
        case .validate: return "Validate state against constraints"
        case .generate: return "Generate new artifacts"
        case .ingest: return "Ingest external data"
        case .export: return "Export data to external system"
        case .migrate: return "Migrate data between formats"
        case .test: return "Execute tests"
        }
    }
}

// MARK: - Step Input/Output Types

/// Canonical input to a step execution
public struct StepInput: Sendable, Codable {
    public let stepId: StepId
    public let stateSlice: StateSlice
    public let context: StepContext
    public let constraints: [StepConstraint]

    public init(stepId: StepId, stateSlice: StateSlice, context: StepContext, constraints: [StepConstraint] = []) {
        self.stepId = stepId
        self.stateSlice = stateSlice
        self.context = context
        self.constraints = constraints
    }
}

/// Output from a step execution
public struct StepOutput: Sendable, Codable {
    public let stepId: StepId
    public let stateDelta: StateDelta
    public let artifacts: [ArtifactRef]
    public let metrics: StepMetrics
    public let status: StepStatus

    public init(stepId: StepId, stateDelta: StateDelta, artifacts: [ArtifactRef] = [], metrics: StepMetrics, status: StepStatus) {
        self.stepId = stepId
        self.stateDelta = stateDelta
        self.artifacts = artifacts
        self.metrics = metrics
        self.status = status
    }
}

/// A candidate action proposed for a step
public struct StepCandidate: Sendable, Codable {
    public let id: CandidateId
    public let stepId: StepId
    public let action: CandidateAction
    public let confidence: Double
    public let reasoning: String
    public let estimatedImpact: ImpactEstimate
    public let policyFlags: [PolicyFlag]

    public init(id: CandidateId, stepId: StepId, action: CandidateAction, confidence: Double, reasoning: String, estimatedImpact: ImpactEstimate, policyFlags: [PolicyFlag] = []) {
        self.id = id
        self.stepId = stepId
        self.action = action
        self.confidence = confidence
        self.reasoning = reasoning
        self.estimatedImpact = estimatedImpact
        self.policyFlags = policyFlags
    }
}

/// Decision made after candidate evaluation
public struct StepDecision: Sendable, Codable {
    public let stepId: StepId
    public let selectedCandidate: CandidateId?
    public let rejectionReason: String?
    public let policyViolations: [PolicyViolation]
    public let trustTierRequired: TrustTier
    public let quarantineAction: QuarantineAction?

    public init(stepId: StepId, selectedCandidate: CandidateId?, rejectionReason: String? = nil, policyViolations: [PolicyViolation] = [], trustTierRequired: TrustTier, quarantineAction: QuarantineAction? = nil) {
        self.stepId = stepId
        self.selectedCandidate = selectedCandidate
        self.rejectionReason = rejectionReason
        self.policyViolations = policyViolations
        self.trustTierRequired = trustTierRequired
        self.quarantineAction = quarantineAction
    }
}

// MARK: - Supporting Types

/// Unique identifier for a candidate
public struct CandidateId: Sendable, Codable, Hashable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public static func generate() -> CandidateId {
        return CandidateId(UUID().uuidString)
    }
}

/// Action that a candidate proposes to take
public struct CandidateAction: Sendable, Codable {
    public let type: ActionType
    public let parameters: [String: String]
    public let targetRefs: [String]  // References to entities in state slice

    public init(type: ActionType, parameters: [String: String], targetRefs: [String] = []) {
        self.type = type
        self.parameters = parameters
        self.targetRefs = targetRefs
    }
}

/// Type of action a candidate can perform
public enum ActionType: String, Sendable, Codable {
    case createFile = "create_file"
    case modifyFile = "modify_file"
    case deleteFile = "delete_file"
    case runCommand = "run_command"
    case callAPI = "call_api"
    case updateState = "update_state"
    case createEntity = "create_entity"
    case updateEntity = "update_entity"
    case deleteEntity = "delete_entity"
    case analyze = "analyze"      // Added
    case transform = "transform"  // Added
    case validate = "validate"    // Added
    case generate = "generate"    // Added
    case ingest = "ingest"        // Added
    case export = "export"        // Added
    case migrate = "migrate"      // Added
    case test = "test"            // Added
}

/// Slice of state provided to step
public struct StateSlice: Sendable, Codable {
    public let entities: [StateEntity]
    public let relations: [StateRelation]
    public let metadata: [String: String]

    public init(entities: [StateEntity] = [], relations: [StateRelation] = [], metadata: [String: String] = [:]) {
        self.entities = entities
        self.relations = relations
        self.metadata = metadata
    }
}

/// Delta representing changes to state
public struct StateDelta: Sendable, Codable {
    public let addedEntities: [StateEntity]
    public let modifiedEntities: [StateEntity]
    public let deletedEntities: [String]  // Entity IDs
    public let addedRelations: [StateRelation]
    public let deletedRelations: [String]  // Relation IDs

    public init(addedEntities: [StateEntity] = [], modifiedEntities: [StateEntity] = [], deletedEntities: [String] = [], addedRelations: [StateRelation] = [], deletedRelations: [String] = []) {
        self.addedEntities = addedEntities
        self.modifiedEntities = modifiedEntities
        self.deletedEntities = deletedEntities
        self.addedRelations = addedRelations
        self.deletedRelations = deletedRelations
    }
}

/// Entity in state slice
public struct StateEntity: Sendable, Codable {
    public let id: String
    public let type: String
    public let attributes: [String: String]

    public init(id: String, type: String, attributes: [String: String]) {
        self.id = id
        self.type = type
        self.attributes = attributes
    }
}

/// Relation between entities in state slice
public struct StateRelation: Sendable, Codable {
    public let id: String
    public let fromEntity: String
    public let toEntity: String
    public let relationType: String
    public let attributes: [String: String]

    public init(id: String, fromEntity: String, toEntity: String, relationType: String, attributes: [String: String] = [:]) {
        self.id = id
        self.fromEntity = fromEntity
        self.toEntity = toEntity
        self.relationType = relationType
        self.attributes = attributes
    }
}

/// Context for step execution
public struct StepContext: Sendable, Codable {
    public let workflowId: String
    public let sessionId: String
    public let trustTier: TrustTier
    public let allowedCapabilities: [String]
    public let securityZone: SecurityZone
    public let deadline: Date?

    public init(workflowId: String, sessionId: String, trustTier: TrustTier, allowedCapabilities: [String], securityZone: SecurityZone, deadline: Date? = nil) {
        self.workflowId = workflowId
        self.sessionId = sessionId
        self.trustTier = trustTier
        self.allowedCapabilities = allowedCapabilities
        self.securityZone = securityZone
        self.deadline = deadline
    }
}

/// Constraint on step execution
public struct StepConstraint: Sendable, Codable {
    public let type: ConstraintType
    public let parameters: [String: String]

    public init(type: ConstraintType, parameters: [String: String] = [:]) {
        self.type = type
        self.parameters = parameters
    }
}

/// Type of constraint
public enum ConstraintType: String, Sendable, Codable {
    case maxDuration = "max_duration"
    case maxMemory = "max_memory"
    case allowedPaths = "allowed_paths"
    case forbiddenPaths = "forbidden_paths"
    case maxTokens = "max_tokens"
    case requireApproval = "require_approval"
}

/// Metrics for step execution
public struct StepMetrics: Sendable, Codable {
    public let duration: TimeInterval
    public let memoryUsed: Int64
    public let tokensProcessed: Int?
    public let filesAccessed: Int
    public let networkCalls: Int

    public init(duration: TimeInterval, memoryUsed: Int64, tokensProcessed: Int? = nil, filesAccessed: Int = 0, networkCalls: Int = 0) {
        self.duration = duration
        self.memoryUsed = memoryUsed
        self.tokensProcessed = tokensProcessed
        self.filesAccessed = filesAccessed
        self.networkCalls = networkCalls
    }
}

/// Status of step execution
public enum StepStatus: String, Sendable, Codable, Equatable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    case quarantined = "quarantined"
}

/// Estimate of impact for a candidate
public struct ImpactEstimate: Sendable, Codable {
    public let riskLevel: RiskLevel
    public let changesEstimated: Int
    public let resourcesRequired: ResourceEstimate
    public let rollbackComplexity: RollbackComplexity

    public init(riskLevel: RiskLevel, changesEstimated: Int, resourcesRequired: ResourceEstimate, rollbackComplexity: RollbackComplexity) {
        self.riskLevel = riskLevel
        self.changesEstimated = changesEstimated
        self.resourcesRequired = resourcesRequired
        self.rollbackComplexity = rollbackComplexity
    }
}

/// Resource estimate for impact
public struct ResourceEstimate: Sendable, Codable {
    public let cpuTime: TimeInterval
    public let memoryBytes: Int64
    public let diskBytes: Int64
    public let networkBytes: Int64

    public init(cpuTime: TimeInterval = 0, memoryBytes: Int64 = 0, diskBytes: Int64 = 0, networkBytes: Int64 = 0) {
        self.cpuTime = cpuTime
        self.memoryBytes = memoryBytes
        self.diskBytes = diskBytes
        self.networkBytes = networkBytes
    }
}

/// Flag raised by policy evaluation
public struct PolicyFlag: Sendable, Codable {
    public let policy: String
    public let severity: PolicySeverity
    public let message: String

    public init(policy: String, severity: PolicySeverity, message: String) {
        self.policy = policy
        self.severity = severity
        self.message = message
    }
}

/// Severity of policy flag
public enum PolicySeverity: String, Sendable, Codable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
}

/// Violation of policy
public struct PolicyViolation: Sendable, Codable {
    public let policy: String
    public let rule: String
    public let severity: PolicySeverity
    public let description: String
    public let remediation: String?

    public init(policy: String, rule: String, severity: PolicySeverity, description: String, remediation: String? = nil) {
        self.policy = policy
        self.rule = rule
        self.severity = severity
        self.description = description
        self.remediation = remediation
    }
}

/// Quarantine action for problematic steps
public struct QuarantineAction: Sendable, Codable {
    public let reason: String
    public let duration: TimeInterval?  // nil = indefinite
    public let conditions: [String]     // Conditions to lift quarantine

    public init(reason: String, duration: TimeInterval? = nil, conditions: [String] = []) {
        self.reason = reason
        self.duration = duration
        self.conditions = conditions
    }
}

/// Reference to an artifact
public struct ArtifactRef: Sendable, Codable {
    public let id: String
    public let type: String
    public let hash: String
    public let location: String

    public init(id: String, type: String, hash: String, location: String) {
        self.id = id
        self.type = type
        self.hash = hash
        self.location = location
    }
}

// MARK: - Trace Types

/// Complete trace of step execution
public struct StepTrace: Sendable, Codable {
    public let schemaVersion: String
    public let id: TraceId
    public let stepId: StepId
    public let workflowId: String
    public let sessionId: String
    public let timestamp: Date
    public let input: StepInput
    public var candidates: [StepCandidate]
    public var decision: StepDecision
    public var output: StepOutput?
    public var events: [TraceEvent]

    public init(id: TraceId, stepId: StepId, workflowId: String, sessionId: String, timestamp: Date, input: StepInput, candidates: [StepCandidate], decision: StepDecision, output: StepOutput?, events: [TraceEvent]) {
        self.id = id
        self.stepId = stepId
        self.workflowId = workflowId
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.schemaVersion = "v1"
        self.input = input
        self.candidates = candidates
        self.decision = decision
        self.output = output
        self.events = events
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, stepId, workflowId, sessionId
        case timestamp, input, candidates, decision, output, events
    }
}

/// Content value kinds for trace redaction
public enum TraceValueKind: String, Sendable, Codable {
    case hash = "hash"           // Content hash only
    case pointer = "pointer"     // Reference to stored content
    case preview = "preview"     // Redacted preview
    case literal = "literal"     // Full content (policy-gated)
}

/// Redaction policy for trace content
public struct RedactionPolicy: Sendable, Codable, Equatable {
    public let allowedKinds: [TraceValueKind]
    public let maxPreviewLength: Int?
    public let requireHashForSensitive: Bool

    public init(allowedKinds: [TraceValueKind], maxPreviewLength: Int? = nil, requireHashForSensitive: Bool = true) {
        self.allowedKinds = allowedKinds
        self.maxPreviewLength = maxPreviewLength
        self.requireHashForSensitive = requireHashForSensitive
    }
}

/// Individual event within a trace
public struct TraceEvent: Sendable, Codable, Equatable {
    public let id: EventId
    public let timestamp: Date
    public let type: EventType
    public let severity: EventSeverity
    public let component: String
    public let message: String
    public let data: [String: String]
    public let valueKind: TraceValueKind
    public let redactionPolicy: RedactionPolicy?

    public init(id: EventId, timestamp: Date, type: EventType, severity: EventSeverity, component: String, message: String, data: [String: String] = [:], valueKind: TraceValueKind = .hash, redactionPolicy: RedactionPolicy? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.severity = severity
        self.component = component
        self.message = message
        self.data = data
        self.valueKind = valueKind
        self.redactionPolicy = redactionPolicy
    }
}

/// Unique identifier for a trace
public struct TraceId: Sendable, Codable, Hashable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public static func generate() -> TraceId {
        return TraceId(UUID().uuidString)
    }
}

/// Unique identifier for an event
public struct EventId: Sendable, Codable, Hashable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public static func generate() -> EventId {
        return EventId(UUID().uuidString)
    }
}

/// Type of trace event
public enum EventType: String, Sendable, Codable {
    case stepStarted = "step_started"
    case stepCompleted = "step_completed"
    case stepFailed = "step_failed"
    case candidateGenerated = "candidate_generated"
    case candidateEvaluated = "candidate_evaluated"
    case candidateSelected = "candidate_selected"
    case candidateRejected = "candidate_rejected"
    case policyChecked = "policy_checked"
    case policyViolated = "policy_violated"
    case quarantineTriggered = "quarantine_triggered"
    case resourceExhausted = "resource_exhausted"
    case timeout = "timeout"
}

/// Severity of trace event
public enum EventSeverity: String, Sendable, Codable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
}

// MARK: - Workflow Contracts

/// Contract for step input validation
public struct StepInputContract: WorkflowContract {
    public static let id = ContractID(name: "maker.step.input", major: 1, minor: 0, schemaHash: "v1.0")

    public let payload: StepInput

    public init(_ payload: StepInput) {
        self.payload = payload
    }

    public static func validateInvariants(_ value: StepInputContract) throws {
        // Validate that state slice is not empty
        guard !value.payload.stateSlice.entities.isEmpty || !value.payload.stateSlice.relations.isEmpty else {
            throw ValidationError.invalidRequest("State slice cannot be empty")
        }

        // Validate that step ID is valid
        guard !value.payload.stepId.value.isEmpty else {
            throw ValidationError.invalidRequest("Step ID cannot be empty")
        }
    }
}

/// Contract for step output validation
public struct StepOutputContract: WorkflowContract {
    public static let id = ContractID(name: "maker.step.output", major: 1, minor: 0, schemaHash: "v1.0")

    public let payload: StepOutput

    public init(_ payload: StepOutput) {
        self.payload = payload
    }

    public static func validateInvariants(_ value: StepOutputContract) throws {
        // Validate that step IDs match
        guard !value.payload.stepId.value.isEmpty else {
            throw ValidationError.invalidRequest("Step ID cannot be empty")
        }

        // Validate metrics are reasonable
        guard value.payload.metrics.duration >= 0 else {
            throw ValidationError.invalidRequest("Duration cannot be negative")
        }

        guard value.payload.metrics.memoryUsed >= 0 else {
            throw ValidationError.invalidRequest("Memory usage cannot be negative")
        }
    }
}

/// Contract for trace validation
public struct StepTraceContract: WorkflowContract {
    public static let id = ContractID(name: "maker.step.trace", major: 1, minor: 0, schemaHash: "v1.0")

    public let payload: StepTrace

    public init(_ payload: StepTrace) {
        self.payload = payload
    }

    public static func validateInvariants(_ value: StepTraceContract) throws {
        // Validate trace has required fields
        guard !value.payload.stepId.value.isEmpty else {
            throw ValidationError.invalidRequest("Step ID cannot be empty")
        }

        guard !value.payload.workflowId.isEmpty else {
            throw ValidationError.invalidRequest("Workflow ID cannot be empty")
        }

        guard !value.payload.sessionId.isEmpty else {
            throw ValidationError.invalidRequest("Session ID cannot be empty")
        }

        // Validate events are in chronological order
        let sortedEvents = value.payload.events.sorted { $0.timestamp < $1.timestamp }
        guard sortedEvents == value.payload.events else {
            throw ValidationError.invalidRequest("Events must be in chronological order")
        }
    }
}

// MARK: - Quarantine Records

/// Retry policy for quarantined steps
public struct RetryPolicy: Sendable, Codable {
    public let maxRetries: Int
    public let backoffMultiplier: Double
    public let maxBackoffSeconds: Int

    public init(maxRetries: Int = 3, backoffMultiplier: Double = 2.0, maxBackoffSeconds: Int = 300) {
        self.maxRetries = maxRetries
        self.backoffMultiplier = backoffMultiplier
        self.maxBackoffSeconds = maxBackoffSeconds
    }
}

/// Durable record for quarantined steps
public struct QuarantineRecord: Sendable, Codable {
    public let stepId: StepId
    public let reason: String
    public let errorSignature: String
    public let quarantinedAt: Date
    public let nextEligibleTime: Date?
    public let retryPolicy: RetryPolicy

    public init(stepId: StepId, reason: String, errorSignature: String, quarantinedAt: Date = Date(), nextEligibleTime: Date? = nil, retryPolicy: RetryPolicy = RetryPolicy()) {
        self.stepId = stepId
        self.reason = reason
        self.errorSignature = errorSignature
        self.quarantinedAt = quarantinedAt
        self.nextEligibleTime = nextEligibleTime
        self.retryPolicy = retryPolicy
    }
}

/// Result of policy evaluation
public struct PolicyEvaluationResult: Sendable, Codable { // Added Codable conformance
    public let allowed: Bool
    public let flags: [PolicyFlag]
    public let violations: [PolicyViolation]

    public init(allowed: Bool, flags: [PolicyFlag] = [], violations: [PolicyViolation] = []) {
        self.allowed = allowed
        self.flags = flags
        self.violations = violations
    }
}

// MARK: - Optimization Contracts

/// Protocol for optimization strategies within MAKER engine
public protocol OptimizationStrategy: Sendable {
    /// Unique identifier for this optimization strategy
    var strategyId: String { get }
    
    /// Human-readable name for the strategy
    var name: String { get }
    
    /// Description of what this strategy optimizes
    var description: String { get }
    
    /// Apply optimization to a candidate
    func optimize(candidate: StepCandidate, context: StepContext) async throws -> OptimizedCandidate
}

/// Optimized candidate with optimization metadata
public struct OptimizedCandidate: Sendable, Codable {
    public let originalCandidate: StepCandidate
    public let optimizedCandidate: StepCandidate
    public let optimizationStrategy: String
    public let optimizationMetrics: OptimizationMetrics
    public let appliedOptimizations: [AppliedOptimization]

    public init(
        originalCandidate: StepCandidate,
        optimizedCandidate: StepCandidate,
        optimizationStrategy: String,
        optimizationMetrics: OptimizationMetrics,
        appliedOptimizations: [AppliedOptimization] = []
    ) {
        self.originalCandidate = originalCandidate
        self.optimizedCandidate = optimizedCandidate
        self.optimizationStrategy = optimizationStrategy
        self.optimizationMetrics = optimizationMetrics
        self.appliedOptimizations = appliedOptimizations
    }
}

/// Metrics for optimization results
public struct OptimizationMetrics: Sendable, Codable {
    public let performanceImprovement: Double  // Percentage improvement (0.0-1.0)
    public let resourceReduction: ResourceEstimate
    public let confidenceImpact: Double      // Impact on original confidence (-1.0 to 1.0)
    public let optimizationTimeMs: TimeInterval
    public let determinismPreserved: Bool

    public init(
        performanceImprovement: Double = 0.0,
        resourceReduction: ResourceEstimate = ResourceEstimate(),
        confidenceImpact: Double = 0.0,
        optimizationTimeMs: TimeInterval = 0,
        determinismPreserved: Bool = true
    ) {
        self.performanceImprovement = performanceImprovement
        self.resourceReduction = resourceReduction
        self.confidenceImpact = confidenceImpact
        self.optimizationTimeMs = optimizationTimeMs
        self.determinismPreserved = determinismPreserved
    }
}

/// Individual optimization that was applied
public struct AppliedOptimization: Sendable, Codable {
    public let optimizationType: OptimizationType
    public let description: String
    public let beforeValue: String
    public let afterValue: String
    public let impactScore: Double  // 0.0-1.0 scale

    public init(
        optimizationType: OptimizationType,
        description: String,
        beforeValue: String,
        afterValue: String,
        impactScore: Double
    ) {
        self.optimizationType = optimizationType
        self.description = description
        self.beforeValue = beforeValue
        self.afterValue = afterValue
        self.impactScore = impactScore
    }
}

/// Types of optimizations available
public enum OptimizationType: String, Sendable, Codable, CaseIterable {
    case resourceReduction = "resource_reduction"
    case performanceImprovement = "performance_improvement"
    case determinismEnhancement = "determinism_enhancement"
    case confidenceCalibration = "confidence_calibration"
    case resourceReallocation = "resource_reallocation"
    case pathOptimization = "path_optimization"
    case constraintRelaxation = "constraint_relaxation"

    public var description: String {
        switch self {
        case .resourceReduction: return "Reduce resource usage while maintaining functionality"
        case .performanceImprovement: return "Improve execution performance and efficiency"
        case .determinismEnhancement: return "Enhance deterministic behavior and reproducibility"
        case .confidenceCalibration: return "Calibrate confidence scores for better accuracy"
        case .resourceReallocation: return "Reallocate resources for better utilization"
        case .pathOptimization: return "Optimize execution paths and sequences"
        case .constraintRelaxation: return "Relax constraints while maintaining safety"
        }
    }
}

/// Bounded optimization profile for deterministic execution
public struct OptimizationProfile: Sendable, Codable {
    public let profileId: String
    public let strategyIds: [String]  // Ordered list of strategy IDs to apply
    public let maxOptimizationTimeMs: TimeInterval
    public let maxResourceImpact: ResourceEstimate
    public let requireDeterminism: Bool
    public let allowedOptimizationTypes: [OptimizationType]

    public init(
        profileId: String,
        strategyIds: [String],
        maxOptimizationTimeMs: TimeInterval = 1000,  // 1 second default
        maxResourceImpact: ResourceEstimate = ResourceEstimate(cpuTime: 500, memoryBytes: 1024*1024, diskBytes: 1024*1024),
        requireDeterminism: Bool = true,
        allowedOptimizationTypes: [OptimizationType] = OptimizationType.allCases
    ) {
        self.profileId = profileId
        self.strategyIds = strategyIds
        self.maxOptimizationTimeMs = maxOptimizationTimeMs
        self.maxResourceImpact = maxResourceImpact
        self.requireDeterminism = requireDeterminism
        self.allowedOptimizationTypes = allowedOptimizationTypes
    }
}

/// Context for optimization execution
public struct OptimizationContext: Sendable, Codable {
    public let sessionId: String
    public let workflowId: String
    public let optimizationProfile: OptimizationProfile
    public let deterministicSeed: String?
    public let resourceLimits: ResourceEstimate
    public let allowedStrategies: [String]

    public init(
        sessionId: String,
        workflowId: String,
        optimizationProfile: OptimizationProfile,
        deterministicSeed: String? = nil,
        resourceLimits: ResourceEstimate = ResourceEstimate(),
        allowedStrategies: [String] = []
    ) {
        self.sessionId = sessionId
        self.workflowId = workflowId
        self.optimizationProfile = optimizationProfile
        self.deterministicSeed = deterministicSeed
        self.resourceLimits = resourceLimits
        self.allowedStrategies = allowedStrategies
    }
}

/// Result of optimization batch
public struct OptimizationResult: Sendable, Codable {
    public let contextId: String
    public let profileId: String
    public let optimizedCandidates: [OptimizedCandidate]
    public let batchMetrics: BatchOptimizationMetrics
    public let determinismValidation: DeterminismValidation?
    public let appliedConstraints: [OptimizationConstraint]

    public init(
        contextId: String,
        profileId: String,
        optimizedCandidates: [OptimizedCandidate] = [],
        batchMetrics: BatchOptimizationMetrics,
        determinismValidation: DeterminismValidation? = nil,
        appliedConstraints: [OptimizationConstraint] = []
    ) {
        self.contextId = contextId
        self.profileId = profileId
        self.optimizedCandidates = optimizedCandidates
        self.batchMetrics = batchMetrics
        self.determinismValidation = determinismValidation
        self.appliedConstraints = appliedConstraints
    }
}

/// Metrics for optimization batch processing
public struct BatchOptimizationMetrics: Sendable, Codable {
    public let totalProcessingTimeMs: TimeInterval
    public let averageOptimizationTimeMs: TimeInterval
    public let totalPerformanceImprovement: Double
    public let totalResourceReduction: ResourceEstimate
    public let determinismPreservationRate: Double  // 0.0-1.0
    public let optimizationSuccessRate: Double  // 0.0-1.0

    public init(
        totalProcessingTimeMs: TimeInterval,
        averageOptimizationTimeMs: TimeInterval,
        totalPerformanceImprovement: Double = 0.0,
        totalResourceReduction: ResourceEstimate = ResourceEstimate(),
        determinismPreservationRate: Double = 1.0,
        optimizationSuccessRate: Double = 1.0
    ) {
        self.totalProcessingTimeMs = totalProcessingTimeMs
        self.averageOptimizationTimeMs = averageOptimizationTimeMs
        self.totalPerformanceImprovement = totalPerformanceImprovement
        self.totalResourceReduction = totalResourceReduction
        self.determinismPreservationRate = determinismPreservationRate
        self.optimizationSuccessRate = optimizationSuccessRate
    }
}

/// Validation of deterministic behavior
public struct DeterminismValidation: Sendable, Codable {
    public let validationId: String
    public let deterministicSeed: String
    public let beforeHash: String
    public let afterHash: String
    public let determinismPreserved: Bool
    public let varianceExplanation: String?

    public init(
        validationId: String,
        deterministicSeed: String,
        beforeHash: String,
        afterHash: String,
        determinismPreserved: Bool,
        varianceExplanation: String? = nil
    ) {
        self.validationId = validationId
        self.deterministicSeed = deterministicSeed
        self.beforeHash = beforeHash
        self.afterHash = afterHash
        self.determinismPreserved = determinismPreserved
        self.varianceExplanation = varianceExplanation
    }
}

/// Constraints applied during optimization - reuse existing StepConstraint
public typealias OptimizationConstraint = StepConstraint
