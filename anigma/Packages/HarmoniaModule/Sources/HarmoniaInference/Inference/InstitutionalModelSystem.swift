//
//  InstitutionalModelSystem.swift
//  HarmoniaModule
//
//  Implements per-tenant institutional models with:
//  - Machine-readable charters
//  - Governed learning loops with receipts
//  - Federated learning without data hoarding
//  - Gremlin-based ethics committee
//  - Shadow deployment and model democracy
//
//  This is the "bonkers++" level: institutional models behave like
//  small regulated organisms with immune systems, union contracts, and paper trails.
//

@preconcurrency import Foundation
import Foundation
import HarmoniaCore
import AnigmaPrimitives
import InferenceCore
import AnigmaCore

// MARK: - Institutional Model Charter

/// A machine-readable charter that governs what an institutional model can do.
/// Training and serving both read this charter - violations are refused and logged.
struct InstitutionalCharter: Sendable, Codable, Identifiable {
    public let id: String
    public let tenantId: String
    public let name: String
    public let version: String

    /// Domains this model is allowed to touch.
    public let allowedDomains: Set<CharterDomain>

    /// Domains explicitly forbidden.
    public let forbiddenDomains: Set<CharterDomain>

    /// Authoritative legal/policy sources.
    public let authoritativeSources: [AuthoritativeSource]

    /// Things the model must NEVER optimize for.
    public let prohibitedOptimizations: Set<ProhibitedOptimization>

    /// Required approvers for capability changes.
    public let requiredApprovers: [ApproverRole]

    /// Behavioral constraints.
    public let behaviorConstraints: CharterBehaviorConstraints

    /// Ethical guardrails.
    public let ethicalGuardrails: EthicalGuardrails

    /// Audit requirements.
    public let auditRequirements: CharterAuditRequirements

    /// Charter effective dates.
    public let effectiveFrom: Date
    public let effectiveUntil: Date?

    /// Hash of charter for integrity verification.
    public var charterHash: String {
        // In production: cryptographic hash of all fields
        "\(id):\(version):\(tenantId)"
    }

    public init(
        id: String = UUID().uuidString,
        tenantId: String,
        name: String,
        version: String = "1.0.0",
        allowedDomains: Set<CharterDomain>,
        forbiddenDomains: Set<CharterDomain> = [],
        authoritativeSources: [AuthoritativeSource] = [],
        prohibitedOptimizations: Set<ProhibitedOptimization> = [],
        requiredApprovers: [ApproverRole] = [],
        behaviorConstraints: CharterBehaviorConstraints = .default,
        ethicalGuardrails: EthicalGuardrails = .default,
        auditRequirements: CharterAuditRequirements = .default,
        effectiveFrom: Date = Date(),
        effectiveUntil: Date? = nil
    ) {
        self.id = id
        self.tenantId = tenantId
        self.name = name
        self.version = version
        self.allowedDomains = allowedDomains
        self.forbiddenDomains = forbiddenDomains
        self.authoritativeSources = authoritativeSources
        self.prohibitedOptimizations = prohibitedOptimizations
        self.requiredApprovers = requiredApprovers
        self.behaviorConstraints = behaviorConstraints
        self.ethicalGuardrails = ethicalGuardrails
        self.auditRequirements = auditRequirements
        self.effectiveFrom = effectiveFrom
        self.effectiveUntil = effectiveUntil
    }

    /// Validates that an action is permitted under this charter.
    public func validate(action: CharterAction) -> CharterValidationResult {
        var violations: [CharterViolation] = []

        // Check domain permissions
        if !allowedDomains.contains(action.domain) {
            violations.append(.domainNotAllowed(action.domain))
        }
        if forbiddenDomains.contains(action.domain) {
            violations.append(.domainExplicitlyForbidden(action.domain))
        }

        // Check prohibited optimizations
        for optimization in action.impliedOptimizations {
            if prohibitedOptimizations.contains(optimization) {
                violations.append(.prohibitedOptimization(optimization))
            }
        }

        // Check ethical guardrails
        if let ethicalViolation = ethicalGuardrails.check(action) {
            violations.append(.ethicalViolation(ethicalViolation))
        }

        if violations.isEmpty {
            return .permitted(charter: id, version: version)
        } else {
            return .denied(violations: violations)
        }
    }
}

/// Domains a charter can govern.
enum CharterDomain: String, Sendable, Codable, CaseIterable {
    case dspsForms
    case dspsAccommodations
    case dspsAltMedia
    case academicRecords
    case financialAid
    case studentCommunications
    case facultyCommunications
    case complianceReporting
    case generalAssistance
    case medicalDocumentation  // Usually forbidden
    case legalAdvice          // Usually forbidden
}

/// Authoritative sources the model must respect.
struct AuthoritativeSource: Sendable, Codable {
    public let name: String
    public let type: SourceType
    public let uri: String?
    public let version: String?
    public let priority: Int  // Lower = higher priority

    public enum SourceType: String, Sendable, Codable {
        case federalLaw
        case stateLaw
        case institutionalPolicy
        case departmentalProcedure
        case professionalStandard
    }

    public init(
        name: String,
        type: SourceType,
        uri: String? = nil,
        version: String? = nil,
        priority: Int = 100
    ) {
        self.name = name
        self.type = type
        self.uri = uri
        self.version = version
        self.priority = priority
    }
}

/// Things the model must never optimize for.
enum ProhibitedOptimization: String, Sendable, Codable, CaseIterable {
    case reducedBenefits
    case fewerAccommodations
    case shorterAppeals
    case staffConvenience
    case costReduction
    case fasterDenials
    case reducedDocumentation
    case minimizedCompliance
}

/// Roles required to approve charter changes.
enum ApproverRole: String, Sendable, Codable, CaseIterable {
    case dspsLead
    case legalCounsel
    case studentRepresentative
    case accessibilityOfficer
    case privacyOfficer
    case itSecurity
    case institutionalAdmin
}

/// Behavioral constraints from charter.
struct CharterBehaviorConstraints: Sendable, Codable {
    public var requireHumanReviewAboveRisk: Double
    public var maxAutonomousDecisions: Int
    public var requireExplanationForAll: Bool
    public var allowAutomatedDenials: Bool
    public var maxConfidenceWithoutVerification: Double

    public init(
        requireHumanReviewAboveRisk: Double = 0.7,
        maxAutonomousDecisions: Int = 10,
        requireExplanationForAll: Bool = true,
        allowAutomatedDenials: Bool = false,
        maxConfidenceWithoutVerification: Double = 0.6
    ) {
        self.requireHumanReviewAboveRisk = requireHumanReviewAboveRisk
        self.maxAutonomousDecisions = maxAutonomousDecisions
        self.requireExplanationForAll = requireExplanationForAll
        self.allowAutomatedDenials = allowAutomatedDenials
        self.maxConfidenceWithoutVerification = maxConfidenceWithoutVerification
    }

    public static let `default` = CharterBehaviorConstraints()
    public static let strict = CharterBehaviorConstraints(
        requireHumanReviewAboveRisk: 0.3,
        maxAutonomousDecisions: 3,
        allowAutomatedDenials: false,
        maxConfidenceWithoutVerification: 0.4
    )
}

/// Ethical guardrails.
struct EthicalGuardrails: Sendable, Codable {
    public var neverDiscourageAppeals: Bool
    public var alwaysOfferAlternatives: Bool
    public var protectVulnerablePopulations: Bool
    public var preventBiasAmplification: Bool
    public var requireAccessibilityConsideration: Bool

    public init(
        neverDiscourageAppeals: Bool = true,
        alwaysOfferAlternatives: Bool = true,
        protectVulnerablePopulations: Bool = true,
        preventBiasAmplification: Bool = true,
        requireAccessibilityConsideration: Bool = true
    ) {
        self.neverDiscourageAppeals = neverDiscourageAppeals
        self.alwaysOfferAlternatives = alwaysOfferAlternatives
        self.protectVulnerablePopulations = protectVulnerablePopulations
        self.preventBiasAmplification = preventBiasAmplification
        self.requireAccessibilityConsideration = requireAccessibilityConsideration
    }

    public static let `default` = EthicalGuardrails()

    /// Checks an action against guardrails.
    public func check(_ action: CharterAction) -> String? {
        if neverDiscourageAppeals && action.discoursesAppeals {
            return "Action would discourage appeals"
        }
        if protectVulnerablePopulations && action.negativelyImpactsVulnerable {
            return "Action negatively impacts vulnerable population"
        }
        return nil
    }
}

/// Audit requirements from charter.
struct CharterAuditRequirements: Sendable, Codable {
    public var logAllDecisions: Bool
    public var retainLogsYears: Int
    public var requireExplanationArtifacts: Bool
    public var enableProvenanceTracking: Bool
    public var periodicReviewInterval: TimeInterval

    public init(
        logAllDecisions: Bool = true,
        retainLogsYears: Int = 7,
        requireExplanationArtifacts: Bool = true,
        enableProvenanceTracking: Bool = true,
        periodicReviewInterval: TimeInterval = 90 * 24 * 3600  // 90 days
    ) {
        self.logAllDecisions = logAllDecisions
        self.retainLogsYears = retainLogsYears
        self.requireExplanationArtifacts = requireExplanationArtifacts
        self.enableProvenanceTracking = enableProvenanceTracking
        self.periodicReviewInterval = periodicReviewInterval
    }

    public static let `default` = CharterAuditRequirements()
}

/// An action to validate against the charter.
struct CharterAction: Sendable {
    public let domain: CharterDomain
    public let actionType: String
    public let impliedOptimizations: Set<ProhibitedOptimization>
    public let riskLevel: Double
    public let discoursesAppeals: Bool
    public let negativelyImpactsVulnerable: Bool

    public init(
        domain: CharterDomain,
        actionType: String,
        impliedOptimizations: Set<ProhibitedOptimization> = [],
        riskLevel: Double = 0.5,
        discoursesAppeals: Bool = false,
        negativelyImpactsVulnerable: Bool = false
    ) {
        self.domain = domain
        self.actionType = actionType
        self.impliedOptimizations = impliedOptimizations
        self.riskLevel = riskLevel
        self.discoursesAppeals = discoursesAppeals
        self.negativelyImpactsVulnerable = negativelyImpactsVulnerable
    }
}

/// Result of charter validation.
enum CharterValidationResult: Sendable {
    case permitted(charter: String, version: String)
    case denied(violations: [CharterViolation])

    public var isPermitted: Bool {
        if case .permitted = self { return true }
        return false
    }
}

/// Types of charter violations.
enum CharterViolation: Sendable {
    case domainNotAllowed(CharterDomain)
    case domainExplicitlyForbidden(CharterDomain)
    case prohibitedOptimization(ProhibitedOptimization)
    case ethicalViolation(String)
    case missingApproval(ApproverRole)
    case charterExpired
}

// MARK: - Provenance Tracking

/// Tracks where model updates came from (receipts and blame).
struct InstitutionalModelProvenance: Sendable, Codable, Identifiable {
    public let id: String
    public let modelId: String
    public let updateType: ProvenanceUpdateType
    public let sources: [ProvenanceSource]
    public let contributionWeights: [String: Double]
    public let timestamp: Date
    public let charterVersion: String

    public init(
        id: String = UUID().uuidString,
        modelId: String,
        updateType: ProvenanceUpdateType,
        sources: [ProvenanceSource],
        contributionWeights: [String: Double] = [:],
        charterVersion: String
    ) {
        self.id = id
        self.modelId = modelId
        self.updateType = updateType
        self.sources = sources
        self.contributionWeights = contributionWeights
        self.timestamp = Date()
        self.charterVersion = charterVersion
    }
}

/// Type of provenance update.
enum ProvenanceUpdateType: String, Sendable, Codable {
    case initialTraining
    case finetuning
    case upftPrefixLearning
    case reinforcementLearning
    case federatedUpdate
    case rollback
}

/// A source that contributed to model behavior.
struct ProvenanceSource: Sendable, Codable {
    public let sourceId: String
    public let sourceType: ProvenanceSourceType
    public let description: String
    public let weight: Double
    public let verifiedBy: String?

    public init(
        sourceId: String,
        sourceType: ProvenanceSourceType,
        description: String,
        weight: Double,
        verifiedBy: String? = nil
    ) {
        self.sourceId = sourceId
        self.sourceType = sourceType
        self.description = description
        self.weight = weight
        self.verifiedBy = verifiedBy
    }
}

/// Types of provenance sources.
enum ProvenanceSourceType: String, Sendable, Codable {
    case policyDocument
    case interactionTrace
    case syntheticExample
    case curatedExemplar
    case federatedAggregate
    case externalCorpus
}

// MARK: - Institutional Model Bundle

/// A complete institutional model bundle with all components.
struct InstitutionalModelBundle: Sendable, Codable, Identifiable {
    public let id: String
    public let tenantId: String
    public let charter: InstitutionalCharter

    /// Component models in this bundle.
    public let components: InstitutionalModelComponents

    /// Current deployment status.
    public var deploymentStatus: DeploymentStatus

    /// Provenance chain for this bundle.
    public let provenanceChain: [InstitutionalModelProvenance]

    /// Evaluation metrics.
    public var evaluationMetrics: InstitutionalModelMetrics

    /// Version info.
    public let version: String
    public let createdAt: Date
    public var lastUpdated: Date

    public init(
        id: String = UUID().uuidString,
        tenantId: String,
        charter: InstitutionalCharter,
        components: InstitutionalModelComponents,
        deploymentStatus: DeploymentStatus = .shadow,
        provenanceChain: [InstitutionalModelProvenance] = [],
        evaluationMetrics: InstitutionalModelMetrics = .empty,
        version: String = "1.0.0"
    ) {
        self.id = id
        self.tenantId = tenantId
        self.charter = charter
        self.components = components
        self.deploymentStatus = deploymentStatus
        self.provenanceChain = provenanceChain
        self.evaluationMetrics = evaluationMetrics
        self.version = version
        self.createdAt = Date()
        self.lastUpdated = Date()
    }
}

/// Components of an institutional model.
struct InstitutionalModelComponents: Sendable, Codable {
    /// Main LLM adapter (LoRA or similar).
    public let primaryAdapter: AdapterReference?

    /// TRM-style small reasoning model.
    public let reasoningModel: ModelReference?

    /// Domain-specific prompt templates.
    public let promptTemplates: [String: String]

    /// Symbolic rules that complement the neural components.
    public let symbolicRules: [SymbolicRule]

    public init(
        primaryAdapter: AdapterReference? = nil,
        reasoningModel: ModelReference? = nil,
        promptTemplates: [String: String] = [:],
        symbolicRules: [SymbolicRule] = []
    ) {
        self.primaryAdapter = primaryAdapter
        self.reasoningModel = reasoningModel
        self.promptTemplates = promptTemplates
        self.symbolicRules = symbolicRules
    }
}

/// Reference to an adapter.
struct AdapterReference: Sendable, Codable {
    public let adapterId: String
    public let baseModelId: String
    public let path: String
    public let rank: Int  // LoRA rank

    public init(
        adapterId: String,
        baseModelId: String,
        path: String,
        rank: Int = 16
    ) {
        self.adapterId = adapterId
        self.baseModelId = baseModelId
        self.path = path
        self.rank = rank
    }
}

/// Reference to a model.
struct ModelReference: Sendable, Codable {
    public let modelId: String
    public let path: String
    public let parameterCount: Int

    public init(modelId: String, path: String, parameterCount: Int) {
        self.modelId = modelId
        self.path = path
        self.parameterCount = parameterCount
    }
}

/// A symbolic rule that complements neural components.
struct SymbolicRule: Sendable, Codable {
    public let ruleId: String
    public let domain: CharterDomain
    public let condition: String  // Simple DSL or predicate
    public let action: String
    public let priority: Int

    public init(
        ruleId: String,
        domain: CharterDomain,
        condition: String,
        action: String,
        priority: Int = 100
    ) {
        self.ruleId = ruleId
        self.domain = domain
        self.condition = condition
        self.action = action
        self.priority = priority
    }
}

/// Deployment status for institutional model.
enum DeploymentStatus: String, Sendable, Codable {
    case development
    case shadow       // Running alongside primary, not affecting users
    case canary       // Affecting small subset of requests
    case primary      // Main production model
    case deprecated   // Scheduled for removal
    case rolled_back  // Rolled back due to issues
}

/// Metrics for institutional model.
struct InstitutionalModelMetrics: Sendable, Codable {
    public var accuracyOnDomain: [CharterDomain: Double]
    public var userOverrideRate: Double
    public var appealOutcomeCorrelation: Double  // How often model suggestions align with appeal outcomes
    public var charterViolationAttempts: Int
    public var gremlinPassRate: Double
    public var shadowWinRate: Double?  // Only for shadow deployments

    public static let empty = InstitutionalModelMetrics(
        accuracyOnDomain: [:],
        userOverrideRate: 0,
        appealOutcomeCorrelation: 0,
        charterViolationAttempts: 0,
        gremlinPassRate: 1.0,
        shadowWinRate: nil
    )

    public init(
        accuracyOnDomain: [CharterDomain: Double],
        userOverrideRate: Double,
        appealOutcomeCorrelation: Double,
        charterViolationAttempts: Int,
        gremlinPassRate: Double,
        shadowWinRate: Double?
    ) {
        self.accuracyOnDomain = accuracyOnDomain
        self.userOverrideRate = userOverrideRate
        self.appealOutcomeCorrelation = appealOutcomeCorrelation
        self.charterViolationAttempts = charterViolationAttempts
        self.gremlinPassRate = gremlinPassRate
        self.shadowWinRate = shadowWinRate
    }
}

// MARK: - Institutional Model Service

/// Service for managing institutional models.
actor InstitutionalModelService {
    /// Active bundles by tenant.
    private var bundlesByTenant: [String: [InstitutionalModelBundle]] = [:]

    /// Active charters by tenant.
    private var chartersByTenant: [String: InstitutionalCharter] = [:]

    /// Provenance records.
    private var provenanceRecords: [InstitutionalModelProvenance] = []

    /// Shadow deployment comparisons.
    private var shadowComparisons: [ShadowComparison] = []

    /// Learning impact measurer integration.
    private let learningMeasurer: LearningImpactMeasurer

    public init(learningMeasurer: LearningImpactMeasurer) {
        self.learningMeasurer = learningMeasurer
    }

    // MARK: - Charter Management

    /// Registers a charter for a tenant.
    public func registerCharter(_ charter: InstitutionalCharter) {
        chartersByTenant[charter.tenantId] = charter
    }

    /// Gets the active charter for a tenant.
    public func getCharter(for tenantId: String) -> InstitutionalCharter? {
        chartersByTenant[tenantId]
    }

    /// Validates an action against the tenant's charter.
    public func validateAction(
        _ action: CharterAction,
        for tenantId: String
    ) -> CharterValidationResult {
        guard let charter = chartersByTenant[tenantId] else {
            return .denied(violations: [.charterExpired])
        }
        return charter.validate(action: action)
    }

    // MARK: - Bundle Management

    /// Registers a model bundle.
    public func registerBundle(_ bundle: InstitutionalModelBundle) {
        var bundles = bundlesByTenant[bundle.tenantId] ?? []
        bundles.append(bundle)
        bundlesByTenant[bundle.tenantId] = bundles
    }

    /// Gets the primary bundle for a tenant.
    public func getPrimaryBundle(for tenantId: String) -> InstitutionalModelBundle? {
        bundlesByTenant[tenantId]?.first { $0.deploymentStatus == .primary }
    }

    /// Gets all bundles for a tenant.
    public func getBundles(for tenantId: String) -> [InstitutionalModelBundle] {
        bundlesByTenant[tenantId] ?? []
    }

    // MARK: - Shadow Deployment

    /// Records a shadow comparison.
    public func recordShadowComparison(_ comparison: ShadowComparison) {
        shadowComparisons.append(comparison)

        // Update bundle metrics
        if var bundles = bundlesByTenant[comparison.tenantId] {
            if let index = bundles.firstIndex(where: { $0.id == comparison.shadowBundleId }) {
                var bundle = bundles[index]

                // Calculate win rate
                let shadowWins = shadowComparisons
                    .filter { $0.shadowBundleId == bundle.id }
                    .filter { $0.shadowWon }
                let total = shadowComparisons.filter { $0.shadowBundleId == bundle.id }.count

                bundle.evaluationMetrics.shadowWinRate = total > 0
                    ? Double(shadowWins.count) / Double(total)
                    : nil
                bundle.lastUpdated = Date()
                bundles[index] = bundle
                bundlesByTenant[comparison.tenantId] = bundles
            }
        }
    }

    /// Evaluates if a shadow bundle should be promoted.
    public func evaluatePromotion(bundleId: String) -> PromotionDecision {
        for (tenantId, bundles) in bundlesByTenant {
            guard let bundle = bundles.first(where: { $0.id == bundleId }) else {
                continue
            }

            guard bundle.deploymentStatus == .shadow else {
                return .notEligible(reason: "Bundle is not in shadow status")
            }

            // Check shadow win rate
            guard let winRate = bundle.evaluationMetrics.shadowWinRate,
                  winRate > 0.6 else {
                return .notReady(reason: "Shadow win rate below threshold")
            }

            // Check gremlin pass rate
            guard bundle.evaluationMetrics.gremlinPassRate > 0.95 else {
                return .notReady(reason: "Gremlin pass rate below threshold")
            }

            // Check charter violation attempts
            guard bundle.evaluationMetrics.charterViolationAttempts < 5 else {
                return .rejected(reason: "Too many charter violation attempts")
            }

            return .readyForPromotion(
                bundleId: bundleId,
                tenantId: tenantId,
                metrics: bundle.evaluationMetrics
            )
        }

        return .notEligible(reason: "Bundle not found")
    }

    // MARK: - Learning Integration

    /// Submits a trace for potential learning (goes through full governance).
    public func submitForLearning(
        trace: ReasoningTrace,
        tenantId: String,
        userConsent: LearningConsent
    ) async -> LearningSubmissionResult {
        // Check charter allows learning
        guard let charter = chartersByTenant[tenantId] else {
            return .rejected(reason: "No charter found")
        }

        // Check consent
        guard userConsent.allowsLearning else {
            return .rejected(reason: "User did not consent to learning")
        }

        // Check domain is allowed
        guard charter.allowedDomains.contains(
            CharterDomain(rawValue: trace.domain.rawValue) ?? .generalAssistance
        ) else {
            return .rejected(reason: "Domain not allowed by charter")
        }

        // Check quality
        guard trace.quality.meetsQualityBar else {
            return .rejected(reason: "Trace quality below bar")
        }

        // Record the trace
        await learningMeasurer.record(trace)

        return .accepted(traceId: trace.id)
    }
}

/// Comparison between shadow and primary model.
struct ShadowComparison: Sendable, Codable {
    public let id: String
    public let tenantId: String
    public let shadowBundleId: String
    public let primaryBundleId: String
    public let taskType: String
    public let shadowWon: Bool
    public let metrics: ComparisonMetrics
    public let timestamp: Date

    public init(
        tenantId: String,
        shadowBundleId: String,
        primaryBundleId: String,
        taskType: String,
        shadowWon: Bool,
        metrics: ComparisonMetrics
    ) {
        self.id = UUID().uuidString
        self.tenantId = tenantId
        self.shadowBundleId = shadowBundleId
        self.primaryBundleId = primaryBundleId
        self.taskType = taskType
        self.shadowWon = shadowWon
        self.metrics = metrics
        self.timestamp = Date()
    }
}

/// Metrics for comparing models.
struct ComparisonMetrics: Sendable, Codable {
    public let shadowLatency: TimeInterval
    public let primaryLatency: TimeInterval
    public let shadowCorrect: Bool
    public let primaryCorrect: Bool
    public let userPreferredShadow: Bool?

    public init(
        shadowLatency: TimeInterval,
        primaryLatency: TimeInterval,
        shadowCorrect: Bool,
        primaryCorrect: Bool,
        userPreferredShadow: Bool?
    ) {
        self.shadowLatency = shadowLatency
        self.primaryLatency = primaryLatency
        self.shadowCorrect = shadowCorrect
        self.primaryCorrect = primaryCorrect
        self.userPreferredShadow = userPreferredShadow
    }
}

/// Decision about promoting a model.
enum PromotionDecision: Sendable {
    case readyForPromotion(bundleId: String, tenantId: String, metrics: InstitutionalModelMetrics)
    case notReady(reason: String)
    case notEligible(reason: String)
    case rejected(reason: String)
}

/// User consent for learning.
struct LearningConsent: Sendable, Codable {
    public let allowsLearning: Bool
    public let scope: LearningScope
    public let restrictions: Set<LearningRestriction>

    public init(
        allowsLearning: Bool,
        scope: LearningScope = .institutionOnly,
        restrictions: Set<LearningRestriction> = []
    ) {
        self.allowsLearning = allowsLearning
        self.scope = scope
        self.restrictions = restrictions
    }
}

/// Scope of learning consent.
enum LearningScope: String, Sendable, Codable {
    case institutionOnly
    case federatedAnonymized
    case none
}

/// Restrictions on learning.
enum LearningRestriction: String, Sendable, Codable {
    case noDecisionSuggestions
    case explanersOnly
    case noCaseContent
}

/// Result of learning submission.
enum LearningSubmissionResult: Sendable {
    case accepted(traceId: String)
    case rejected(reason: String)
    case deferred(reason: String)
}
