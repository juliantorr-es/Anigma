//
//  ResearchDoctrinePack.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Research
//
//  Doctrine pack for literature quality checks.
//  Enforces "no module without literature" as brutally as security doctrine.
//

import Foundation
import HarmoniaModule

// MARK: - Research Doctrine Pack

/// Doctrine pack that checks research adequacy.
public struct ResearchDoctrinePack: DoctrinePack {
    public let id = "research"
    public let domain = DoctrineDomain.computerScience
    public let version = "1.0"
    public let rules: [DoctrineRule]

    public init() {
        self.rules = [
            // Core research adequacy rules
            DoctrineRule(
                id: "research.adequacy.minimum_papers",
                domain: DoctrineCore.DoctrineDomain.computerScience,
                severity: DoctrineCore.DoctrineSeverity.error,
                title: "Minimum number of papers",
                description: "Research bundle must contain at least 5 relevant papers."
            )                { context in
                    guard let bundle = context.researchBundle else {
                        return .valid(grant: nil)
                    }

                    if bundle.papers.count < 5 {
                        return .invalid(reason: "Only \(bundle.papers.count) papers found, need at least 5")
                    }
                    return .valid(grant: nil)
                },

            DoctrineRule(
                id: "research.adequacy.recent_papers",
                domain: DoctrineCore.DoctrineDomain.computerScience,
                severity: DoctrineCore.DoctrineSeverity.warning,
                title: "Recent papers required",
                description: "At least 2 papers should be from the last 5 years."
            )                { context in
                    guard let bundle = context.researchBundle else {
                        return .valid(grant: nil)
                    }

                    let recentPapers = bundle.papers.filter { $0.isRecent }
                    if recentPapers.count < 2 {
                        return .invalid(reason: "Only \(recentPapers.count) recent papers, need at least 2")
                    }
                    return .valid(grant: nil)
                },

            DoctrineRule(
                id: "research.adequacy.independent_sources",
                domain: DoctrineCore.DoctrineDomain.computerScience,
                severity: DoctrineCore.DoctrineSeverity.error,
                title: "Independent research sources",
                description: "Papers should come from at least 3 different institutions."
            )                { context in
                    guard let bundle = context.researchBundle else {
                        return .valid(grant: nil)
                    }

                    let institutions = Set(bundle.papers.compactMap { $0.primaryInstitution })
                    if institutions.count < 3 {
                        return .invalid(reason: "Only \(institutions.count) independent institutions, need at least 3")
                    }
                    return .valid(grant: nil)
                },

            DoctrineRule(
                id: "research.adequacy.limitations_coverage",
                domain: DoctrineCore.DoctrineDomain.computerScience,
                severity: DoctrineCore.DoctrineSeverity.warning,
                title: "Limitations coverage",
                description: "Research should include discussion of limitations."
            )                { context in
                    guard let bundle = context.researchBundle else {
                        return .valid(grant: nil)
                    }

                    let limitationNotes = bundle.extractedNotes.filter { $0.noteType == .limitation }
                    if limitationNotes.isEmpty {
                        return .invalid(reason: "No limitations discussed in research")
                    }
                    return .valid(grant: nil)
                },

            DoctrineRule(
                id: "research.adequacy.citation_impact",
                domain: DoctrineCore.DoctrineDomain.computerScience,
                severity: .info,
                title: "Citation impact",
                description: "At least one highly cited paper (>100 citations)."
            )                { context in
                    guard let bundle = context.researchBundle else {
                        return .valid(grant: nil)
                    }

                    let highlyCited = bundle.papers.contains { $0.isHighlyCited }
                    if !highlyCited {
                        return .invalid(reason: "No highly cited papers found")
                    }
                    return .valid(grant: nil)
                },

            DoctrineRule(
                id: "research.adequacy.venue_diversity",
                domain: DoctrineCore.DoctrineDomain.computerScience,
                severity: .info,
                title: "Venue diversity",
                description: "Papers from at least 2 different venues."
            )                { context in
                    guard let bundle = context.researchBundle else {
                        return .valid(grant: nil)
                    }

                    let venues = Set(bundle.papers.compactMap { $0.venue })
                    if venues.count < 2 {
                        return .invalid(reason: "Limited venue diversity")
                    }
                    return .valid(grant: nil)
                },

            // Security-specific research rules
            DoctrineRule(
                id: "research.security.analysis_required",
                domain: DoctrineCore.DoctrineDomain.privacy,
                severity: DoctrineCore.DoctrineSeverity.error,
                title: "Security analysis required",
                description: "Security-related topics require explicit security analysis."
            )                { context in
                    guard let bundle = context.researchBundle else {
                        return .valid(grant: nil)
                    }

                    // Check if topic has security doctrine tags
                    let hasSecurityTags = bundle.topicSpec.doctrineTags.contains(.privacy)
                    if !hasSecurityTags {
                        return .valid(grant: nil)
                    }

                    // Security topics need security notes
                    let securityNotes = bundle.extractedNotes.filter { $0.noteType == .security }
                    if securityNotes.isEmpty {
                        return .invalid(reason: "Security topic requires security analysis in research")
                    }
                    return .valid(grant: nil)
                },

            // Accessibility-specific research rules
            DoctrineRule(
                id: "research.accessibility.analysis_required",
                domain: DoctrineCore.DoctrineDomain.accessibility,
                severity: DoctrineCore.DoctrineSeverity.error,
                title: "Accessibility analysis required",
                description: "Accessibility-related topics require explicit accessibility analysis."
            )                { context in
                    guard let bundle = context.researchBundle else {
                        return .valid(grant: nil)
                    }

                    let hasAccessibilityTags = bundle.topicSpec.doctrineTags.contains(.accessibility)
                    if !hasAccessibilityTags {
                        return .valid(grant: nil)
                    }

                    let accessibilityNotes = bundle.extractedNotes.filter { $0.tags.contains("accessibility") || $0.tags.contains("a11y") }
                    if accessibilityNotes.isEmpty {
                        return .invalid(reason: "Accessibility topic requires accessibility analysis in research")
                    }
                    return .valid(grant: nil)
                },

            // Compliance rules
            DoctrineRule(
                id: "research.compliance.open_access",
                domain: DoctrineCore.DoctrineDomain.lawCompliance,
                severity: DoctrineCore.DoctrineSeverity.warning,
                title: "Open access compliance",
                description: "Prefer open access sources when possible."
            )                { context in
                    guard let bundle = context.researchBundle else {
                        return .valid(grant: nil)
                    }

                    let openAccessPapers = bundle.papers.filter { $0.isOpenAccess }
                    let openAccessRatio = Double(openAccessPapers.count) / Double(bundle.papers.count)

                    if openAccessRatio < 0.5 {
                        return .invalid(reason: "Only \(Int(openAccessRatio * 100))% open access papers")
                    }
                    return .valid(grant: nil)
                },

            // Research freshness rules
            DoctrineRule(
                id: "research.freshness.expiration",
                domain: DoctrineCore.DoctrineDomain.computerScience,
                severity: DoctrineCore.DoctrineSeverity.error,
                title: "Research expiration",
                description: "Research bundles expire after 90 days."
            )                { context in
                    guard let bundle = context.researchBundle else {
                        return .valid(grant: nil)
                    }

                    if !bundle.isValid {
                        return .invalid(reason: "Research expired on \(bundle.expiresAt)")
                    }
                    return .valid(grant: nil)
                },

            // Adequacy threshold rule (the main gate)
            DoctrineRule(
                id: "research.adequacy.threshold",
                domain: DoctrineCore.DoctrineDomain.computerScience,
                severity: DoctrineCore.DoctrineSeverity.critical,
                title: "Research adequacy threshold",
                description: "Research must meet minimum adequacy score (70%)."
            )                { context in
                    guard let bundle = context.researchBundle else {
                        return .invalid(reason: "No research bundle provided")
                    }

                    if !bundle.isAdequate {
                        return .invalid(reason: "Research adequacy score \(Int(bundle.adequacyScore * 100))% below 70% threshold")
                    }
                    return .valid(grant: nil)
                }
        ]
    }

    /// Calculate comprehensive adequacy score for a research bundle.
    public func calculateAdequacyScore(_ bundle: ResearchBundle) -> Double {
        var score = 0.0
        let maxScore = 10.0

        // Paper count (max 2 points)
        let paperCountScore = min(Double(bundle.papers.count) / 10.0, 2.0)
        score += paperCountScore

        // Recency (max 2 points)
        let recentPapers = bundle.papers.filter { $0.isRecent }
        if recentPapers.count >= 3 {
            score += 2.0
        } else if recentPapers.count >= 1 {
            score += 1.0
        }

        // Independent sources (max 2 points)
        let institutions = Set(bundle.papers.compactMap { $0.primaryInstitution })
        if institutions.count >= 4 {
            score += 2.0
        } else if institutions.count >= 2 {
            score += 1.0
        }

        // Citation impact (max 1 point)
        let highlyCited = bundle.papers.contains { $0.isHighlyCited }
        if highlyCited {
            score += 1.0
        }

        // Limitations coverage (max 1 point)
        let limitationNotes = bundle.extractedNotes.filter { $0.noteType == .limitation }
        if !limitationNotes.isEmpty {
            score += 1.0
        }

        // Venue diversity (max 1 point)
        let venues = Set(bundle.papers.compactMap { $0.venue })
        if venues.count >= 3 {
            score += 1.0
        } else if venues.count >= 2 {
            score += 0.5
        }

        // Doctrine coverage (max 1 point)
        let coveredDomains = Set(bundle.doctrineLinks.keys)
        let requiredDomains = Set(bundle.topicSpec.doctrineTags)
        if requiredDomains.isSubset(of: coveredDomains) {
            score += 1.0
        } else if !coveredDomains.isEmpty {
            score += 0.5
        }

        return min(score / maxScore, 1.0)
    }

    /// Generate research debt tasks for inadequate research.
    public func generateDebtTasks(for bundle: ResearchBundle, blockedEntityId: UUID, blockedEntityType: String) -> [ResearchDebtTask] {
        var debtTasks: [ResearchDebtTask] = []
        let context = ResearchDoctrineContext(researchBundle: bundle)

        for rule in rules {
            let result = rule.check(context)
            if case .invalid(let reason) = result {
                let requiredActions = generateRequiredActions(for: rule.id, reason: reason)

                let debtTask = ResearchDebtTask(
                    researchBundleId: bundle.id,
                    reason: "\(rule.title): \(reason)",
                    requiredActions: requiredActions,
                    blockedEntityId: blockedEntityId,
                    blockedEntityType: blockedEntityType,
                    priority: rule.severity == .critical ? .critical : .high
                )

                debtTasks.append(debtTask)
            }
        }

        return debtTasks
    }

    private func generateRequiredActions(for ruleId: String, reason: String) -> [String] {
        switch ruleId {
        case "research.adequacy.minimum_papers":
            return [
                "Search for additional papers on the topic",
                "Expand search keywords or try different queries",
                "Consider related topics that might provide relevant papers"
            ]

        case "research.adequacy.recent_papers":
            return [
                "Search for papers published in the last 5 years",
                "Check recent conference proceedings (NeurIPS, ICML, ICLR, etc.)",
                "Look for arXiv preprints on the topic"
            ]

        case "research.adequacy.independent_sources":
            return [
                "Search for papers from different research groups",
                "Look for international collaborations",
                "Check industry research labs (Google, Microsoft, Meta, etc.)"
            ]

        case "research.adequacy.limitations_coverage":
            return [
                "Explicitly search for limitations or challenges",
                "Look for papers with 'limitations' or 'future work' sections",
                "Search for critical analyses or surveys of the field"
            ]

        case "research.security.analysis_required":
            return [
                "Search for security analysis papers on the topic",
                "Look for papers from security conferences (IEEE S&P, USENIX Security, etc.)",
                "Check for threat models or vulnerability analyses"
            ]

        case "research.accessibility.analysis_required":
            return [
                "Search for accessibility research on the topic",
                "Look for papers from accessibility conferences (ASSETS, W4A, etc.)",
                "Check for user studies with diverse populations"
            ]

        case "research.freshness.expiration":
            return [
                "Conduct new literature search",
                "Check for recent developments in the field",
                "Update research bundle with current papers"
            ]

        case "research.adequacy.threshold":
            return [
                "Address all individual research deficiencies",
                "Improve paper quality and diversity",
                "Ensure comprehensive coverage of the topic"
            ]

        default:
            return ["Improve research quality based on: \(reason)"]
        }
    }

    /// Check if a module type requires research.
    public func requiresResearch(for moduleType: String, changes: [String]) -> Bool {
        // Always require research for new modules
        if changes.contains("new_module") {
            return true
        }

        // Require research for security/infra changes
        if changes.contains("security") || changes.contains("infrastructure") {
            return true
        }

        // Don't require research for trivial changes
        let trivialChanges = ["refactor", "typo", "documentation", "test", "rename"]
        if changes.allSatisfy({ trivialChanges.contains($0) }) {
            return false
        }

        // Default: require research for significant changes
        let significantChanges = ["architecture", "api", "database", "performance", "scalability"]
        return changes.contains { significantChanges.contains($0) }
    }

    /// Get adequacy threshold for a topic.
    public func adequacyThreshold(for topicSpec: TopicSpec) -> Double {
        var threshold = 0.7  // Default threshold

        // Higher thresholds for critical domains
        if topicSpec.doctrineTags.contains(.privacy) {
            threshold = 0.8  // Security needs better research
        }

        if topicSpec.doctrineTags.contains(.accessibility) {
            threshold = 0.75  // Accessibility needs good research
        }

        // Lower thresholds for well-established topics
        if topicSpec.searchKeywords.contains("established") || topicSpec.searchKeywords.contains("standard") {
            threshold = 0.6
        }

        return threshold
    }
}

// MARK: - Research Doctrine Context

/// Context for research doctrine checks.
public struct ResearchDoctrineContext: DoctrineContext {
    public let researchBundle: ResearchBundle?

    public init(researchBundle: ResearchBundle? = nil) {
        self.researchBundle = researchBundle
    }

    public func getValue<T>(for key: String) -> T? {
        // Research-specific context values
        switch key {
        case "research_bundle":
            return researchBundle as? T
        case "papers_count":
            return researchBundle?.papers.count as? T
        case "recent_papers_count":
            let count = researchBundle?.papers.filter { $0.isRecent }.count ?? 0
            return count as? T
        case "institution_count":
            let count = Set(researchBundle?.papers.compactMap { $0.primaryInstitution } ?? []).count
            return count as? T
        case "has_limitations":
            let has = !(researchBundle?.extractedNotes.filter { $0.noteType == .limitation }.isEmpty ?? true)
            return has as? T
        case "has_security_analysis":
            let has = !(researchBundle?.extractedNotes.filter { $0.noteType == .security }.isEmpty ?? true)
            return has as? T
        case "adequacy_score":
            return researchBundle?.adequacyScore as? T
        case "is_valid":
            return researchBundle?.isValid as? T
        default:
            return nil
        }
    }
}

// MARK: - Research Adequacy Calculator

/// Calculator for research adequacy metrics.
public struct ResearchAdequacyCalculator {
    private let doctrinePack: ResearchDoctrinePack

    public init(doctrinePack: ResearchDoctrinePack = ResearchDoctrinePack()) {
        self.doctrinePack = doctrinePack
    }

    /// Calculate detailed adequacy metrics for a research bundle.
    public func calculateMetrics(_ bundle: ResearchBundle) -> ResearchAdequacyMetrics {
        let papers = bundle.papers

        // Paper metrics
        let paperCount = papers.count
        let recentPapers = papers.filter { $0.isRecent }.count
        let highlyCitedPapers = papers.filter { $0.isHighlyCited }.count
        let openAccessPapers = papers.filter { $0.isOpenAccess }.count

        // Source diversity
        let institutions = Set(papers.compactMap { $0.primaryInstitution })
        let venues = Set(papers.compactMap { $0.venue })

        // Note coverage
        let limitationNotes = bundle.extractedNotes.filter { $0.noteType == .limitation }.count
        let securityNotes = bundle.extractedNotes.filter { $0.noteType == .security }.count
        let findingNotes = bundle.extractedNotes.filter { $0.noteType == .finding }.count

        // Doctrine coverage
        let coveredDomains = Set(bundle.doctrineLinks.keys)
        let requiredDomains = Set(bundle.topicSpec.doctrineTags)
        let doctrineCoverage = requiredDomains.isEmpty ? 1.0 :
            Double(coveredDomains.intersection(requiredDomains).count) / Double(requiredDomains.count)

        // Calculate scores
        let paperCountScore = min(Double(paperCount) / 10.0, 1.0)
        let recencyScore = recentPapers >= 2 ? 1.0 : Double(recentPapers) / 2.0
        let citationScore = highlyCitedPapers > 0 ? 1.0 : 0.0
        let diversityScore = min(Double(institutions.count) / 4.0, 1.0)
        let limitationsScore = limitationNotes > 0 ? 1.0 : 0.0
        let securityScore = securityNotes > 0 ? 1.0 : 0.0

        // Weighted overall score
        let overallScore = (
            paperCountScore * 0.2 +
            recencyScore * 0.2 +
            citationScore * 0.15 +
            diversityScore * 0.15 +
            limitationsScore * 0.15 +
            securityScore * 0.15
        )

        return ResearchAdequacyMetrics(
            paperCount: paperCount,
            recentPapers: recentPapers,
            highlyCitedPapers: highlyCitedPapers,
            openAccessPapers: openAccessPapers,
            institutionCount: institutions.count,
            venueCount: venues.count,
            limitationNotes: limitationNotes,
            securityNotes: securityNotes,
            findingNotes: findingNotes,
            doctrineCoverage: doctrineCoverage,
            paperCountScore: paperCountScore,
            recencyScore: recencyScore,
            citationScore: citationScore,
            diversityScore: diversityScore,
            limitationsScore: limitationsScore,
            securityScore: securityScore,
            overallScore: overallScore,
            meetsThreshold: overallScore >= doctrinePack.adequacyThreshold(for: bundle.topicSpec)
        )
    }

    /// Generate improvement recommendations.
    public func generateRecommendations(_ bundle: ResearchBundle) -> [ResearchRecommendation] {
        var recommendations: [ResearchRecommendation] = []
        let metrics = calculateMetrics(bundle)

        if metrics.paperCount < 5 {
            recommendations.append(ResearchRecommendation(
                priority: .high,
                action: "Find more papers",
                reason: "Only \(metrics.paperCount) papers found, need at least 5",
                suggestedQueries: bundle.topicSpec.generateQueries()
            ))
        }

        if metrics.recentPapers < 2 {
            recommendations.append(ResearchRecommendation(
                priority: .medium,
                action: "Find recent papers",
                reason: "Only \(metrics.recentPapers) recent papers, need at least 2",
                suggestedQueries: bundle.topicSpec.generateQueries().map { "\($0) 2023 2024 2025" }
            ))
        }

        if metrics.institutionCount < 3 {
            recommendations.append(ResearchRecommendation(
                priority: .medium,
                action: "Diversify sources",
                reason: "Papers from only \(metrics.institutionCount) institutions",
                suggestedQueries: []
            ))
        }

        if metrics.limitationNotes == 0 {
            recommendations.append(ResearchRecommendation(
                priority: .low,
                action: "Find limitations",
                reason: "No limitations discussed",
                suggestedQueries: ["limitations of \(bundle.topicSpec.moduleName)", "challenges \(bundle.topicSpec.purpose)"]
            ))
        }

        if !metrics.meetsThreshold {
            recommendations.append(ResearchRecommendation(
                priority: .critical,
                action: "Improve overall research quality",
                reason: "Adequacy score \(Int(metrics.overallScore * 100))% below threshold",
                suggestedQueries: bundle.topicSpec.generateQueries()
            ))
        }

        return recommendations
    }
}

// MARK: - Supporting Types

/// Metrics for research adequacy.
public struct ResearchAdequacyMetrics: Sendable, Codable {
    public let paperCount: Int
    public let recentPapers: Int
    public let highlyCitedPapers: Int
    public let openAccessPapers: Int
    public let institutionCount: Int
    public let venueCount: Int
    public let limitationNotes: Int
    public let securityNotes: Int
    public let findingNotes: Int
    public let doctrineCoverage: Double
    public let paperCountScore: Double
    public let recencyScore: Double
    public let citationScore: Double
    public let diversityScore: Double
    public let limitationsScore: Double
    public let securityScore: Double
    public let overallScore: Double
    public let meetsThreshold: Bool
}

/// Recommendation for improving research.
public struct ResearchRecommendation: Sendable, Codable {
    public let priority: Priority
    public let action: String
    public let reason: String
    public let suggestedQueries: [String]

    public enum Priority: String, Sendable, Codable {
        case low, medium, high, critical
    }
}

// MARK: - Integration with Existing Doctrine System

extension ResearchDoctrinePack {
    /// Register this pack with the doctrine system.
    public static func register() {
        let pack = ResearchDoctrinePack()
        DoctrinePacks.register(pack: pack)
    }

    /// Check research adequacy using the doctrine system.
    public static func checkAdequacy(_ bundle: ResearchBundle) -> [DoctrineViolation] {
        let pack = ResearchDoctrinePack()
        let context = ResearchDoctrineContext(researchBundle: bundle)

        var violations: [DoctrineViolation] = []

        for rule in pack.rules {
            let result = rule.check(context)
            if case .invalid(let reason) = result {
                let violation = DoctrineViolation(
                    ruleId: rule.id,
                    severity: rule.severity,
                    context: "\(rule.title): \(reason)",
                    metadata: ["research_bundle_id": bundle.id.uuidString]
                )
                violations.append(violation)
            }
        }

        return violations
    }
}
