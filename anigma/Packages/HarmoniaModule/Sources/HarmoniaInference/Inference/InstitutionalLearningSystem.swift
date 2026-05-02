//
//  InstitutionalLearningSystem.swift
//  HarmoniaModule
//
//  Radically Legible AI: Institutional learning with full transparency.
//  Every trace used for learning has provenance, consent, and revocability.
//

import Foundation
import HarmoniaCore
import AnigmaPrimitives
import InferenceCore
import AnigmaCore
@preconcurrency import Foundation

// MARK: - Learning Charter

/// A machine-readable charter that defines what an institutional model can and cannot do.
/// This is the "constitution" for per-tenant AI behavior in the learning system.
struct LearningCharter: Sendable, Codable, Identifiable {
    let id: String
    let tenantId: String
    let version: String
    let effectiveDate: Date
    let expirationDate: Date?

    /// Domains this charter covers.
    let coveredDomains: Set<String>

    /// Legal/policy sources that are authoritative.
    let authoritativeSources: [LearningAuthoritativeSource]

    /// Explicit prohibitions - things the model must never optimize for.
    let prohibitions: [LearningProhibition]

    /// Required approvers for capability changes.
    let approvers: [LearningApprover]

    /// Learning configuration.
    let learningConfig: LearningConfiguration

    /// Behavioral constraints.
    let behavioralConstraints: LearningBehavioralConstraints

    init(
        id: String = UUID().uuidString,
        tenantId: String,
        version: String,
        effectiveDate: Date = Date(),
        expirationDate: Date? = nil,
        coveredDomains: Set<String>,
        authoritativeSources: [LearningAuthoritativeSource],
        prohibitions: [LearningProhibition],
        approvers: [LearningApprover],
        learningConfig: LearningConfiguration,
        behavioralConstraints: LearningBehavioralConstraints
    ) {
        self.id = id
        self.tenantId = tenantId
        self.version = version
        self.effectiveDate = effectiveDate
        self.expirationDate = expirationDate
        self.coveredDomains = coveredDomains
        self.authoritativeSources = authoritativeSources
        self.prohibitions = prohibitions
        self.approvers = approvers
        self.learningConfig = learningConfig
        self.behavioralConstraints = behavioralConstraints
    }
}

// MARK: - Charter Components

struct LearningAuthoritativeSource: Sendable, Codable, Identifiable {
    let id: String
    let type: SourceType
    let name: String
    let jurisdiction: String?
    let priority: Int  // Lower = higher priority

    enum SourceType: String, Sendable, Codable {
        case federalLaw
        case stateLaw
        case regulation
        case institutionalPolicy
        case departmentPolicy
        case professionalStandard
    }

    init(
        id: String = UUID().uuidString,
        type: SourceType,
        name: String,
        jurisdiction: String? = nil,
        priority: Int = 100
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.jurisdiction = jurisdiction
        self.priority = priority
    }
}

struct LearningProhibition: Sendable, Codable, Identifiable {
    let id: String
    let description: String
    let category: Category
    let severity: Severity

    enum Category: String, Sendable, Codable {
        case benefitReduction  // Reducing benefits/accommodations
        case appealDiscouragement  // Discouraging appeals/complaints
        case costMinimization  // Prioritizing cost over student needs
        case workloadReduction  // Reducing staff workload at student expense
        case proceduralShortcuts  // Skipping required procedures
        case discriminatory  // Any discriminatory behavior
    }

    enum Severity: String, Sendable, Codable {
        case critical  // Automatic rejection, immediate audit
        case high  // Rejection, logged for review
        case medium  // Warning, requires justification
    }

    init(
        id: String = UUID().uuidString,
        description: String,
        category: Category,
        severity: Severity = .high
    ) {
        self.id = id
        self.description = description
        self.category = category
        self.severity = severity
    }
}

struct LearningApprover: Sendable, Codable, Identifiable {
    let id: String
    let role: String
    let department: String?
    let requiredFor: Set<ApprovalScope>

    enum ApprovalScope: String, Sendable, Codable, Hashable {
        case newCapabilities
        case policyChanges
        case learningConfigChanges
        case charterModifications
    }

    init(
        id: String = UUID().uuidString,
        role: String,
        department: String? = nil,
        requiredFor: Set<ApprovalScope>
    ) {
        self.id = id
        self.role = role
        self.department = department
        self.requiredFor = requiredFor
    }
}

// MARK: - Learning Configuration

struct LearningConfiguration: Sendable, Codable {
    let enabled: Bool
    let mode: LearningMode
    let eligibleDomains: Set<String>
    let requiresConsent: Bool
    let retentionDays: Int
    let qualityThreshold: Double
    let impactThreshold: Double
    let upftEnabled: Bool
    let federationAllowed: Bool

    enum LearningMode: String, Sendable, Codable {
        case disabled  // No learning
        case anonymizedOnly  // Only anonymized traces
        case prefixOnly  // UPFT-style prefix extraction
        case fullTraces  // Full reasoning traces (with consent)
    }

    init(
        enabled: Bool = false,
        mode: LearningMode = .anonymizedOnly,
        eligibleDomains: Set<String> = [],
        requiresConsent: Bool = true,
        retentionDays: Int = 90,
        qualityThreshold: Double = 0.7,
        impactThreshold: Double = 0.5,
        upftEnabled: Bool = true,
        federationAllowed: Bool = false
    ) {
        self.enabled = enabled
        self.mode = mode
        self.eligibleDomains = eligibleDomains
        self.requiresConsent = requiresConsent
        self.retentionDays = retentionDays
        self.qualityThreshold = qualityThreshold
        self.impactThreshold = impactThreshold
        self.upftEnabled = upftEnabled
        self.federationAllowed = federationAllowed
    }

    static let disabled = LearningConfiguration(enabled: false)

    static let anonymized = LearningConfiguration(
        enabled: true,
        mode: .anonymizedOnly,
        eligibleDomains: ["dsps", "transcriptum"],
        requiresConsent: true,
        retentionDays: 90
    )
}

// MARK: - Behavioral Constraints

struct LearningBehavioralConstraints: Sendable, Codable {
    let maxReasoningTokensDefault: Int
    let requireVerificationFor: Set<String>  // Domain names
    let assistiveModeOnly: Set<String>  // Domains where autopilot is forbidden
    let humanApprovalRequired: Set<String>  // Actions requiring human approval
    let auditLevel: AuditLevel

    enum AuditLevel: String, Sendable, Codable {
        case minimal  // Only errors and violations
        case standard  // Key decisions
        case full  // All reasoning steps
    }

    init(
        maxReasoningTokensDefault: Int = 2000,
        requireVerificationFor: Set<String> = [],
        assistiveModeOnly: Set<String> = [],
        humanApprovalRequired: Set<String> = [],
        auditLevel: AuditLevel = .standard
    ) {
        self.maxReasoningTokensDefault = maxReasoningTokensDefault
        self.requireVerificationFor = requireVerificationFor
        self.assistiveModeOnly = assistiveModeOnly
        self.humanApprovalRequired = humanApprovalRequired
        self.auditLevel = auditLevel
    }

    static let dspsDefault = LearningBehavioralConstraints(
        maxReasoningTokensDefault: 4000,
        requireVerificationFor: ["accommodation_decisions", "eligibility_determinations"],
        assistiveModeOnly: ["case_closures", "denial_recommendations"],
        humanApprovalRequired: ["accommodation_denials", "eligibility_denials"],
        auditLevel: .full
    )
}

// MARK: - Learning Trace

/// A trace that may be used for institutional learning.
struct LearningTrace: Sendable, Codable, Identifiable {
    let id: String
    let tenantId: String
    let domain: String
    let createdAt: Date
    let expiresAt: Date

    /// Provenance - where did this trace come from?
    let provenance: TraceProvenance

    /// The actual learning content.
    let content: LearningContent

    /// Quality and impact assessment.
    let assessment: TraceAssessment

    /// User control.
    let userControl: UserControl

    /// Status.
    let status: TraceStatus

    init(
        id: String = UUID().uuidString,
        tenantId: String,
        domain: String,
        createdAt: Date = Date(),
        expiresAt: Date,
        provenance: TraceProvenance,
        content: LearningContent,
        assessment: TraceAssessment,
        userControl: UserControl,
        status: TraceStatus = .pending
    ) {
        self.id = id
        self.tenantId = tenantId
        self.domain = domain
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.provenance = provenance
        self.content = content
        self.assessment = assessment
        self.userControl = userControl
        self.status = status
    }
}

struct TraceProvenance: Sendable, Codable {
    let taskId: String
    let interactionClass: InteractionClass
    let corpusSource: String?
    let humanReviewed: Bool
    let humanCorrected: Bool

    enum InteractionClass: String, Sendable, Codable {
        case synthetic  // Generated for training
        case userInteraction  // From actual user interaction
        case staffReviewed  // Staff-reviewed case
        case expertCurated  // Expert-curated example
    }

    init(
        taskId: String,
        interactionClass: InteractionClass,
        corpusSource: String? = nil,
        humanReviewed: Bool = false,
        humanCorrected: Bool = false
    ) {
        self.taskId = taskId
        self.interactionClass = interactionClass
        self.corpusSource = corpusSource
        self.humanReviewed = humanReviewed
        self.humanCorrected = humanCorrected
    }
}

enum LearningContent: Sendable, Codable {
    case fullTrace(steps: [String])
    case prefixOnly(prefix: String, prefixTokens: Int)
    case structuredTemplate(template: String, slots: [String: String])
    case anonymizedSummary(summary: String)
}

struct TraceAssessment: Sendable, Codable {
    let qualityScore: Double  // 0.0 to 1.0
    let impactScore: Double  // Learning impact estimate
    let structureScore: Double  // How well-structured
    let noveltyScore: Double  // How different from existing
    let safetyPassed: Bool  // Passed safety checks
    let charterCompliant: Bool  // Compliant with charter

    init(
        qualityScore: Double,
        impactScore: Double,
        structureScore: Double,
        noveltyScore: Double,
        safetyPassed: Bool,
        charterCompliant: Bool
    ) {
        self.qualityScore = qualityScore
        self.impactScore = impactScore
        self.structureScore = structureScore
        self.noveltyScore = noveltyScore
        self.safetyPassed = safetyPassed
        self.charterCompliant = charterCompliant
    }

    var meetsThreshold: Bool {
        qualityScore >= 0.7 && impactScore >= 0.5 && safetyPassed && charterCompliant
    }
}

struct UserControl: Sendable, Codable {
    let consentGiven: Bool
    let consentTimestamp: Date?
    let revocable: Bool
    let revoked: Bool
    let revokedAt: Date?

    init(
        consentGiven: Bool = false,
        consentTimestamp: Date? = nil,
        revocable: Bool = true,
        revoked: Bool = false,
        revokedAt: Date? = nil
    ) {
        self.consentGiven = consentGiven
        self.consentTimestamp = consentTimestamp
        self.revocable = revocable
        self.revoked = revoked
        self.revokedAt = revokedAt
    }

    static let noConsent = UserControl(consentGiven: false)

    static func withConsent() -> UserControl {
        UserControl(consentGiven: true, consentTimestamp: Date())
    }
}

enum TraceStatus: String, Sendable, Codable {
    case pending  // Awaiting assessment
    case approved  // Approved for learning
    case rejected  // Rejected (low quality, safety, etc.)
    case used  // Already used in training
    case expired  // Past retention period
    case revoked  // User revoked consent
}

// MARK: - Institutional Learning Service

/// Manages institutional learning with full governance.
actor InstitutionalLearningService {
    private var charters: [String: LearningCharter] = [:]
    private var traces: [String: LearningTrace] = [:]
    private var tracesByTenant: [String: Set<String>] = [:]

    init() {}

    // MARK: - Charter Management

    /// Register a charter for a tenant.
    func registerCharter(_ charter: LearningCharter) {
        charters[charter.tenantId] = charter
    }

    /// Get the charter for a tenant.
    func getCharter(for tenantId: String) -> LearningCharter? {
        charters[tenantId]
    }

    /// Check if an action complies with the charter.
    func checkCompliance(
        tenantId: String,
        action: String,
        domain: String
    ) -> ComplianceResult {
        guard let charter = charters[tenantId] else {
            return .noCharter
        }

        // Check if domain is covered
        guard charter.coveredDomains.contains(domain) else {
            return .domainNotCovered
        }

        // Check for prohibitions
        for prohibition in charter.prohibitions {
            if actionViolatesProhibition(action, prohibition: prohibition) {
                return .violation(prohibition: prohibition)
            }
        }

        // Check behavioral constraints
        if charter.behavioralConstraints.assistiveModeOnly.contains(domain) {
            return .assistiveModeRequired
        }

        if charter.behavioralConstraints.humanApprovalRequired.contains(action) {
            return .humanApprovalRequired
        }

        return .compliant
    }

    private func actionViolatesProhibition(_ action: String, prohibition: LearningProhibition)
        -> Bool {
        // Simple keyword matching - would be more sophisticated in production
        let actionLower = action.lowercased()
        switch prohibition.category {
        case .benefitReduction:
            return actionLower.contains("reduce") || actionLower.contains("deny")
                || actionLower.contains("limit")
        case .appealDiscouragement:
            return actionLower.contains("discourage") || actionLower.contains("don't appeal")
        case .costMinimization:
            return actionLower.contains("save cost") || actionLower.contains("cheaper")
        case .workloadReduction:
            return actionLower.contains("skip") || actionLower.contains("simplify process")
        case .proceduralShortcuts:
            return actionLower.contains("skip step") || actionLower.contains("bypass")
        case .discriminatory:
            return false  // Would use more sophisticated detection
        }
    }

    enum ComplianceResult: Sendable {
        case compliant
        case noCharter
        case domainNotCovered
        case violation(prohibition: LearningProhibition)
        case assistiveModeRequired
        case humanApprovalRequired
    }

    // MARK: - Trace Management

    /// Submit a trace for potential learning.
    func submitTrace(_ trace: LearningTrace) -> TraceSubmissionResult {
        guard let charter = charters[trace.tenantId] else {
            return .rejected(reason: "No charter for tenant")
        }

        // Check learning configuration
        guard charter.learningConfig.enabled else {
            return .rejected(reason: "Learning disabled for tenant")
        }

        guard charter.learningConfig.eligibleDomains.contains(trace.domain) else {
            return .rejected(reason: "Domain not eligible for learning")
        }

        // Check consent if required
        if charter.learningConfig.requiresConsent && !trace.userControl.consentGiven {
            return .rejected(reason: "Consent required but not given")
        }

        // Check quality thresholds
        guard trace.assessment.qualityScore >= charter.learningConfig.qualityThreshold else {
            return .rejected(reason: "Quality score below threshold")
        }

        guard trace.assessment.impactScore >= charter.learningConfig.impactThreshold else {
            return .rejected(reason: "Impact score below threshold")
        }

        // Check safety
        guard trace.assessment.safetyPassed && trace.assessment.charterCompliant else {
            return .rejected(reason: "Failed safety or charter compliance")
        }

        // Store the trace
        _ = trace
        // Update status using a new trace (since it's immutable)
        let newTrace = LearningTrace(
            id: trace.id,
            tenantId: trace.tenantId,
            domain: trace.domain,
            createdAt: trace.createdAt,
            expiresAt: trace.expiresAt,
            provenance: trace.provenance,
            content: trace.content,
            assessment: trace.assessment,
            userControl: trace.userControl,
            status: .approved
        )

        traces[newTrace.id] = newTrace

        if tracesByTenant[trace.tenantId] == nil {
            tracesByTenant[trace.tenantId] = []
        }
        tracesByTenant[trace.tenantId]?.insert(newTrace.id)

        return .accepted(traceId: newTrace.id)
    }

    enum TraceSubmissionResult: Sendable {
        case accepted(traceId: String)
        case rejected(reason: String)
    }

    /// Revoke a trace.
    func revokeTrace(traceId: String, by principalId: String) -> Bool {
        guard let trace = traces[traceId] else { return false }
        guard trace.userControl.revocable else { return false }

        // Create a revoked version
        let revokedControl = UserControl(
            consentGiven: trace.userControl.consentGiven,
            consentTimestamp: trace.userControl.consentTimestamp,
            revocable: true,
            revoked: true,
            revokedAt: Date()
        )

        let revokedTrace = LearningTrace(
            id: trace.id,
            tenantId: trace.tenantId,
            domain: trace.domain,
            createdAt: trace.createdAt,
            expiresAt: trace.expiresAt,
            provenance: trace.provenance,
            content: trace.content,
            assessment: trace.assessment,
            userControl: revokedControl,
            status: .revoked
        )

        traces[traceId] = revokedTrace
        return true
    }

    /// Get traces for a tenant.
    func getTraces(for tenantId: String, status: TraceStatus? = nil) -> [LearningTrace] {
        guard let traceIds = tracesByTenant[tenantId] else { return [] }

        var result: [LearningTrace] = []
        for traceId in traceIds {
            if let trace = traces[traceId] {
                if let status = status {
                    if trace.status == status {
                        result.append(trace)
                    }
                } else {
                    result.append(trace)
                }
            }
        }
        return result
    }

    /// Get learning statistics for a tenant.
    func getStats(for tenantId: String) -> LearningStats {
        let allTraces = getTraces(for: tenantId)

        let approved = allTraces.filter { $0.status == .approved }.count
        let rejected = allTraces.filter { $0.status == .rejected }.count
        let used = allTraces.filter { $0.status == .used }.count
        let revoked = allTraces.filter { $0.status == .revoked }.count

        let avgQuality =
            allTraces.isEmpty
            ? 0.0
            : allTraces.map { $0.assessment.qualityScore }.reduce(0, +) / Double(allTraces.count)
        let avgImpact =
            allTraces.isEmpty
            ? 0.0
            : allTraces.map { $0.assessment.impactScore }.reduce(0, +) / Double(allTraces.count)

        return LearningStats(
            totalTraces: allTraces.count,
            approvedTraces: approved,
            rejectedTraces: rejected,
            usedTraces: used,
            revokedTraces: revoked,
            averageQualityScore: avgQuality,
            averageImpactScore: avgImpact
        )
    }
}

struct LearningStats: Sendable, Codable {
    let totalTraces: Int
    let approvedTraces: Int
    let rejectedTraces: Int
    let usedTraces: Int
    let revokedTraces: Int
    let averageQualityScore: Double
    let averageImpactScore: Double
}

// MARK: - UPFT Extractor

/// Extracts prefixes for UPFT-style learning.
struct LearningUPFTExtractor {

    /// Extract prefix from a reasoning trace.
    static func extractPrefix(
        from trace: StructuredReasoningTrace,
        maxTokens: Int = 200
    ) -> LearningContent {
        var prefixSteps: [String] = []
        var totalTokens = 0

        for step in trace.steps {
            let stepDescription = "[\(step.tier.rawValue)] \(step.description)"
            let stepTokens = step.tokensUsed

            if totalTokens + stepTokens > maxTokens {
                break
            }

            prefixSteps.append(stepDescription)
            totalTokens += stepTokens
        }

        let prefix = prefixSteps.joined(separator: "\n")
        return .prefixOnly(prefix: prefix, prefixTokens: totalTokens)
    }

    /// Anonymize a trace by removing specific identifiers.
    static func anonymize(
        _ trace: StructuredReasoningTrace
    ) -> LearningContent {
        var anonymizedSteps: [String] = []

        for step in trace.steps {
            var desc = step.description

            // Replace specific patterns with generic ones
            desc = desc.replacingOccurrences(
                of: #"student \w+"#, with: "student [STUDENT]", options: .regularExpression)
            desc = desc.replacingOccurrences(
                of: #"case \d+"#, with: "case [CASE_ID]", options: .regularExpression)
            desc = desc.replacingOccurrences(
                of: #"course \w+\d+"#, with: "course [COURSE]", options: .regularExpression)
            desc = desc.replacingOccurrences(
                of: #"term \d{4}"#, with: "term [TERM]", options: .regularExpression)

            anonymizedSteps.append("[\(step.tier.rawValue)] \(desc)")
        }

        return .anonymizedSummary(summary: anonymizedSteps.joined(separator: "\n"))
    }
}

// MARK: - Charter Renderer

/// Renders charters for human inspection.
struct CharterRenderer {

    static func renderText(_ charter: LearningCharter) -> String {
        var lines: [String] = []

        lines.append("═══════════════════════════════════════════════════════════════")
        lines.append("              INSTITUTIONAL CHARTER")
        lines.append("═══════════════════════════════════════════════════════════════")
        lines.append("Tenant: \(charter.tenantId)")
        lines.append("Version: \(charter.version)")
        lines.append("Effective: \(charter.effectiveDate)")
        lines.append("")

        // Domains
        lines.append("┌─ COVERED DOMAINS ────────────────────────────────────────┐")
        for domain in charter.coveredDomains.sorted() {
            lines.append("│ • \(domain.padding(toLength: 52, withPad: " ", startingAt: 0))│")
        }
        lines.append("└──────────────────────────────────────────────────────────┘")
        lines.append("")

        // Prohibitions
        lines.append("┌─ PROHIBITED OPTIMIZATIONS ───────────────────────────────┐")
        for prohibition in charter.prohibitions {
            let severity =
                prohibition.severity == .critical ? "🔴" : prohibition.severity == .high ? "🟠" : "🟡"
            lines.append("│ \(severity) \(prohibition.description.prefix(50))│")
        }
        lines.append("└──────────────────────────────────────────────────────────┘")
        lines.append("")

        // Learning
        lines.append("┌─ LEARNING CONFIGURATION ─────────────────────────────────┐")
        let enabledStr = charter.learningConfig.enabled ? "Yes" : "No"
        lines.append("│ Enabled: \(enabledStr.padding(toLength: 45, withPad: " ", startingAt: 0))│")
        lines.append(
            "│ Mode: \(charter.learningConfig.mode.rawValue.padding(toLength: 48, withPad: " ", startingAt: 0))│"
        )
        let consentStr = charter.learningConfig.requiresConsent ? "Yes" : "No"
        lines.append(
            "│ Requires Consent: \(consentStr.padding(toLength: 35, withPad: " ", startingAt: 0))│")
        let retentionStr = "\(charter.learningConfig.retentionDays) days"
        lines.append(
            "│ Retention: \(retentionStr.padding(toLength: 42, withPad: " ", startingAt: 0))│")
        lines.append("└──────────────────────────────────────────────────────────┘")
        lines.append("")

        // Behavioral Constraints
        lines.append("┌─ BEHAVIORAL CONSTRAINTS ─────────────────────────────────┐")
        lines.append(
            "│ Max Reasoning Tokens: \(String(charter.behavioralConstraints.maxReasoningTokensDefault).padding(toLength: 31, withPad: " ", startingAt: 0))│"
        )
        lines.append(
            "│ Audit Level: \(charter.behavioralConstraints.auditLevel.rawValue.padding(toLength: 40, withPad: " ", startingAt: 0))│"
        )
        lines.append("└──────────────────────────────────────────────────────────┘")
        lines.append("")

        // Approvers
        lines.append("┌─ REQUIRED APPROVERS ─────────────────────────────────────┐")
        for approver in charter.approvers {
            lines.append("│ • \(approver.role.padding(toLength: 52, withPad: " ", startingAt: 0))│")
        }
        lines.append("└──────────────────────────────────────────────────────────┘")

        lines.append("")
        lines.append("═══════════════════════════════════════════════════════════════")

        return lines.joined(separator: "\n")
    }
}
