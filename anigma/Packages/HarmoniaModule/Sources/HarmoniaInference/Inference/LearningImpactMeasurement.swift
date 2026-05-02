//
//  LearningImpactMeasurement.swift
//  HarmoniaModule
//
//  Implements learning impact measurement and curated training data management.
//  Based on research showing that tiny, high-quality datasets outperform massive ones.
//
//  Features:
//  - Impact scoring for reasoning traces
//  - UPFT-style prefix extraction
//  - Domain-specific training data curation
//  - Synthetic puzzle generation integration
//

@preconcurrency import Foundation
import Foundation
import HarmoniaCore
import AnigmaPrimitives
import InferenceCore
import AnigmaCore

// MARK: - Reasoning Trace

/// A captured reasoning trace from model execution.
public struct ReasoningTrace: Sendable, Codable, Identifiable {
    public let id: String
    public let domain: TrainingDomain
    public let taskType: String
    public let input: String
    public let reasoning: String
    public let output: String
    public let metadata: TraceMetadata
    public let quality: TraceQuality
    public let timestamp: Date

    public init(
        id: String = UUID().uuidString,
        domain: TrainingDomain,
        taskType: String,
        input: String,
        reasoning: String,
        output: String,
        metadata: TraceMetadata,
        quality: TraceQuality
    ) {
        self.id = id
        self.domain = domain
        self.taskType = taskType
        self.input = input
        self.reasoning = reasoning
        self.output = output
        self.metadata = metadata
        self.quality = quality
        self.timestamp = Date()
    }
}

/// Domains for training data.
public enum TrainingDomain: String, Sendable, Codable, CaseIterable {
    case dsps               // DSPS workflows and accommodations
    case transcriptum       // Academic records and degree auditing
    case compliance         // Governance and policy compliance
    case coding             // Code generation and editing
    case general            // General reasoning
    case institutional      // Institution-specific knowledge
}

/// Metadata about a reasoning trace.
public struct TraceMetadata: Sendable, Codable {
    public let modelId: String
    public let modelVersion: String
    public let promptTemplate: String?
    public let tokensIn: Int
    public let tokensOut: Int
    public let latency: TimeInterval
    public let wasCorrect: Bool?
    public let humanVerified: Bool
    public let sourceType: TraceSourceType

    public init(
        modelId: String,
        modelVersion: String,
        promptTemplate: String? = nil,
        tokensIn: Int,
        tokensOut: Int,
        latency: TimeInterval,
        wasCorrect: Bool? = nil,
        humanVerified: Bool = false,
        sourceType: TraceSourceType = .production
    ) {
        self.modelId = modelId
        self.modelVersion = modelVersion
        self.promptTemplate = promptTemplate
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.latency = latency
        self.wasCorrect = wasCorrect
        self.humanVerified = humanVerified
        self.sourceType = sourceType
    }
}

/// Source of a trace.
public enum TraceSourceType: String, Sendable, Codable {
    case production         // From real usage
    case synthetic          // Generated synthetically
    case curated            // Hand-crafted exemplar
    case distilled          // Distilled from larger model
}

/// Quality assessment of a trace.
public struct TraceQuality: Sendable, Codable {
    /// Overall quality score (0-1).
    public let overallScore: Double

    /// Reasoning structure score.
    public let structureScore: Double

    /// Correctness score (if verifiable).
    public let correctnessScore: Double?

    /// Clarity and coherence score.
    public let clarityScore: Double

    /// Whether trace follows domain patterns.
    public let followsDomainPatterns: Bool

    /// Identified quality issues.
    public let issues: [TraceQualityIssue]

    public init(
        overallScore: Double,
        structureScore: Double,
        correctnessScore: Double? = nil,
        clarityScore: Double,
        followsDomainPatterns: Bool,
        issues: [TraceQualityIssue] = []
    ) {
        self.overallScore = overallScore
        self.structureScore = structureScore
        self.correctnessScore = correctnessScore
        self.clarityScore = clarityScore
        self.followsDomainPatterns = followsDomainPatterns
        self.issues = issues
    }

    /// Whether trace meets minimum quality bar.
    public var meetsQualityBar: Bool {
        overallScore >= 0.7 && structureScore >= 0.6 && clarityScore >= 0.6
    }
}

/// Issues found in trace quality.
public enum TraceQualityIssue: String, Sendable, Codable, CaseIterable {
    case lacksStructure
    case missingConstraintCheck
    case verboseReasoning
    case jumpedToConclusion
    case incorrectResult
    case hallucinatedFacts
    case missingUncertainty
    case offTopic
}

// MARK: - Impact Measurement

/// Measures learning impact of training data.
public actor LearningImpactMeasurer {
    /// Traces by domain.
    private var tracesByDomain: [TrainingDomain: [ReasoningTrace]] = [:]

    /// Impact scores by trace ID.
    private var impactScores: [String: ImpactScore] = [:]

    /// Curated trace sets by domain.
    private var curatedSets: [TrainingDomain: CuratedTraceSet] = [:]

    /// Maximum traces per domain before pruning.
    private let maxTracesPerDomain = 10000

    public init() {}

    // MARK: - Trace Collection

    /// Records a reasoning trace.
    public func record(_ trace: ReasoningTrace) {
        var traces = tracesByDomain[trace.domain] ?? []
        traces.append(trace)

        // Prune if needed
        if traces.count > maxTracesPerDomain {
            traces = pruneTraces(traces)
        }

        tracesByDomain[trace.domain] = traces
    }

    /// Gets traces for a domain.
    public func traces(for domain: TrainingDomain) -> [ReasoningTrace] {
        tracesByDomain[domain] ?? []
    }

    // MARK: - Impact Scoring

    /// Scores the learning impact of a trace.
    public func scoreImpact(
        traceId: String,
        benchmarkResults: LearningBenchmarkResults
    ) -> ImpactScore {
        let score = ImpactScore(
            traceId: traceId,
            heldOutImprovement: benchmarkResults.improvementOverBaseline,
            noveltyScore: benchmarkResults.noveltyScore,
            diversityContribution: benchmarkResults.diversityContribution,
            domainCoverage: benchmarkResults.domainCoverage,
            computedAt: Date()
        )

        impactScores[traceId] = score
        return score
    }

    /// Gets impact score for a trace.
    public func getImpactScore(_ traceId: String) -> ImpactScore? {
        impactScores[traceId]
    }

    /// Selects high-impact traces for training.
    public func selectHighImpactTraces(
        domain: TrainingDomain,
        count: Int,
        minImpact: Double = 0.3
    ) -> [ReasoningTrace] {
        let traces = tracesByDomain[domain] ?? []

        return traces
            .filter { trace in
                guard let score = impactScores[trace.id] else { return false }
                return score.overallImpact >= minImpact
            }
            .sorted { lhs, rhs in
                let lhsImpact = impactScores[lhs.id]?.overallImpact ?? 0
                let rhsImpact = impactScores[rhs.id]?.overallImpact ?? 0
                return lhsImpact > rhsImpact
            }
            .prefix(count)
            .map { $0 }
    }

    // MARK: - Curated Sets

    /// Creates or updates a curated trace set.
    public func createCuratedSet(
        domain: TrainingDomain,
        name: String,
        description: String,
        maxSize: Int = 117  // "117 examples beat 100k"
    ) -> CuratedTraceSet {
        let set = CuratedTraceSet(
            id: UUID().uuidString,
            domain: domain,
            name: name,
            description: description,
            maxSize: maxSize,
            traceIds: [],
            createdAt: Date(),
            lastUpdated: Date()
        )

        curatedSets[domain] = set
        return set
    }

    /// Adds a trace to the curated set.
    public func addToCuratedSet(
        domain: TrainingDomain,
        traceId: String
    ) -> Bool {
        guard var set = curatedSets[domain] else { return false }
        guard set.traceIds.count < set.maxSize else { return false }

        set.traceIds.append(traceId)
        set.lastUpdated = Date()
        curatedSets[domain] = set
        return true
    }

    /// Gets the curated set for a domain.
    public func getCuratedSet(_ domain: TrainingDomain) -> CuratedTraceSet? {
        curatedSets[domain]
    }

    // MARK: - Private Helpers

    private func pruneTraces(_ traces: [ReasoningTrace]) -> [ReasoningTrace] {
        // Keep traces with good quality and measured impact
        return traces
            .filter { $0.quality.meetsQualityBar }
            .sorted { lhs, rhs in
                let lhsImpact = impactScores[lhs.id]?.overallImpact ?? 0
                let rhsImpact = impactScores[rhs.id]?.overallImpact ?? 0
                return lhsImpact > rhsImpact
            }
            .prefix(maxTracesPerDomain / 2)
            .map { $0 }
    }
}

/// Impact score for a trace.
public struct ImpactScore: Sendable, Codable {
    public let traceId: String
    public let heldOutImprovement: Double
    public let noveltyScore: Double
    public let diversityContribution: Double
    public let domainCoverage: Double
    public let computedAt: Date

    /// Overall impact (weighted combination).
    public var overallImpact: Double {
        heldOutImprovement * 0.5 +
        noveltyScore * 0.2 +
        diversityContribution * 0.2 +
        domainCoverage * 0.1
    }
}

/// Learning impact benchmark results.
public struct LearningBenchmarkResults: Sendable {
    public let improvementOverBaseline: Double
    public let noveltyScore: Double
    public let diversityContribution: Double
    public let domainCoverage: Double

    public init(
        improvementOverBaseline: Double,
        noveltyScore: Double,
        diversityContribution: Double,
        domainCoverage: Double
    ) {
        self.improvementOverBaseline = improvementOverBaseline
        self.noveltyScore = noveltyScore
        self.diversityContribution = diversityContribution
        self.domainCoverage = domainCoverage
    }
}

/// A curated set of traces for training.
public struct CuratedTraceSet: Sendable, Codable {
    public let id: String
    public let domain: TrainingDomain
    public let name: String
    public let description: String
    public let maxSize: Int
    public var traceIds: [String]
    public let createdAt: Date
    public var lastUpdated: Date

    public var isFull: Bool { traceIds.count >= maxSize }
}

// MARK: - UPFT Prefix Extraction

/// Extracts prefixes from reasoning traces for UPFT-style training.
public actor UPFTExtractor {
    /// Configuration for prefix extraction.
    private var config: UPFTConfig = .default

    /// Extracted prefixes by domain.
    private var prefixesByDomain: [TrainingDomain: [ExtractedPrefix]] = [:]

    public init() {}

    // MARK: - Configuration

    /// Sets UPFT configuration.
    public func configure(_ config: UPFTConfig) {
        self.config = config
    }

    // MARK: - Extraction

    /// Extracts prefix from a reasoning trace.
    public func extractPrefix(from trace: ReasoningTrace) -> ExtractedPrefix? {
        let reasoning = trace.reasoning

        // Find the stable prefix portion
        let prefixEnd = findStablePrefixEnd(reasoning)
        guard prefixEnd > config.minPrefixTokens else { return nil }

        let prefixText = String(reasoning.prefix(prefixEnd * 4))  // Approximate token-to-char

        // Anonymize the prefix
        let anonymized = anonymizePrefix(prefixText, domain: trace.domain)

        let prefix = ExtractedPrefix(
            id: UUID().uuidString,
            sourceTraceId: trace.id,
            domain: trace.domain,
            prefixText: anonymized,
            estimatedTokens: prefixEnd,
            structure: identifyStructure(anonymized),
            timestamp: Date()
        )

        // Store it
        var prefixes = prefixesByDomain[trace.domain] ?? []
        prefixes.append(prefix)
        prefixesByDomain[trace.domain] = prefixes

        return prefix
    }

    /// Extracts prefixes from multiple traces for the same task.
    public func extractConsensusPrefix(
        from traces: [ReasoningTrace]
    ) -> ExtractedPrefix? {
        guard traces.count >= config.minTracesForConsensus else { return nil }
        guard let domain = traces.first?.domain else { return nil }

        // Find common prefix length
        let reasonings = traces.map { $0.reasoning }
        let commonPrefixLength = findCommonPrefixLength(reasonings)

        guard commonPrefixLength >= config.minPrefixTokens * 4 else { return nil }

        let prefixText = String(reasonings[0].prefix(commonPrefixLength))
        let anonymized = anonymizePrefix(prefixText, domain: domain)

        return ExtractedPrefix(
            id: UUID().uuidString,
            sourceTraceId: "consensus:\(traces.map { $0.id }.joined(separator: ","))",
            domain: domain,
            prefixText: anonymized,
            estimatedTokens: commonPrefixLength / 4,
            structure: identifyStructure(anonymized),
            timestamp: Date()
        )
    }

    /// Gets extracted prefixes for a domain.
    public func prefixes(for domain: TrainingDomain) -> [ExtractedPrefix] {
        prefixesByDomain[domain] ?? []
    }

    // MARK: - Private Helpers

    private func findStablePrefixEnd(_ text: String) -> Int {
        // Heuristic: find where reasoning diverges (task-specific decisions)
        // Look for transition markers
        let markers = ["Therefore,", "So,", "Thus,", "Given that,", "I will", "Let me"]

        var minMarkerPosition = text.count
        for marker in markers {
            if let range = text.range(of: marker) {
                let position = text.distance(from: text.startIndex, to: range.lowerBound)
                minMarkerPosition = min(minMarkerPosition, position)
            }
        }

        // Cap at max prefix length
        let maxChars = config.maxPrefixTokens * 4
        return min(minMarkerPosition, maxChars) / 4  // Convert to approximate tokens
    }

    private func findCommonPrefixLength(_ strings: [String]) -> Int {
        guard let first = strings.first else { return 0 }

        var commonLength = 0
        for i in 0..<first.count {
            let char = first[first.index(first.startIndex, offsetBy: i)]
            let allMatch = strings.allSatisfy { s in
                i < s.count && s[s.index(s.startIndex, offsetBy: i)] == char
            }
            if allMatch {
                commonLength = i + 1
            } else {
                break
            }
        }

        return commonLength
    }

    private func anonymizePrefix(_ text: String, domain: TrainingDomain) -> String {
        var result = text

        // Replace specific patterns with generic tokens
        let patterns: [(pattern: String, replacement: String)] = [
            ("\\b\\d{7,}\\b", "[ID]"),                      // Long numbers (IDs)
            ("\\b[A-Z]{2,}\\d{3,}\\b", "[CODE]"),          // Course codes like ENG101
            ("[A-Za-z]+@[A-Za-z.]+", "[EMAIL]"),           // Emails
            ("\\b\\d{1,2}/\\d{1,2}/\\d{2,4}\\b", "[DATE]"), // Dates
            ("\\b(Spring|Fall|Summer|Winter) \\d{4}\\b", "[TERM]") // Terms
        ]

        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }

        return result
    }

    private func identifyStructure(_ text: String) -> PrefixStructure {
        var elements: [PrefixElement] = []

        if text.contains("Given:") || text.contains("Input:") {
            elements.append(.problemRestatement)
        }
        if text.contains("Constraint") || text.contains("must") || text.contains("require") {
            elements.append(.constraintEnumeration)
        }
        if text.contains("First,") || text.contains("Step 1") || text.contains("I will") {
            elements.append(.planOutline)
        }
        if text.contains("check") || text.contains("verify") || text.contains("ensure") {
            elements.append(.invariantCheck)
        }

        return PrefixStructure(elements: Set(elements))
    }
}

/// Configuration for UPFT extraction.
public struct UPFTConfig: Sendable {
    public var minPrefixTokens: Int
    public var maxPrefixTokens: Int
    public var minTracesForConsensus: Int
    public var anonymizePII: Bool

    public init(
        minPrefixTokens: Int = 50,
        maxPrefixTokens: Int = 300,
        minTracesForConsensus: Int = 3,
        anonymizePII: Bool = true
    ) {
        self.minPrefixTokens = minPrefixTokens
        self.maxPrefixTokens = maxPrefixTokens
        self.minTracesForConsensus = minTracesForConsensus
        self.anonymizePII = anonymizePII
    }

    public static let `default` = UPFTConfig()
}

/// An extracted prefix for UPFT training.
public struct ExtractedPrefix: Sendable, Codable, Identifiable {
    public let id: String
    public let sourceTraceId: String
    public let domain: TrainingDomain
    public let prefixText: String
    public let estimatedTokens: Int
    public let structure: PrefixStructure
    public let timestamp: Date
}

/// Structure of a reasoning prefix.
public struct PrefixStructure: Sendable, Codable {
    public let elements: Set<PrefixElement>

    public var isWellFormed: Bool {
        elements.contains(.problemRestatement) &&
        (elements.contains(.constraintEnumeration) || elements.contains(.planOutline))
    }
}

/// Elements found in a prefix.
public enum PrefixElement: String, Sendable, Codable, CaseIterable {
    case problemRestatement
    case constraintEnumeration
    case planOutline
    case invariantCheck
    case contextGathering
    case hypothesisFormation
}

// MARK: - Domain-Specific Trace Templates

/// Templates for generating high-quality domain traces.
public struct DomainTraceTemplates {
    /// DSPS workflow trace template.
    public static let dspsWorkflow = """
    Given: A student with [STUDENT_TYPE] has requested [ACCOMMODATION_TYPE] for [COURSE_TYPE].

    Constraints:
    1. Accommodations must be documented and approved
    2. Instructor notification is required within [TIMELINE]
    3. Alt-media must be ready before [DEADLINE]
    4. FERPA compliance must be maintained

    I will:
    1. Verify student eligibility status
    2. Check accommodation documentation
    3. Generate instructor notification
    4. Queue alt-media production if needed
    5. Log all actions for audit trail

    Checking invariants:
    - No accommodation granted without documentation: [CHECK]
    - Timeline constraints satisfied: [CHECK]
    - Privacy boundaries respected: [CHECK]
    """

    /// Transcriptum degree audit template.
    public static let degreeAudit = """
    Given: Student record showing [UNITS_COMPLETED] units toward [PROGRAM_NAME].

    Requirements:
    1. Core courses: [CORE_LIST]
    2. Electives: [ELECTIVE_REQUIREMENTS]
    3. GPA minimum: [GPA_THRESHOLD]
    4. Residency: [RESIDENCY_REQUIREMENT]

    I will:
    1. Map completed courses to requirements
    2. Calculate requirement satisfaction
    3. Identify remaining requirements
    4. Verify no constraint violations

    Checking invariants:
    - No double-counting of courses: [CHECK]
    - GPA calculations correct: [CHECK]
    - All requirements from current catalog version: [CHECK]
    """

    /// Compliance policy check template.
    public static let complianceCheck = """
    Given: Proposed action [ACTION_TYPE] on [ENTITY_TYPE] by [PRINCIPAL_TYPE].

    Applicable controls:
    1. Access control: [AC_CONTROLS]
    2. Audit requirements: [AU_CONTROLS]
    3. Data protection: [SC_CONTROLS]

    I will:
    1. Identify all applicable policies
    2. Evaluate action against each policy
    3. Determine if action is permitted
    4. Generate evidence for audit trail

    Checking invariants:
    - All relevant controls evaluated: [CHECK]
    - Decision is explainable: [CHECK]
    - Audit entry will be created: [CHECK]
    """
}
