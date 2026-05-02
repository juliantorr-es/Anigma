//
//  VersionedDoctrinePacks.swift
//  HarmoniaModule
//
//  Versioned doctrine packs with explicit, checkable invariants.
//  Not vibes - actual rules with versioning and upgrade paths.
//

@preconcurrency import Foundation
import Foundation
import HarmoniaCore
import AnigmaCore
import AnigmaPrimitives
import DoctrineCore

// MARK: - Versioned Doctrine Pack Protocol

/// A versioned collection of doctrine rules that can be enforced.
public protocol VersionedDoctrinePack: Sendable {
    /// Unique identifier for this pack.
    var id: String { get }

    /// Human-readable name.
    var name: String { get }

    /// Semantic version (e.g., "1.0.0").
    var version: String { get }

    /// Doctrine domain this pack belongs to.
    var domain: DoctrineDomain { get }

    /// All rules in this pack.
    var rules: [DoctrineRule] { get }

    /// Whether this pack is enabled by default.
    var enabledByDefault: Bool { get }

    /// Minimum trust tier required to override rules.
    var minimumTrustTierForOverride: TrustTier { get }

    /// Get rule by ID.
    func rule(withId id: String) -> DoctrineRule?

    /// Check if a rule can be overridden at given trust tier.
    func canOverride(ruleId: String, at trustTier: TrustTier) -> Bool
}

// MARK: - Computer Science Doctrine Pack v1

/// Computer Science Doctrine Pack v1.0.0
/// Basic complexity and concurrency sanity rules.
public struct CSDoctrinePackV1: VersionedDoctrinePack {
    public let id = "cs-doctrine-v1"
    public let name = "Computer Science Doctrine v1"
    public let version = "1.0.0"
    public let domain: DoctrineDomain = .computerScience
    public let enabledByDefault = true
    public let minimumTrustTierForOverride: TrustTier = .gold

    public let rules: [DoctrineRule] = [
        // CS-001: No unbounded O(n²) in hot loops
        DoctrineRule(
            id: "cs-001",
            title: "No unbounded quadratic complexity in hot loops",
            description: "Hot loops (executed >1000 times) must not contain unbounded O(n²) operations.",
            severity: DoctrineCore.DoctrineSeverity.error,
            implementation: DoctrineRule.RuleImplementation.astPattern,
            parameters: [
                "max_iterations": "1000",
                "complexity_threshold": "quadratic"
            ],
            blocking: true,
            source: "ACM/IEEE CS Curriculum 2013 - Algorithm Analysis"
        ),

        // CS-002: No shared mutable state across actor boundaries
        DoctrineRule(
            id: "cs-002",
            title: "No shared mutable state across actor boundaries",
            description: "Mutable state must not be shared between actors without proper synchronization.",
            severity: DoctrineCore.DoctrineSeverity.critical,
            implementation: DoctrineRule.RuleImplementation.astPattern,
            parameters: [
                "actor_keywords": "actor,Actor,@MainActor",
                "mutable_keywords": "var,mutating,inout"
            ],
            blocking: true,
            source: "Swift Concurrency Manifesto - Actor Isolation"
        ),

        // CS-003: No sync-over-async deadlock patterns
        DoctrineRule(
            id: "cs-003",
            title: "No sync-over-async deadlock patterns",
            description: "Synchronous code must not call async code without proper handling.",
            severity: DoctrineCore.DoctrineSeverity.error,
            implementation: DoctrineRule.RuleImplementation.astPattern,
            parameters: [
                "sync_patterns": "DispatchQueue.sync,semaphore.wait",
                "async_patterns": "await,async,Task"
            ],
            blocking: false,
            source: "Swift Concurrency - Avoiding Deadlocks"
        ),

        // CS-004: Resource bounds must be declared
        DoctrineRule(
            id: "cs-004",
            title: "Resource bounds must be declared",
            description: "Functions that allocate memory or other resources must declare bounds.",
            severity: DoctrineCore.DoctrineSeverity.warning,
            implementation: DoctrineRule.RuleImplementation.filePattern,
            parameters: [
                "resource_keywords": "malloc,alloc,Array.init,Data.init",
                "annotation": "@ResourceBound"
            ],
            blocking: false,
            source: "IEEE Software Engineering Standards - Resource Management"
        ),

        // CS-005: No magic numbers in algorithms
        DoctrineRule(
            id: "cs-005",
            title: "No magic numbers in algorithms",
            description: "Algorithmic constants must be named and documented.",
            severity: DoctrineCore.DoctrineSeverity.warning,
            implementation: DoctrineRule.RuleImplementation.astPattern,
            parameters: [
                "numeric_patterns": "0.05,0.01,1000,1024",
                "exceptions": "0,1,2,-1"
            ],
            blocking: false,
            source: "Clean Code - Meaningful Names"
        )
    ]

    public func rule(withId id: String) -> DoctrineRule? {
        rules.first { $0.id == id }
    }

    public func canOverride(ruleId: String, at trustTier: TrustTier) -> Bool {
        guard let rule = rule(withId: ruleId) else { return false }

        // Critical rules cannot be overridden below gold tier
        if rule.severity == .critical && trustTier < .gold {
            return false
        }

        // Error rules require at least silver
        if rule.severity == .error && trustTier < .silver {
            return false
        }

        return trustTier >= minimumTrustTierForOverride
    }
}

// MARK: - Statistics Doctrine Pack v1

/// Statistics Doctrine Pack v1.0.0
/// Basic statistical integrity and ethics rules.
public struct StatisticsDoctrinePackV1: VersionedDoctrinePack {
    public let id = "stats-doctrine-v1"
    public let name = "Statistics Doctrine v1"
    public let version = "1.0.0"
    public let domain: DoctrineDomain = .statistics
    public let enabledByDefault = true
    public let minimumTrustTierForOverride: TrustTier = .platinum

    public let rules: [DoctrineRule] = [
        // STATS-001: No unlabeled p-values
        DoctrineRule(
            id: "stats-001",
            title: "No unlabeled p-values",
            description: "Statistical tests must label p-values with the test used and hypothesis.",
            severity: DoctrineCore.DoctrineSeverity.error,
            implementation: DoctrineRule.RuleImplementation.astPattern,
            parameters: [
                "pvalue_patterns": "p <,p>,p=,p-value",
                "required_annotations": "@Hypothesis,@Test"
            ],
            blocking: true,
            source: "ASA Statement on p-Values - Transparency"
        ),

        // STATS-002: No training on evaluation data
        DoctrineRule(
            id: "stats-002",
            title: "No training on evaluation data",
            description: "Models must not be trained on data used for evaluation.",
            severity: DoctrineCore.DoctrineSeverity.critical,
            implementation: DoctrineRule.RuleImplementation.dataFlow,
            parameters: [
                "train_keywords": "fit,train,learn",
                "eval_keywords": "test,evaluate,score",
                "dataset_annotation": "@DatasetRole"
            ],
            blocking: true,
            source: "ML Ethics - Data Leakage Prevention"
        ),

        // STATS-003: Uncertainty must be quantified
        DoctrineRule(
            id: "stats-003",
            title: "Uncertainty must be quantified",
            description: "Statistical estimates must include uncertainty measures (CI, SE, etc.).",
            severity: DoctrineCore.DoctrineSeverity.error,
            implementation: DoctrineRule.RuleImplementation.astPattern,
            parameters: [
                "estimate_keywords": "mean,median,proportion,correlation",
                "uncertainty_keywords": "confidence interval,standard error,margin of error"
            ],
            blocking: false,
            source: "ASA Guidelines - Uncertainty Communication"
        ),

        // STATS-004: No multiple testing without correction
        DoctrineRule(
            id: "stats-004",
            title: "No multiple testing without correction",
            description: "Multiple hypothesis tests require correction (Bonferroni, FDR, etc.).",
            severity: DoctrineCore.DoctrineSeverity.warning,
            implementation: DoctrineRule.RuleImplementation.astPattern,
            parameters: [
                "test_keywords": "t.test,chi.square,anova",
                "correction_annotation": "@MultipleTestingCorrection"
            ],
            blocking: false,
            source: "Multiple Comparisons Problem - Statistical Ethics"
        ),

        // STATS-005: Sample size justification required
        DoctrineRule(
            id: "stats-005",
            title: "Sample size justification required",
            description: "Studies must justify sample size (power analysis, feasibility).",
            severity: DoctrineCore.DoctrineSeverity.warning,
            implementation: DoctrineRule.RuleImplementation.filePattern,
            parameters: [
                "sample_keywords": "n=,sample size,participants",
                "justification_annotation": "@SampleSizeJustification"
            ],
            blocking: false,
            source: "Research Ethics - Adequate Power"
        )
    ]

    public func rule(withId id: String) -> DoctrineRule? {
        rules.first { $0.id == id }
    }

    public func canOverride(ruleId: String, at trustTier: TrustTier) -> Bool {
        // Statistics rules are strict - only platinum can override
        return trustTier >= .platinum
    }
}

// MARK: - Law/Compliance Doctrine Pack v1

/// Law/Compliance Doctrine Pack v1.0.0
/// Basic privacy and accessibility rules.
public struct LawComplianceDoctrinePackV1: VersionedDoctrinePack {
    public let id = "law-doctrine-v1"
    public let name = "Law/Compliance Doctrine v1"
    public let version = "1.0.0"
    public let domain: DoctrineDomain = .lawCompliance
    public let enabledByDefault = true
    public let minimumTrustTierForOverride: TrustTier = .platinum

    public let rules: [DoctrineRule] = [
        // LAW-PII-001: PII must be classified
        DoctrineRule(
            id: "law-pii-001",
            title: "PII must be classified",
            description: "Personally Identifiable Information must have explicit classification.",
            severity: DoctrineCore.DoctrineSeverity.critical,
            implementation: DoctrineRule.RuleImplementation.astPattern,
            parameters: [
                "pii_patterns": "email,phone,ssn,address,dob",
                "classification_annotation": "@DataClassification"
            ],
            blocking: true,
            source: "GDPR Article 5 - Data Minimization"
        ),

        // LAW-PII-002: No raw PII in logs
        DoctrineRule(
            id: "law-pii-002",
            title: "No raw PII in logs",
            description: "PII must be masked or tokenized in logs.",
            severity: DoctrineCore.DoctrineSeverity.error,
            implementation: DoctrineRule.RuleImplementation.filePattern,
            parameters: [
                "log_functions": "log,debug,info,error,print",
                "pii_patterns": "email,phone,ssn"
            ],
            blocking: true,
            source: "GDPR Article 32 - Security of Processing"
        ),

        // LAW-ACC-001: Timeouts must be accessible
        DoctrineRule(
            id: "law-acc-001",
            title: "Timeouts must be accessible",
            description: "User interactions must have sufficient time limits (≥5 seconds).",
            severity: DoctrineCore.DoctrineSeverity.warning,
            implementation: DoctrineRule.RuleImplementation.astPattern,
            parameters: [
                "timeout_keywords": "timeout,delay,Timer,sleep",
                "minimum_seconds": "5.0"
            ],
            blocking: false,
            source: "WCAG 2.1 Success Criterion 2.2.1"
        ),

        // LAW-ACC-002: Images must have alt text
        DoctrineRule(
            id: "law-acc-002",
            title: "Images must have alt text",
            description: "UI images must have accessibility labels.",
            severity: DoctrineCore.DoctrineSeverity.error,
            implementation: DoctrineRule.RuleImplementation.astPattern,
            parameters: [
                "image_patterns": "Image,AsyncImage,img src",
                "accessibility_attributes": "accessibilityLabel,alt,aria-label"
            ],
            blocking: false,
            source: "WCAG 2.1 Success Criterion 1.1.1"
        ),

        // LAW-CONSENT-001: Data processing requires legal basis
        DoctrineRule(
            id: "law-consent-001",
            title: "Data processing requires legal basis",
            description: "Processing personal data requires declared legal basis.",
            severity: DoctrineCore.DoctrineSeverity.critical,
            implementation: DoctrineRule.RuleImplementation.filePattern,
            parameters: [
                "processing_verbs": "process,collect,store,share,transfer",
                "basis_annotation": "@LegalBasis"
            ],
            blocking: true,
            source: "GDPR Article 6 - Lawfulness of Processing"
        )
    ]

    public func rule(withId id: String) -> DoctrineRule? {
        rules.first { $0.id == id }
    }

    public func canOverride(ruleId: String, at trustTier: TrustTier) -> Bool {
        // Law rules are very strict - only platinum can override, and only non-critical
        guard let rule = rule(withId: ruleId) else { return false }

        if rule.severity == .critical {
            return false  // Critical law rules cannot be overridden
        }

        return trustTier >= .platinum
    }
}

// MARK: - Doctrine Rule

/// A single enforceable doctrine rule.
public struct DoctrineRule: Sendable, Codable {
    public let id: String
    public let title: String
    public let description: String
    public let severity: DoctrineSeverity
    public let implementation: RuleImplementation
    public let parameters: [String: String]
    public let blocking: Bool
    public let source: String
    public let domain: DoctrineDomain
    public let enabled: Bool
    public let minimumTrustTier: TrustTier

    public enum RuleImplementation: String, Sendable, Codable {
        case astPattern = "ast_pattern"
        case filePattern = "file_pattern"
        case testCoverage = "test_coverage"
        case dataFlow = "data_flow"
        case configuration = "configuration"
    }

    public init(
        id: String,
        title: String,
        description: String,
        severity: DoctrineSeverity,
        implementation: RuleImplementation,
        parameters: [String: String] = [:],
        blocking: Bool = false,
        source: String,
        domain: DoctrineDomain = .softwareEngineering,
        enabled: Bool = true,
        minimumTrustTier: TrustTier = .bronze
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.severity = severity
        self.implementation = implementation
        self.parameters = parameters
        self.blocking = blocking
        self.source = source
        self.domain = domain
        self.enabled = enabled
        self.minimumTrustTier = minimumTrustTier
    }
}

// MARK: - Doctrine Pack Registry

/// Registry for versioned doctrine packs.
public actor DoctrinePackRegistry {
    private var packs: [String: any VersionedDoctrinePack] = [:]

    public init() {}

    /// Register a doctrine pack.
    public func register(_ pack: any VersionedDoctrinePack) {
        packs[pack.id] = pack
    }

    /// Get all packs for a domain.
    public func packs(for domain: DoctrineDomain) -> [any VersionedDoctrinePack] {
        packs.values.filter { $0.domain == domain }
    }

    /// Get pack by ID.
    public func pack(withId id: String) -> (any VersionedDoctrinePack)? {
        packs[id]
    }

    /// Get all enabled packs.
    public func enabledPacks() -> [any VersionedDoctrinePack] {
        packs.values.filter { $0.enabledByDefault }
    }

    /// Check if a rule can be overridden.
    public func canOverride(ruleId: String, at trustTier: TrustTier) -> Bool {
        for pack in packs.values {
            if pack.rule(withId: ruleId) != nil {
                return pack.canOverride(ruleId: ruleId, at: trustTier)
            }
        }
        return false
    }

    /// Registers the default doctrine packs within the actor context.
    public func bootstrapDefaultPacks() {
        registerDefaultPacks()
    }

    private func registerDefaultPacks() {
        register(CSDoctrinePackV1())
        register(StatisticsDoctrinePackV1())
        register(LawComplianceDoctrinePackV1())
    }
}
