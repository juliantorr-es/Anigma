//
//  SelfTuningArchitectureSelection.swift
//  HarmoniaModule
//
//  Implements learned architecture selection policies that:
//  - Learn optimal model routing per tenant/domain from experience
//  - Close the loop: selection → metrics → learning impact → governed updates
//  - Use gremlins to attack routing policies
//  - Support environment-specific tuning (CCSF prod vs staging vs lab)
//
//  This turns architecture selection from heuristics into a learned, governed policy.
//

@preconcurrency import Foundation
import AnigmaCore

// MARK: - Architecture Selection Policy

/// A learned policy for selecting model architectures.
public struct ArchitectureSelectionPolicy: Sendable, Codable, Identifiable {
    public let id: String
    public let tenantId: String
    public let domain: SelectionDomain
    public let version: Int

    /// Learned weights for different architecture features.
    public var featureWeights: [ArchitectureFeatureKey: Double]

    /// Task-specific routing rules.
    public var taskRoutes: [TaskRoutingRule]

    /// Constraints that override learned weights.
    public var hardConstraints: [RoutingConstraint]

    /// Performance history that shaped this policy.
    public let trainingHistory: PolicyTrainingHistory

    /// When this policy was last updated.
    public var lastUpdated: Date

    /// Governance info.
    public let approvedBy: String?
    public let approvedAt: Date?

    public init(
        id: String = UUID().uuidString,
        tenantId: String,
        domain: SelectionDomain,
        version: Int = 1,
        featureWeights: [ArchitectureFeatureKey: Double] = [:],
        taskRoutes: [TaskRoutingRule] = [],
        hardConstraints: [RoutingConstraint] = [],
        trainingHistory: PolicyTrainingHistory = .empty,
        approvedBy: String? = nil
    ) {
        self.id = id
        self.tenantId = tenantId
        self.domain = domain
        self.version = version
        self.featureWeights = featureWeights
        self.taskRoutes = taskRoutes
        self.hardConstraints = hardConstraints
        self.trainingHistory = trainingHistory
        self.lastUpdated = Date()
        self.approvedBy = approvedBy
        self.approvedAt = approvedBy != nil ? Date() : nil
    }

    /// Scores a model for a task using learned weights.
    public func score(
        model: ModelDescriptor,
        task: InferenceTask,
        architectureProfile: ArchitectureProfile?
    ) -> PolicyScore {
        var baseScore = 0.5
        var explanation: [String] = []

        // Apply hard constraints first
        for constraint in hardConstraints {
            if let violation = constraint.check(model: model, task: task) {
                return PolicyScore(
                    score: 0,
                    confidence: 1.0,
                    explanation: ["Hard constraint violated: \(violation)"],
                    selectedRoute: nil
                )
            }
        }

        // Check task-specific routes
        for route in taskRoutes where route.matches(task) {
            if route.preferredModelFamily == model.family {
                baseScore += route.bonus
                explanation.append("Task route match: +\(route.bonus)")
            }
        }

        // Apply learned feature weights
        if let profile = architectureProfile {
            for (feature, weight) in featureWeights {
                let featureValue = extractFeatureValue(feature, from: profile, task: task)
                baseScore += featureValue * weight
                if abs(weight) > 0.1 {
                    explanation.append("\(feature.rawValue): \(featureValue) * \(weight)")
                }
            }
        }

        return PolicyScore(
            score: min(max(baseScore, 0), 1),
            confidence: calculateConfidence(),
            explanation: explanation,
            selectedRoute: taskRoutes.first { $0.matches(task) }
        )
    }

    private func extractFeatureValue(
        _ key: ArchitectureFeatureKey,
        from profile: ArchitectureProfile,
        task: InferenceTask
    ) -> Double {
        switch key {
        case .kvCompression:
            return profile.kvCache.isCompressed ? 1.0 : 0.0
        case .longContextFriendly:
            return profile.isLongContextFriendly ? 1.0 : 0.0
        case .quantizationStable:
            return profile.quantization.quantizationFriendly ? 1.0 : 0.0
        case .fastStructuredOutput:
            return profile.isFastStructuredOutput ? 1.0 : 0.0
        case .diffusionBased:
            return profile.generationMode == .diffusion ? 1.0 : 0.0
        case .distributedSuitable:
            return profile.distributedInferenceSuitability
        case .contextSizeMatch:
            let hints = ArchitectureSchedulingHints.from(task: task)
            return profile.longContext.degradationThreshold > hints.requiredContext ? 1.0 : 0.0
        }
    }

    private func calculateConfidence() -> Double {
        // Confidence based on training history
        let observations = trainingHistory.totalObservations
        if observations < 10 { return 0.3 }
        if observations < 100 { return 0.5 }
        if observations < 1000 { return 0.7 }
        return 0.9
    }
}

/// Domains for selection policies.
public enum SelectionDomain: String, Sendable, Codable, CaseIterable {
    case dsps
    case transcriptum
    case compliance
    case coding
    case altMedia
    case general
}

/// Feature keys for learned weights.
public enum ArchitectureFeatureKey: String, Sendable, Codable, CaseIterable {
    case kvCompression
    case longContextFriendly
    case quantizationStable
    case fastStructuredOutput
    case diffusionBased
    case distributedSuitable
    case contextSizeMatch
}

/// A task-specific routing rule.
public struct TaskRoutingRule: Sendable, Codable {
    public let taskPattern: TaskPattern
    public let preferredModelFamily: String
    public let preferredBackend: BackendKind?
    public let bonus: Double
    public let reason: String

    public init(
        taskPattern: TaskPattern,
        preferredModelFamily: String,
        preferredBackend: BackendKind? = nil,
        bonus: Double = 0.2,
        reason: String
    ) {
        self.taskPattern = taskPattern
        self.preferredModelFamily = preferredModelFamily
        self.preferredBackend = preferredBackend
        self.bonus = bonus
        self.reason = reason
    }

    public func matches(_ task: InferenceTask) -> Bool {
        taskPattern.matches(task)
    }
}

/// Pattern for matching tasks.
public struct TaskPattern: Sendable, Codable {
    public let kinds: Set<InferenceTaskKind>?
    public let minContextTokens: Int?
    public let maxLatencyMs: Int?
    public let requiresStructuredOutput: Bool?

    public init(
        kinds: Set<InferenceTaskKind>? = nil,
        minContextTokens: Int? = nil,
        maxLatencyMs: Int? = nil,
        requiresStructuredOutput: Bool? = nil
    ) {
        self.kinds = kinds
        self.minContextTokens = minContextTokens
        self.maxLatencyMs = maxLatencyMs
        self.requiresStructuredOutput = requiresStructuredOutput
    }

    public func matches(_ task: InferenceTask) -> Bool {
        if let kinds = kinds, !kinds.contains(task.kind) {
            return false
        }
        // Add more matching logic as needed
        return true
    }
}

/// Hard constraint that cannot be overridden by learning.
public struct RoutingConstraint: Sendable, Codable {
    public let name: String
    public let type: ConstraintType
    public let value: String

    public enum ConstraintType: String, Sendable, Codable {
        case requireLocalOnly
        case forbidBackend
        case requireBackend
        case maxCost
        case minQuality
    }

    public init(name: String, type: ConstraintType, value: String) {
        self.name = name
        self.type = type
        self.value = value
    }

    public func check(model: ModelDescriptor, task: InferenceTask) -> String? {
        switch type {
        case .requireLocalOnly:
            if model.backend == .remoteAPI {
                return "Remote API not allowed for this tenant"
            }
        case .forbidBackend:
            if model.backend.rawValue == value {
                return "Backend \(value) is forbidden"
            }
        case .requireBackend:
            if model.backend.rawValue != value {
                return "Backend \(value) is required"
            }
        case .maxCost, .minQuality:
            break // Would check against model metadata
        }
        return nil
    }
}

/// Score from policy evaluation.
public struct PolicyScore: Sendable {
    public let score: Double
    public let confidence: Double
    public let explanation: [String]
    public let selectedRoute: TaskRoutingRule?
}

/// Training history for a policy.
public struct PolicyTrainingHistory: Sendable, Codable {
    public var totalObservations: Int
    public var successfulSelections: Int
    public var failedSelections: Int
    public var lastTrainingDate: Date?
    public var improvementTrend: Double  // Positive = getting better

    public static let empty = PolicyTrainingHistory(
        totalObservations: 0,
        successfulSelections: 0,
        failedSelections: 0,
        lastTrainingDate: nil,
        improvementTrend: 0
    )

    public var successRate: Double {
        guard totalObservations > 0 else { return 0 }
        return Double(successfulSelections) / Double(totalObservations)
    }
}

// MARK: - Selection Policy Service

/// Service for managing and learning architecture selection policies.
public actor SelectionPolicyService {
    /// Policies by tenant and domain.
    private var policies: [String: [SelectionDomain: ArchitectureSelectionPolicy]] = [:]

    /// Observation buffer for learning.
    private var observationBuffer: [SelectionObservation] = []

    /// Maximum buffer size before triggering learning.
    private let maxBufferSize = 100

    /// Default policy template.
    private var defaultPolicy: ArchitectureSelectionPolicy

    /// Architecture registry for profiles.
    private let architectureRegistry: ArchitectureRegistry

    public init(architectureRegistry: ArchitectureRegistry) {
        self.architectureRegistry = architectureRegistry
        self.defaultPolicy = ArchitectureSelectionPolicy(
            id: "default",
            tenantId: "*",
            domain: .general,
            featureWeights: [
                .kvCompression: 0.15,
                .longContextFriendly: 0.2,
                .quantizationStable: 0.1,
                .fastStructuredOutput: 0.15,
                .contextSizeMatch: 0.25
            ]
        )
    }

    // MARK: - Policy Management

    /// Gets the policy for a tenant/domain.
    public func getPolicy(
        tenantId: String,
        domain: SelectionDomain
    ) -> ArchitectureSelectionPolicy {
        policies[tenantId]?[domain] ?? defaultPolicy
    }

    /// Registers a policy.
    public func registerPolicy(_ policy: ArchitectureSelectionPolicy) {
        var tenantPolicies = policies[policy.tenantId] ?? [:]
        tenantPolicies[policy.domain] = policy
        policies[policy.tenantId] = tenantPolicies
    }

    // MARK: - Selection

    /// Selects the best model for a task using learned policy.
    public func selectModel(
        from candidates: [ModelDescriptor],
        for task: InferenceTask,
        tenantId: String,
        domain: SelectionDomain
    ) async -> SelectionResult {
        let policy = getPolicy(tenantId: tenantId, domain: domain)

        var scoredCandidates: [(ModelDescriptor, PolicyScore)] = []

        for candidate in candidates {
            let profile = await architectureRegistry.getProfile(for: candidate.family)
            let score = policy.score(
                model: candidate,
                task: task,
                architectureProfile: profile
            )
            // Only include candidates that pass constraints (score > 0)
            if score.score > 0 {
                scoredCandidates.append((candidate, score))
            }
        }

        // Sort by score descending
        scoredCandidates.sort { $0.1.score > $1.1.score }

        guard let best = scoredCandidates.first else {
            return SelectionResult(
                selectedModel: nil,
                score: PolicyScore(score: 0, confidence: 0, explanation: ["No candidates pass constraints"], selectedRoute: nil),
                alternates: [],
                policyId: policy.id,
                policyVersion: policy.version
            )
        }

        return SelectionResult(
            selectedModel: best.0,
            score: best.1,
            alternates: Array(scoredCandidates.dropFirst().prefix(3).map { $0.0 }),
            policyId: policy.id,
            policyVersion: policy.version
        )
    }

    // MARK: - Learning

    /// Records an observation for learning.
    public func recordObservation(_ observation: SelectionObservation) {
        observationBuffer.append(observation)

        if observationBuffer.count >= maxBufferSize {
            Task {
                await triggerLearning()
            }
        }
    }

    /// Triggers policy learning from observations.
    public func triggerLearning() async {
        guard !observationBuffer.isEmpty else { return }

        // Group observations by tenant/domain
        let grouped = Dictionary(grouping: observationBuffer) { obs in
            "\(obs.tenantId):\(obs.domain.rawValue)"
        }

        for (key, observations) in grouped {
            let parts = key.split(separator: ":")
            guard parts.count == 2,
                  let domain = SelectionDomain(rawValue: String(parts[1])) else {
                continue
            }
            let tenantId = String(parts[0])

            // Get or create policy
            var policy = getPolicy(tenantId: tenantId, domain: domain)

            // Update weights based on observations
            policy = updateWeights(policy: policy, observations: observations)

            // Register updated policy (would go through governance in production)
            registerPolicy(policy)
        }

        // Clear buffer
        observationBuffer.removeAll()
    }

    private func updateWeights(
        policy: ArchitectureSelectionPolicy,
        observations: [SelectionObservation]
    ) -> ArchitectureSelectionPolicy {
        var updated = policy

        // Simple gradient-free update: increase weights for features of successful selections
        for observation in observations where observation.wasSuccessful {
            for feature in observation.activeFeatures {
                let currentWeight = updated.featureWeights[feature] ?? 0.1
                let learningRate = 0.01
                updated.featureWeights[feature] = currentWeight + learningRate
            }
        }

        // Decrease weights for failed selections
        for observation in observations where !observation.wasSuccessful {
            for feature in observation.activeFeatures {
                let currentWeight = updated.featureWeights[feature] ?? 0.1
                let learningRate = 0.005
                updated.featureWeights[feature] = max(0, currentWeight - learningRate)
            }
        }

        // Update training history
        var history = updated.trainingHistory
        history.totalObservations += observations.count
        history.successfulSelections += observations.filter { $0.wasSuccessful }.count
        history.failedSelections += observations.filter { !$0.wasSuccessful }.count
        history.lastTrainingDate = Date()

        return ArchitectureSelectionPolicy(
            id: updated.id,
            tenantId: updated.tenantId,
            domain: updated.domain,
            version: updated.version + 1,
            featureWeights: updated.featureWeights,
            taskRoutes: updated.taskRoutes,
            hardConstraints: updated.hardConstraints,
            trainingHistory: history,
            approvedBy: nil  // Requires re-approval
        )
    }

    // MARK: - Policy Analysis

    /// Gets policy statistics.
    public func getPolicyStats(
        tenantId: String,
        domain: SelectionDomain
    ) -> PolicyStats {
        let policy = getPolicy(tenantId: tenantId, domain: domain)

        return PolicyStats(
            policyId: policy.id,
            version: policy.version,
            totalObservations: policy.trainingHistory.totalObservations,
            successRate: policy.trainingHistory.successRate,
            topFeatures: policy.featureWeights.sorted { $0.value > $1.value }.prefix(5).map { $0.key },
            taskRoutesCount: policy.taskRoutes.count,
            constraintsCount: policy.hardConstraints.count
        )
    }
}

/// Result of model selection.
public struct SelectionResult: Sendable {
    public let selectedModel: ModelDescriptor?
    public let score: PolicyScore
    public let alternates: [ModelDescriptor]
    public let policyId: String
    public let policyVersion: Int
}

/// An observation for learning.
public struct SelectionObservation: Sendable, Codable {
    public let id: String
    public let tenantId: String
    public let domain: SelectionDomain
    public let taskKind: InferenceTaskKind
    public let selectedModelId: String
    public let activeFeatures: Set<ArchitectureFeatureKey>
    public let wasSuccessful: Bool
    public let latencyMs: Int
    public let qualityScore: Double?
    public let timestamp: Date

    public init(
        tenantId: String,
        domain: SelectionDomain,
        taskKind: InferenceTaskKind,
        selectedModelId: String,
        activeFeatures: Set<ArchitectureFeatureKey>,
        wasSuccessful: Bool,
        latencyMs: Int,
        qualityScore: Double? = nil
    ) {
        self.id = UUID().uuidString
        self.tenantId = tenantId
        self.domain = domain
        self.taskKind = taskKind
        self.selectedModelId = selectedModelId
        self.activeFeatures = activeFeatures
        self.wasSuccessful = wasSuccessful
        self.latencyMs = latencyMs
        self.qualityScore = qualityScore
        self.timestamp = Date()
    }
}

/// Policy statistics.
public struct PolicyStats: Sendable {
    public let policyId: String
    public let version: Int
    public let totalObservations: Int
    public let successRate: Double
    public let topFeatures: [ArchitectureFeatureKey]
    public let taskRoutesCount: Int
    public let constraintsCount: Int
}

// MARK: - Gremlin Integration for Policy Testing

/// Puzzle builder for testing architecture selection policies.
public struct SelectionPolicyPuzzleBuilder {
    /// Builds a puzzle to test policy correctness.
    public static func build(
        policy: ArchitectureSelectionPolicy,
        testCases: [PolicyTestCase]
    ) -> SelectionPolicyPuzzle {
        SelectionPolicyPuzzle(
            policyId: policy.id,
            tenantId: policy.tenantId,
            testCases: testCases,
            expectedBehaviors: deriveExpectedBehaviors(from: policy)
        )
    }

    private static func deriveExpectedBehaviors(
        from policy: ArchitectureSelectionPolicy
    ) -> [ExpectedBehavior] {
        var behaviors: [ExpectedBehavior] = []

        // Every hard constraint must be respected
        for constraint in policy.hardConstraints {
            behaviors.append(ExpectedBehavior(
                description: "Constraint '\(constraint.name)' must be enforced",
                type: .constraintRespected(constraint.name)
            ))
        }

        // Task routes should be followed when matching
        for route in policy.taskRoutes {
            behaviors.append(ExpectedBehavior(
                description: "Route to \(route.preferredModelFamily) for matching tasks",
                type: .routeFollowed(route.preferredModelFamily)
            ))
        }

        return behaviors
    }
}

/// Puzzle for testing selection policies.
public struct SelectionPolicyPuzzle: Sendable {
    public let policyId: String
    public let tenantId: String
    public let testCases: [PolicyTestCase]
    public let expectedBehaviors: [ExpectedBehavior]
}

/// A test case for policy testing.
public struct PolicyTestCase: Sendable {
    public let id: String
    public let task: InferenceTask
    public let availableModels: [ModelDescriptor]
    public let expectedSelection: String?  // Model ID that should be selected
    public let forbiddenSelections: Set<String>  // Model IDs that should never be selected

    public init(
        id: String = UUID().uuidString,
        task: InferenceTask,
        availableModels: [ModelDescriptor],
        expectedSelection: String? = nil,
        forbiddenSelections: Set<String> = []
    ) {
        self.id = id
        self.task = task
        self.availableModels = availableModels
        self.expectedSelection = expectedSelection
        self.forbiddenSelections = forbiddenSelections
    }
}

/// Expected behavior from a policy.
public struct ExpectedBehavior: Sendable {
    public let description: String
    public let type: ExpectedBehaviorType
}

/// Types of expected behaviors.
public enum ExpectedBehaviorType: Sendable {
    case constraintRespected(String)
    case routeFollowed(String)
    case qualityThreshold(Double)
    case latencyBound(Int)
}

/// Result of policy puzzle evaluation.
public struct PolicyPuzzleResult: Sendable {
    public let policyId: String
    public let passed: Bool
    public let failedCases: [FailedPolicyCase]
    public let violatedBehaviors: [ExpectedBehavior]

    public var isClean: Bool { passed && failedCases.isEmpty }
}

/// A failed policy test case.
public struct FailedPolicyCase: Sendable {
    public let testCaseId: String
    public let reason: String
    public let actualSelection: String?
    public let expectedSelection: String?
}
