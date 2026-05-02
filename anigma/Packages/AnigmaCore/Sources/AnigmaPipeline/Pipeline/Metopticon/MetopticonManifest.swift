//
//  MetopticonManifest.swift
//  AnigmaCore
//
//  The Metopticon Ethics Manifest - machine-readable governance charter.
//
//  This manifest defines what Metopticon is, what it tracks, what it does not,
//  and the technical guarantees that make those promises enforceable.
//
//  The name "Metopticon" is a deliberate counter-reference to the panopticon:
//  - Meta (μετά): beyond, about, concerning
//  - Opticon: observation/sight
//  - Together: "observation about observation" - watching infrastructure, not individuals
//
//  Core principle: expose infrastructure behavior, not individual behavior.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import ContractsCore
import InferenceCore
import Foundation

// MARK: - Ethics Manifest

/// The complete Metopticon ethics and governance manifest.
public struct MetopticonManifest: Codable, Sendable {

    /// Version of this manifest
    public let version: String

    /// When this manifest was last updated
    public let lastUpdated: Date

    /// The preamble explaining what Metopticon is
    public let preamble: String

    /// Core principles
    public let principles: [Principle]

    /// Technical guarantees
    public let technicalGuarantees: [TechnicalGuarantee]

    /// What is collected
    public let dataCollected: [DataCategory]

    /// What is explicitly not collected
    public let dataNotCollected: [ExcludedData]

    /// Allowed uses
    public let allowedUses: [AllowedUse]

    /// Prohibited uses
    public let prohibitedUses: [ProhibitedUse]

    /// Retention policies
    public let retentionPolicies: [MetopticonRetentionPolicy]

    /// Governance structure
    public let governance: GovernanceStructure

    /// Static default manifest
    public static let current = MetopticonManifest.defaultManifest()

    public init(
        version: String,
        lastUpdated: Date,
        preamble: String,
        principles: [Principle],
        technicalGuarantees: [TechnicalGuarantee],
        dataCollected: [DataCategory],
        dataNotCollected: [ExcludedData],
        allowedUses: [AllowedUse],
        prohibitedUses: [ProhibitedUse],
        retentionPolicies: [MetopticonRetentionPolicy],
        governance: GovernanceStructure
    ) {
        self.version = version
        self.lastUpdated = lastUpdated
        self.preamble = preamble
        self.principles = principles
        self.technicalGuarantees = technicalGuarantees
        self.dataCollected = dataCollected
        self.dataNotCollected = dataNotCollected
        self.allowedUses = allowedUses
        self.prohibitedUses = prohibitedUses
        self.retentionPolicies = retentionPolicies
        self.governance = governance
    }
}

// MARK: - Principles

/// A core ethical principle.
public struct Principle: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let rationale: String

    public init(id: String, name: String, description: String, rationale: String) {
        self.id = id
        self.name = name
        self.description = description
        self.rationale = rationale
    }
}

// MARK: - Technical Guarantees

/// A technical guarantee enforced in code.
public struct TechnicalGuarantee: Codable, Sendable, Identifiable {
    public let id: String
    public let guarantee: String
    public let implementation: String
    public let verifiable: Bool
    public let verificationMethod: String?

    public init(
        id: String,
        guarantee: String,
        implementation: String,
        verifiable: Bool,
        verificationMethod: String? = nil
    ) {
        self.id = id
        self.guarantee = guarantee
        self.implementation = implementation
        self.verifiable = verifiable
        self.verificationMethod = verificationMethod
    }
}

// MARK: - Data Categories

/// Category of data that is collected.
public struct DataCategory: Codable, Sendable, Identifiable {
    public let id: String
    public let category: String
    public let description: String
    public let examples: [String]
    public let sensitivity: SensitivityLevel
    public let retentionPolicy: String

    public enum SensitivityLevel: String, Codable, Sendable {
        case low       // Infrastructure metrics
        case medium    // Aggregate patterns
        case high      // Identity-linked metrics
    }

    public init(
        id: String,
        category: String,
        description: String,
        examples: [String],
        sensitivity: SensitivityLevel,
        retentionPolicy: String
    ) {
        self.id = id
        self.category = category
        self.description = description
        self.examples = examples
        self.sensitivity = sensitivity
        self.retentionPolicy = retentionPolicy
    }
}

/// Data that is explicitly not collected.
public struct ExcludedData: Codable, Sendable, Identifiable {
    public let id: String
    public let category: String
    public let description: String
    public let technicalEnforcement: String

    public init(id: String, category: String, description: String, technicalEnforcement: String) {
        self.id = id
        self.category = category
        self.description = description
        self.technicalEnforcement = technicalEnforcement
    }
}

// MARK: - Uses

/// An allowed use of Metopticon data.
public struct AllowedUse: Codable, Sendable, Identifiable {
    public let id: String
    public let use: String
    public let description: String
    public let requiredRole: String
    public let controlMappings: [String]  // NIST/compliance control IDs

    public init(
        id: String,
        use: String,
        description: String,
        requiredRole: String,
        controlMappings: [String]
    ) {
        self.id = id
        self.use = use
        self.description = description
        self.requiredRole = requiredRole
        self.controlMappings = controlMappings
    }
}

/// A prohibited use of Metopticon data.
public struct ProhibitedUse: Codable, Sendable, Identifiable {
    public let id: String
    public let prohibition: String
    public let rationale: String
    public let technicalPrevention: String
    public let violationSeverity: ViolationSeverity

    public enum ViolationSeverity: String, Codable, Sendable {
        case policy      // Policy violation
        case compliance  // Compliance violation
        case legal       // Legal violation
    }

    public init(
        id: String,
        prohibition: String,
        rationale: String,
        technicalPrevention: String,
        violationSeverity: ViolationSeverity
    ) {
        self.id = id
        self.prohibition = prohibition
        self.rationale = rationale
        self.technicalPrevention = technicalPrevention
        self.violationSeverity = violationSeverity
    }
}

// MARK: - Retention

/// Data retention policy for Metopticon.
public struct MetopticonRetentionPolicy: Codable, Sendable, Identifiable {
    public let id: String
    public let dataType: String
    public let detailedRetention: TimeInterval
    public let aggregatedRetention: TimeInterval
    public let anonymizationMethod: String
    public let deletionMethod: String

    public init(
        id: String,
        dataType: String,
        detailedRetention: TimeInterval,
        aggregatedRetention: TimeInterval,
        anonymizationMethod: String,
        deletionMethod: String
    ) {
        self.id = id
        self.dataType = dataType
        self.detailedRetention = detailedRetention
        self.aggregatedRetention = aggregatedRetention
        self.anonymizationMethod = anonymizationMethod
        self.deletionMethod = deletionMethod
    }
}

// MARK: - Governance

/// Governance structure for Metopticon.
public struct GovernanceStructure: Codable, Sendable {
    /// Who owns Metopticon configuration
    public let owner: String

    /// Body that reviews changes
    public let reviewBody: String

    /// How changes are approved
    public let changeProcess: String

    /// How violations are handled
    public let violationProcess: String

    /// Audit requirements
    public let auditRequirements: [String]

    /// Transparency requirements
    public let transparencyRequirements: [String]

    public init(
        owner: String,
        reviewBody: String,
        changeProcess: String,
        violationProcess: String,
        auditRequirements: [String],
        transparencyRequirements: [String]
    ) {
        self.owner = owner
        self.reviewBody = reviewBody
        self.changeProcess = changeProcess
        self.violationProcess = violationProcess
        self.auditRequirements = auditRequirements
        self.transparencyRequirements = transparencyRequirements
    }
}

// MARK: - Default Manifest

extension MetopticonManifest {

    /// The default Metopticon manifest.
    public static func defaultManifest() -> MetopticonManifest {
        MetopticonManifest(
            version: "1.0.0",
            lastUpdated: Date(),
            preamble: """
                Metopticon is a workload observability system for AI and automation pipelines
                running on institutional infrastructure. It is designed for capacity planning,
                reliability monitoring, accessibility compliance, and operational accountability.

                Metopticon is explicitly NOT a surveillance tool. It observes infrastructure
                behavior—templates, performance, errors, and resource usage—not individual
                actions, content, or behavioral patterns. The name references "meta-observation":
                watching the watchers, ensuring the infrastructure serves its users rather than
                monitoring them.

                This manifest defines what Metopticon tracks, what it does not track, and the
                technical guarantees that make these promises enforceable in code.
                """,

            principles: [
                Principle(
                    id: "P1",
                    name: "Observability Over Surveillance",
                    description: "Metopticon observes pipeline behavior, capacity, error patterns, and health signals. It does not observe keystrokes, browsing, raw prompts, document contents, or personal communications.",
                    rationale: "Infrastructure observability enables better service without violating privacy. The distinction between 'what the system is doing' and 'what a person is doing' is fundamental."
                ),
                Principle(
                    id: "P2",
                    name: "Data Minimization",
                    description: "Metopticon only stores and transmits metadata necessary for diagnostics and planning: template IDs, categories, node types, timing metrics, error codes, device IDs, and org-unit tags. Content payloads are excluded at the telemetry layer by design.",
                    rationale: "Collecting only what is needed reduces risk of misuse, simplifies compliance, and builds trust. If data doesn't exist, it cannot be leaked or abused."
                ),
                Principle(
                    id: "P3",
                    name: "Purpose Limitation",
                    description: "Metopticon data may only be used for: system capacity planning, debugging and reliability, template quality improvement, meeting accessibility obligations, and operational accountability. It may NOT be used for: covert performance monitoring, student profiling, disciplinary action without human review and additional evidence, or any form of behavioral targeting.",
                    rationale: "Clear boundaries on use prevent mission creep and ensure the system remains a tool for infrastructure, not a tool for control."
                ),
                Principle(
                    id: "P4",
                    name: "Transparency and Notice",
                    description: "Staff and faculty are informed that Metopticon exists, what it tracks, and what it does not track. Documentation is accessible and written for non-technical readers.",
                    rationale: "People have a right to know what systems observe their work environment. Transparency enables informed consent and builds trust."
                ),
                Principle(
                    id: "P5",
                    name: "User Agency",
                    description: "Staff can view their own pipeline history and metrics. Observability is symmetrical—individuals see how their tools behave, not just administrators.",
                    rationale: "When people can see what the system sees about them, the power dynamic shifts from surveillance to shared understanding."
                ),
                Principle(
                    id: "P6",
                    name: "Technical Enforcement",
                    description: "Privacy protections are enforced in code, not just policy. Certain misuses are structurally difficult because the data required for them never enters the telemetry layer.",
                    rationale: "Policy can be violated; architecture is harder to circumvent. Design choices that make misuse technically difficult are stronger than promises alone."
                )
            ],

            technicalGuarantees: [
                TechnicalGuarantee(
                    id: "TG1",
                    guarantee: "PortValue content is never serialized into telemetry",
                    implementation: "TelemetryContext only accepts pre-defined metric types; PortValue.content is not a valid field. Type system prevents accidental inclusion.",
                    verifiable: true,
                    verificationMethod: "Static analysis of TelemetryContext struct and all code paths that write to it"
                ),
                TechnicalGuarantee(
                    id: "TG2",
                    guarantee: "ExecutionTrace and NodeTrace contain identifiers and metrics only",
                    implementation: "Trace structs have no content fields. Node inputs/outputs are represented only as type IDs and sizes, never values.",
                    verifiable: true,
                    verificationMethod: "Struct definition audit and serialization tests"
                ),
                TechnicalGuarantee(
                    id: "TG3",
                    guarantee: "PipelineWorkloadComponent carries categories and template IDs, not payload",
                    implementation: "Component schema has no fields for text content, documents, or prompts. Only metadata fields are defined.",
                    verifiable: true,
                    verificationMethod: "Schema review and ECS component audit"
                ),
                TechnicalGuarantee(
                    id: "TG4",
                    guarantee: "RBAC filters data before it leaves the query layer",
                    implementation: "MetopticonAccessEnforcer runs on all queries. Fields are redacted based on principal's effective access before serialization.",
                    verifiable: true,
                    verificationMethod: "Unit tests for access enforcement, integration tests with test principals"
                ),
                TechnicalGuarantee(
                    id: "TG5",
                    guarantee: "Logs are aggregated and anonymized according to retention policy",
                    implementation: "MetopticonRetentionSystem runs on schedule, aggregating detailed traces into summaries and deleting raw data.",
                    verifiable: true,
                    verificationMethod: "Retention job logs and data lifecycle audit"
                )
            ],

            dataCollected: [
                DataCategory(
                    id: "DC1",
                    category: "Template Metadata",
                    description: "Information about which pipeline templates are used",
                    examples: ["Template ID", "Template name", "Category (alt-media, grading, etc.)", "Version"],
                    sensitivity: .low,
                    retentionPolicy: "Indefinite (part of system configuration)"
                ),
                DataCategory(
                    id: "DC2",
                    category: "Execution Timing",
                    description: "Duration and timing of pipeline executions",
                    examples: ["Start time", "End time", "Duration", "Per-node timing", "Queue wait time"],
                    sensitivity: .low,
                    retentionPolicy: "Detailed: 30 days, Aggregated: 1 year"
                ),
                DataCategory(
                    id: "DC3",
                    category: "Resource Usage",
                    description: "Hardware resource consumption during execution",
                    examples: ["CPU percentage", "GPU percentage", "Memory usage", "ANE usage"],
                    sensitivity: .low,
                    retentionPolicy: "Detailed: 7 days, Aggregated: 90 days"
                ),
                DataCategory(
                    id: "DC4",
                    category: "Error Information",
                    description: "Error codes and failure patterns",
                    examples: ["Error code", "Error category", "Retry count", "Node that failed"],
                    sensitivity: .low,
                    retentionPolicy: "Detailed: 30 days, Aggregated: 1 year"
                ),
                DataCategory(
                    id: "DC5",
                    category: "Org Unit Association",
                    description: "Which department or unit triggered the workload",
                    examples: ["Department ID", "Org unit", "Workload category"],
                    sensitivity: .medium,
                    retentionPolicy: "Aggregated only after 30 days"
                )
            ],

            dataNotCollected: [
                ExcludedData(
                    id: "DNC1",
                    category: "Document Content",
                    description: "The actual content of documents, PDFs, or files processed by pipelines",
                    technicalEnforcement: "PortValue content fields are not serializable to TelemetryContext. No telemetry struct has a content field."
                ),
                ExcludedData(
                    id: "DNC2",
                    category: "Prompt Text",
                    description: "The text of prompts sent to LLMs or other AI models",
                    technicalEnforcement: "Prompt strings are never passed to telemetry. Only token counts and template IDs are recorded."
                ),
                ExcludedData(
                    id: "DNC3",
                    category: "Model Outputs",
                    description: "The generated text, images, or other outputs from AI models",
                    technicalEnforcement: "Output content is excluded from traces. Only output type, size, and timing are recorded."
                ),
                ExcludedData(
                    id: "DNC4",
                    category: "Keystroke or Interaction Logs",
                    description: "How users interact with the UI, their typing, or browsing",
                    technicalEnforcement: "Metopticon has no UI instrumentation. It only observes pipeline execution, not user interfaces."
                ),
                ExcludedData(
                    id: "DNC5",
                    category: "Personal Communications",
                    description: "Emails, messages, or other communications",
                    technicalEnforcement: "Metopticon only tracks pipeline workloads, not communication systems."
                )
            ],

            allowedUses: [
                AllowedUse(
                    id: "AU1",
                    use: "Capacity Planning",
                    description: "Understanding workload patterns to plan hardware, staffing, and scheduling",
                    requiredRole: "itInfrastructure or departmentLead",
                    controlMappings: ["CP-2", "CP-7"]
                ),
                AllowedUse(
                    id: "AU2",
                    use: "Debugging and Reliability",
                    description: "Diagnosing errors, performance issues, and system failures",
                    requiredRole: "itInfrastructure or systemAdmin",
                    controlMappings: ["SI-4", "SI-7"]
                ),
                AllowedUse(
                    id: "AU3",
                    use: "Template Quality Improvement",
                    description: "Identifying templates that need optimization or redesign",
                    requiredRole: "itInfrastructure",
                    controlMappings: ["SA-11", "SA-15"]
                ),
                AllowedUse(
                    id: "AU4",
                    use: "Accessibility Compliance",
                    description: "Monitoring alt-media pipeline health to meet accommodation obligations",
                    requiredRole: "dspsStaff or itInfrastructure",
                    controlMappings: ["Section 508", "ADA Title II"]
                ),
                AllowedUse(
                    id: "AU5",
                    use: "Operational Accountability",
                    description: "Demonstrating that systems are functioning as intended for audits",
                    requiredRole: "auditor or systemAdmin",
                    controlMappings: ["AU-2", "AU-6"]
                )
            ],

            prohibitedUses: [
                ProhibitedUse(
                    id: "PU1",
                    prohibition: "Covert Performance Monitoring",
                    rationale: "Using Metopticon data to evaluate individual employee performance without their knowledge violates transparency and purpose limitation principles.",
                    technicalPrevention: "Aggregation removes individual identity after retention period. RBAC prevents most roles from seeing individual attribution.",
                    violationSeverity: .compliance
                ),
                ProhibitedUse(
                    id: "PU2",
                    prohibition: "Student Profiling",
                    rationale: "Using pipeline data to profile, categorize, or make decisions about students is prohibited under FERPA and institutional policy.",
                    technicalPrevention: "Student identity is not captured in workload telemetry. Workloads are attributed to staff/faculty who trigger them.",
                    violationSeverity: .legal
                ),
                ProhibitedUse(
                    id: "PU3",
                    prohibition: "Disciplinary Action Without Human Review",
                    rationale: "Metopticon metrics alone should never be used for disciplinary action. Patterns may indicate system issues, not individual failings.",
                    technicalPrevention: "Policy enforcement. Dashboard displays disclaimer that metrics are for infrastructure, not evaluation.",
                    violationSeverity: .policy
                ),
                ProhibitedUse(
                    id: "PU4",
                    prohibition: "Behavioral Targeting or Advertising",
                    rationale: "Using workload patterns to target individuals with content, recommendations, or interventions is prohibited.",
                    technicalPrevention: "No integration exists between Metopticon and any targeting or recommendation system.",
                    violationSeverity: .compliance
                ),
                ProhibitedUse(
                    id: "PU5",
                    prohibition: "Cross-Referencing with Other Surveillance",
                    rationale: "Combining Metopticon data with other surveillance systems to build richer profiles is prohibited.",
                    technicalPrevention: "Metopticon has no data export to third-party surveillance systems. Export capability is restricted by role.",
                    violationSeverity: .legal
                )
            ],

            retentionPolicies: [
                MetopticonRetentionPolicy(
                    id: "RP1",
                    dataType: "Detailed Execution Traces",
                    detailedRetention: 7 * 24 * 60 * 60,  // 7 days
                    aggregatedRetention: 90 * 24 * 60 * 60,  // 90 days
                    anonymizationMethod: "Aggregate by template and time bucket, remove individual workload IDs",
                    deletionMethod: "Hard delete from storage after retention period"
                ),
                MetopticonRetentionPolicy(
                    id: "RP2",
                    dataType: "Workload Metadata",
                    detailedRetention: 30 * 24 * 60 * 60,  // 30 days
                    aggregatedRetention: 365 * 24 * 60 * 60,  // 1 year
                    anonymizationMethod: "Remove owner identity, aggregate by org unit",
                    deletionMethod: "Soft delete, then hard delete after grace period"
                ),
                MetopticonRetentionPolicy(
                    id: "RP3",
                    dataType: "Error Logs",
                    detailedRetention: 30 * 24 * 60 * 60,  // 30 days
                    aggregatedRetention: 365 * 24 * 60 * 60,  // 1 year
                    anonymizationMethod: "Aggregate by error code and template",
                    deletionMethod: "Hard delete from storage"
                ),
                MetopticonRetentionPolicy(
                    id: "RP4",
                    dataType: "Resource Metrics",
                    detailedRetention: 7 * 24 * 60 * 60,  // 7 days
                    aggregatedRetention: 90 * 24 * 60 * 60,  // 90 days
                    anonymizationMethod: "Aggregate by device and time bucket",
                    deletionMethod: "Hard delete from storage"
                )
            ],

            governance: GovernanceStructure(
                owner: "IT Infrastructure Team",
                reviewBody: "Digital Ethics Committee or IT Governance Board",
                changeProcess: "Changes to Metopticon scope, retention, or access rules require proposal, review by governance body, consultation with stakeholders (union, faculty senate, student government where applicable), and documented approval.",
                violationProcess: "Suspected violations are reported to IT Security, investigated, and escalated to governance body. Violations may result in access revocation, policy review, or disciplinary action.",
                auditRequirements: [
                    "Quarterly review of access patterns and role assignments",
                    "Annual review of data collected vs. manifest",
                    "Annual review of retention policy compliance",
                    "Incident review for any suspected misuse"
                ],
                transparencyRequirements: [
                    "This manifest is publicly accessible to all staff and faculty",
                    "Dashboard includes visible link to this manifest",
                    "New staff receive training that includes Metopticon explanation",
                    "Changes to Metopticon are communicated via institutional channels"
                ]
            )
        )
    }
}

// MARK: - Manifest Validation

/// Validates that a Metopticon deployment conforms to the manifest.
public struct MetopticonManifestValidator {
    private let manifest: MetopticonManifest

    public init(manifest: MetopticonManifest = .current) {
        self.manifest = manifest
    }

    /// Validates that a telemetry context does not contain prohibited data.
    public func validateTelemetryContext(_ context: [String: Any]) -> [ManifestViolation] {
        var violations: [ManifestViolation] = []

        // Check for content fields
        let prohibitedFields = ["content", "prompt", "output", "document", "text", "message"]
        for field in prohibitedFields {
            if context[field] != nil {
                violations.append(ManifestViolation(
                    type: .prohibitedData,
                    field: field,
                    guarantee: "TG1",
                    description: "Telemetry context contains prohibited content field: \(field)"
                ))
            }
        }

        return violations
    }

    /// Validates that RBAC configuration matches manifest roles.
    public func validateRBACConfiguration(_ roles: [MetopticonRole: MetopticonAccessConfiguration]) -> [ManifestViolation] {
        var violations: [ManifestViolation] = []

        for (role, config) in roles {
            let defaultConfig = role.defaultAccess

            // Check that custom config doesn't exceed default permissions
            if config.granularity > defaultConfig.granularity {
                violations.append(ManifestViolation(
                    type: .excessiveAccess,
                    field: "granularity",
                    guarantee: "TG4",
                    description: "Role \(role.rawValue) has granularity exceeding default"
                ))
            }
        }

        return violations
    }
}

/// A violation of the manifest.
public struct ManifestViolation: Codable, Sendable {
    public let type: ViolationType
    public let field: String
    public let guarantee: String
    public let description: String

    public enum ViolationType: String, Codable, Sendable {
        case prohibitedData
        case excessiveAccess
        case retentionViolation
        case missingAnonymization
    }

    public init(type: ViolationType, field: String, guarantee: String, description: String) {
        self.type = type
        self.field = field
        self.guarantee = guarantee
        self.description = description
    }
}
