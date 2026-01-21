//
//  ReflexiveAnalytics.swift
//  AnigmaCore
//
//  Reflexive analytics for self-improvement.
//  Normalizes traces and detects patterns for campaign planning.
//

import Foundation
import ContractsCore
import CryptoKit
import AnigmaPrimitives

/// Actor-based reflexive analytics service
public actor ReflexiveAnalytics {

    // MARK: - Dependencies

    private let auditLog: any AuditLogging
    private let evidenceRecorder: any EvidenceRecording
    private let config: ReflexiveAnalyticsConfig

    // MARK: - State

    private var normalizedTraces: [TraceId: NormalizedTrace] = [:]
    private var detectedPatterns: [PatternId: DetectedPattern] = [:]
    private var campaignRecommendations: [CampaignId: CampaignRecommendation] = [:]

    // MARK: - Initialization

    public init(
        auditLog: any AuditLogging,
        evidenceRecorder: any EvidenceRecording,
        config: ReflexiveAnalyticsConfig = .default
    ) {
        self.auditLog = auditLog
        self.evidenceRecorder = evidenceRecorder
        self.config = config
    }

    // MARK: - Public Interface

    /// Normalize trace for analytics
    public func normalizeTrace(_ trace: StepTrace) async throws -> NormalizedTrace {
        let startTime = Date()

        // Extract key metrics
        let metrics = extractMetrics(from: trace)

        // Normalize events
        let normalizedEvents = try await normalizeEvents(trace.events)

        // Create fingerprint for pattern matching
        let fingerprint = generateFingerprint(from: trace)

        // Create normalized trace
        let normalized = NormalizedTrace(
            id: trace.id,
            originalTrace: trace,
            metrics: metrics,
            normalizedEvents: normalizedEvents,
            fingerprint: fingerprint,
            timestamp: startTime,
            metadata: NormalizationMetadata(
                version: "1.0",
                algorithm: "v1",
                confidence: calculateNormalizationConfidence(trace)
            )
        )

        // Store normalized trace
        normalizedTraces[trace.id] = normalized

        // Persist through evidence recorder
        let normalizedTraceData = try JSONEncoder().encode(normalized)
        let normalizedTraceHash = SHA256.hash(data: normalizedTraceData)
        let normalizedTraceHead = EvidenceHead(
            headId: normalized.id.value,
            headHash: normalizedTraceHash.compactMap { String(format: "%02x", $0) }.joined(),
            timestamp: Date(),
            lastActor: "ReflexiveAnalytics"
        )
        try await evidenceRecorder.recordEvidence(head: normalizedTraceHead, content: normalizedTraceData)

        // Log to audit trail
        try await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.custom,
            principal: "ReflexiveAnalytics",
            module: "ReflexiveAnalytics",
            description: "Normalized trace with \(normalizedEvents.count) events",
            metadata: [
                "traceId": trace.id.value,
                "eventCount": "\(trace.events.count)",
                "fingerprint": fingerprint,
                "command": "normalize",
                "exitCode": "0",
                "output": "Normalized trace with \(normalizedEvents.count) events",
                "duration": "\(Date().timeIntervalSince(startTime))",
                "timedOut": "false",
                "original_event_type": "normalizeTrace"
            ]
        )

        return normalized
    }

    /// Detect patterns in normalized traces
    public func detectPatterns(
        traceIds: [TraceId]? = nil,
        patternTypes: [PatternType]? = nil
    ) async throws -> [DetectedPattern] {
        let startTime = Date()

        // Get traces to analyze
        let tracesToAnalyze = traceIds.map { ids in
            ids.compactMap { normalizedTraces[$0] }
        } ?? Array(normalizedTraces.values)

        var detected: [DetectedPattern] = []

        // Run pattern detectors
        let patternDetectors = createPatternDetectors()

        for detector in patternDetectors {
            // Skip if pattern type not requested
            if let patternTypes = patternTypes, !patternTypes.contains(detector.patternType) {
                continue
            }

            let patterns = try await detector.detect(in: tracesToAnalyze)
            detected.append(contentsOf: patterns)
        }

        // Store detected patterns
        for pattern in detected {
            detectedPatterns[pattern.id] = pattern
        }

        // Log to audit trail
        try await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.custom,
            principal: "ReflexiveAnalytics",
            module: "ReflexiveAnalytics",
            description: "Detected \(detected.count) patterns",
            metadata: [
                "traceCount": "\(tracesToAnalyze.count)",
                "patternCount": "\(detected.count)",
                "detectorCount": "\(patternDetectors.count)",
                "command": "detect",
                "exitCode": "0",
                "output": "Detected \(detected.count) patterns",
                "duration": "\(Date().timeIntervalSince(startTime))",
                "timedOut": "false",
                "original_event_type": "detectPatterns"
            ]
        )

        return detected
    }

    /// Generate campaign recommendations from patterns
    public func generateCampaigns(
        patternIds: [PatternId]? = nil
    ) async throws -> [CampaignRecommendation] {
        let startTime = Date()

        // Get patterns to analyze
        let patternsToAnalyze = patternIds.map { ids in
            ids.compactMap { detectedPatterns[$0] }
        } ?? Array(detectedPatterns.values)

        var campaigns: [CampaignRecommendation] = []

        // Run campaign planners
        let campaignPlanners = createCampaignPlanners()

        for planner in campaignPlanners {
            let recommendations = try await planner.plan(from: patternsToAnalyze)
            campaigns.append(contentsOf: recommendations)
        }

        // Store campaign recommendations
        for campaign in campaigns {
            campaignRecommendations[campaign.id] = campaign
        }

        // Persist through evidence recorder
        let campaignRecommendationsData = try JSONEncoder().encode(campaigns)
        let campaignRecommendationsHash = SHA256.hash(data: campaignRecommendationsData)
        let campaignRecommendationsHead = EvidenceHead(
            headId: UUID().uuidString,
            headHash: campaignRecommendationsHash.compactMap { String(format: "%02x", $0) }.joined(),
            timestamp: Date(),
            lastActor: "ReflexiveAnalytics"
        )
        try await evidenceRecorder.recordEvidence(head: campaignRecommendationsHead, content: campaignRecommendationsData)

        // Log to audit trail
        try await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.custom,
            principal: "ReflexiveAnalytics",
            module: "ReflexiveAnalytics",
            description: "Generated \(campaigns.count) campaign recommendations",
            metadata: [
                "patternCount": "\(patternsToAnalyze.count)",
                "campaignCount": "\(campaigns.count)",
                "plannerCount": "\(campaignPlanners.count)",
                "command": "plan",
                "exitCode": "0",
                "output": "Generated \(campaigns.count) campaign recommendations",
                "duration": "\(Date().timeIntervalSince(startTime))",
                "timedOut": "false",
                "original_event_type": "generateCampaigns"
            ]
        )

        return campaigns
    }

    /// Get normalized trace by ID
    public func getNormalizedTrace(_ traceId: TraceId) async -> NormalizedTrace? {
        return normalizedTraces[traceId]
    }

    /// Get detected pattern by ID
    public func getDetectedPattern(_ patternId: PatternId) async -> DetectedPattern? {
        return detectedPatterns[patternId]
    }

    /// Get campaign recommendation by ID
    public func getCampaignRecommendation(_ campaignId: CampaignId) async -> CampaignRecommendation? {
        return campaignRecommendations[campaignId]
    }

    /// Get all detected patterns
    public func getAllDetectedPatterns() async -> [DetectedPattern] {
        return Array(detectedPatterns.values)
    }

    /// Get all campaign recommendations
    public func getAllCampaignRecommendations() async -> [CampaignRecommendation] {
        return Array(campaignRecommendations.values)
    }

    // MARK: - Private Methods

    /// Extract metrics from trace
    private func extractMetrics(from trace: StepTrace) -> TraceMetrics {
        let duration = trace.events.last?.timestamp.timeIntervalSince(trace.timestamp) ?? 0

        let candidateCount = trace.candidates.count
        let policyViolationCount = trace.decision.policyViolations.count
        let eventCount = trace.events.count

        // Calculate success rate
        let successRate = trace.output?.status == .completed ? 1.0 : 0.0

        // Calculate average confidence
        let avgConfidence = trace.candidates.isEmpty ? 0.0 :
            trace.candidates.map { $0.confidence }.reduce(0, +) / Double(trace.candidates.count)

        // Calculate risk score
        let riskScore = trace.candidates.isEmpty ? 0.0 :
            trace.candidates.map { candidate in
                mapRiskLevel(candidate.estimatedImpact.riskLevel)
            }.reduce(0, +) / Double(trace.candidates.count)

        return TraceMetrics(
            duration: duration,
            candidateCount: candidateCount,
            policyViolationCount: policyViolationCount,
            eventCount: eventCount,
            successRate: successRate,
            averageConfidence: avgConfidence,
            riskScore: riskScore
        )
    }

    /// Normalize events
    private func normalizeEvents(_ events: [TraceEvent]) async throws -> [NormalizedEvent] {
        return events.map { event in
            NormalizedEvent(
                id: event.id,
                originalEvent: event,
                category: categorizeEvent(event.type),
                severity: normalizeSeverity(event.severity),
                timestamp: event.timestamp,
                duration: calculateEventDuration(event, in: events),
                component: normalizeComponent(event.component),
                message: normalizeMessage(event.message),
                data: normalizeEventData(event.data)
            )
        }
    }

    /// Generate fingerprint for pattern matching
    private func generateFingerprint(from trace: StepTrace) -> String {
        var components: [String] = []

        // Add step kind
        components.append("step:\(trace.input.stepId.value)")

        // Add outcome
        if let output = trace.output {
            components.append("outcome:\(output.status.rawValue)")
        }

        // Add key event types
        let eventTypes = trace.events.map { $0.type.rawValue }.sorted()
        components.append("events:\(eventTypes.joined(separator: ","))")

        // Add policy violations
        if !trace.decision.policyViolations.isEmpty {
            let violations = trace.decision.policyViolations.map { $0.policy }.sorted()
            components.append("violations:\(violations.joined(separator: ","))")
        }

        // Create fingerprint
        let fingerprint = components.joined(separator: "|")
        return fingerprint.sha256
    }

    /// Calculate normalization confidence
    private func calculateNormalizationConfidence(_ trace: StepTrace) -> Double {
        // Base confidence on completeness and consistency
        var confidence = 1.0

        // Check for required events
        let hasStart = trace.events.contains { $0.type == .stepStarted }
        let hasEnd = trace.events.contains { $0.type == .stepCompleted || $0.type == .stepFailed }

        if !hasStart || !hasEnd {
            confidence *= 0.8  // Missing start/end events
        }

        // Check for decision
        if trace.decision.selectedCandidate == nil && trace.decision.rejectionReason == nil {
            confidence *= 0.9  // Unclear decision
        }

        // Check for output consistency
                    if let output = trace.output {
                        let expectedStatus = trace.decision.selectedCandidate != nil ? StepStatus.completed : StepStatus.failed
                        if output.status != expectedStatus {
                            confidence *= 0.7  // Inconsistent status
                        }
                    } else {
                        confidence *= 0.9  // Missing output
                    }
        return confidence
    }

    /// Categorize event type
    private func categorizeEvent(_ type: EventType) -> EventCategory {
        switch type {
        case .stepStarted, .stepCompleted, .stepFailed:
            return .lifecycle
        case .candidateGenerated, .candidateEvaluated, .candidateSelected, .candidateRejected:
            return .decision
        case .policyChecked, .policyViolated:
            return .policy
        case .quarantineTriggered:
            return .security
        case .resourceExhausted, .timeout:
            return .resource
        @unknown default:
            return .other
        }
    }

    /// Normalize severity
    private func normalizeSeverity(_ severity: EventSeverity) -> NormalizedSeverity {
        switch severity {
        case .debug, .info:
            return .low
        case .warning:
            return .medium
        case .error, .critical:
            return .high
        }
    }

    /// Calculate event duration
    private func calculateEventDuration(_ event: TraceEvent, in events: [TraceEvent]) -> TimeInterval {
        guard event.type == .stepCompleted || event.type == .stepFailed else {
            return 0
        }

        // Find corresponding start event
        if let startEvent = events.first(where: {
            $0.type == .stepStarted && $0.timestamp < event.timestamp
        }) {
            return event.timestamp.timeIntervalSince(startEvent.timestamp)
        }

        return 0
    }

    /// Normalize component name
    private func normalizeComponent(_ component: String) -> String {
        // Normalize component names for pattern matching
        return component
            .lowercased()
            .replacingOccurrences(of: "system", with: "core")
            .replacingOccurrences(of: "engine", with: "service")
    }

    /// Normalize message
    private func normalizeMessage(_ message: String) -> String {
        return message
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    /// Normalize event data
    private func normalizeEventData(_ data: [String: String]) -> [String: String] {
        var normalized: [String: String] = [:]

        for (key, value) in data {
            normalized[key.lowercased()] = value.lowercased()
        }

        return normalized
    }

    /// Map risk level to numeric score
    private func mapRiskLevel(_ riskLevel: AnigmaPrimitives.RiskLevel) -> Double {
        switch riskLevel {
        case .low: return 0.25
        case .medium: return 0.5
        case .high: return 0.75
        case .critical: return 1.0
        }
    }

    /// Create pattern detectors
    private func createPatternDetectors() -> [PatternDetector] {
        return [
            RepeatedFailureDetector(),
            PolicyViolationDetector(),
            PerformanceDegradationDetector(),
            ResourceExhaustionDetector(),
            QuarantinePatternDetector()
        ]
    }

    /// Create campaign planners
    private func createCampaignPlanners() -> [CampaignPlanner] {
        return [
            FailureAnalysisPlanner(),
            PolicyImprovementPlanner(),
            PerformanceOptimizationPlanner(),
            ResourceScalingPlanner()
        ]
    }
}

// MARK: - Supporting Types

/// Configuration for reflexive analytics
public struct ReflexiveAnalyticsConfig: Sendable {
    public let maxTracesInMemory: Int
    public let maxPatternsInMemory: Int
    public let maxCampaignsInMemory: Int
    public let enablePersistence: Bool
    public let patternDetectionThreshold: Double

    public init(
        maxTracesInMemory: Int = 1000,
        maxPatternsInMemory: Int = 500,
        maxCampaignsInMemory: Int = 100,
        enablePersistence: Bool = true,
        patternDetectionThreshold: Double = 0.7
    ) {
        self.maxTracesInMemory = maxTracesInMemory
        self.maxPatternsInMemory = maxPatternsInMemory
        self.maxCampaignsInMemory = maxCampaignsInMemory
        self.enablePersistence = enablePersistence
        self.patternDetectionThreshold = patternDetectionThreshold
    }

    public static let `default` = ReflexiveAnalyticsConfig()
}

/// Normalized trace for analytics
public struct NormalizedTrace: Sendable, Codable {
    public let id: TraceId
    public let originalTrace: StepTrace
    public let metrics: TraceMetrics
    public let normalizedEvents: [NormalizedEvent]
    public let fingerprint: String
    public let timestamp: Date
    public let metadata: NormalizationMetadata

    public init(
        id: TraceId,
        originalTrace: StepTrace,
        metrics: TraceMetrics,
        normalizedEvents: [NormalizedEvent],
        fingerprint: String,
        timestamp: Date,
        metadata: NormalizationMetadata
    ) {
        self.id = id
        self.originalTrace = originalTrace
        self.metrics = metrics
        self.normalizedEvents = normalizedEvents
        self.fingerprint = fingerprint
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

/// Metrics extracted from trace
public struct TraceMetrics: Sendable, Codable {
    public let duration: TimeInterval
    public let candidateCount: Int
    public let policyViolationCount: Int
    public let eventCount: Int
    public let successRate: Double
    public let averageConfidence: Double
    public let riskScore: Double

    public init(
        duration: TimeInterval,
        candidateCount: Int,
        policyViolationCount: Int,
        eventCount: Int,
        successRate: Double,
        averageConfidence: Double,
        riskScore: Double
    ) {
        self.duration = duration
        self.candidateCount = candidateCount
        self.policyViolationCount = policyViolationCount
        self.eventCount = eventCount
        self.successRate = successRate
        self.averageConfidence = averageConfidence
        self.riskScore = riskScore
    }
}

/// Normalized event for analytics
public struct NormalizedEvent: Sendable, Codable {
    public let id: EventId
    public let originalEvent: TraceEvent
    public let category: EventCategory
    public let severity: NormalizedSeverity
    public let timestamp: Date
    public let duration: TimeInterval
    public let component: String
    public let message: String
    public let data: [String: String]

    public init(
        id: EventId,
        originalEvent: TraceEvent,
        category: EventCategory,
        severity: NormalizedSeverity,
        timestamp: Date,
        duration: TimeInterval,
        component: String,
        message: String,
        data: [String: String]
    ) {
        self.id = id
        self.originalEvent = originalEvent
        self.category = category
        self.severity = severity
        self.timestamp = timestamp
        self.duration = duration
        self.component = component
        self.message = message
        self.data = data
    }
}

/// Metadata for normalization
public struct NormalizationMetadata: Sendable, Codable {
    public let version: String
    public let algorithm: String
    public let confidence: Double

    public init(version: String, algorithm: String, confidence: Double) {
        self.version = version
        self.algorithm = algorithm
        self.confidence = confidence
    }
}

/// Category of event
public enum EventCategory: String, Sendable, Codable {
    case lifecycle = "lifecycle"
    case decision = "decision"
    case policy = "policy"
    case security = "security"
    case resource = "resource"
    case other = "other"

    public var description: String {
        switch self {
        case .lifecycle: return "Step lifecycle events"
        case .decision: return "Decision-making events"
        case .policy: return "Policy evaluation events"
        case .security: return "Security-related events"
        case .resource: return "Resource usage events"
        case .other: return "Other events"
        }
    }
}

/// Normalized severity
public enum NormalizedSeverity: String, Sendable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    public var description: String {
        switch self {
        case .low: return "Low severity"
        case .medium: return "Medium severity"
        case .high: return "High severity"
        }
    }
}

// MARK: - Pattern Detection

/// Protocol for pattern detectors
public protocol PatternDetector: Sendable {
    var patternType: PatternType { get }
    func detect(in traces: [NormalizedTrace]) async throws -> [DetectedPattern]
}

/// Type of pattern
public enum PatternType: String, Sendable, Codable {
    case repeatedFailure = "repeated_failure"
    case policyViolation = "policy_violation"
    case performanceDegradation = "performance_degradations"
    case resourceExhaustion = "resource_exhaustion"
    case quarantinePattern = "quarantine_pattern"

    public var description: String {
        switch self {
        case .repeatedFailure: return "Repeated failure pattern"
        case .policyViolation: return "Policy violation pattern"
        case .performanceDegradation: return "Performance degradations pattern"
        case .resourceExhaustion: return "Resource exhaustion pattern"
        case .quarantinePattern: return "Quarantine pattern"
        }
    }
}

/// Detected pattern
public struct DetectedPattern: Sendable, Codable {
    public let id: PatternId
    public let type: PatternType
    public let confidence: Double
    public let description: String
    public let affectedTraces: [TraceId]
    public let metadata: PatternMetadata
    public let timestamp: Date

    public init(
        id: PatternId,
        type: PatternType,
        confidence: Double,
        description: String,
        affectedTraces: [TraceId],
        metadata: PatternMetadata,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.confidence = confidence
        self.description = description
        self.affectedTraces = affectedTraces
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

/// Unique identifier for pattern
public struct PatternId: Sendable, Codable, Hashable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public static func generate() -> PatternId {
        return PatternId(UUID().uuidString)
    }
}

/// Metadata for detected pattern
public struct PatternMetadata: Sendable, Codable {
    public let frequency: Int
    public let severity: NormalizedSeverity
    public let firstOccurrence: Date
    public let lastOccurrence: Date
    public let context: [String: String]

    public init(
        frequency: Int,
        severity: NormalizedSeverity,
        firstOccurrence: Date,
        lastOccurrence: Date,
        context: [String: String] = [:]
    ) {
        self.frequency = frequency
        self.severity = severity
        self.firstOccurrence = firstOccurrence
        self.lastOccurrence = lastOccurrence
        self.context = context
    }
}

// MARK: - Campaign Planning

/// Protocol for campaign planners
public protocol CampaignPlanner: Sendable {
    func plan(from patterns: [DetectedPattern]) async throws -> [CampaignRecommendation]
}

/// Campaign recommendation
public struct CampaignRecommendation: Sendable, Codable {
    public let id: CampaignId
    public let type: CampaignType
    public let priority: CampaignPriority
    public let title: String
    public let description: String
    public let rationale: String
    public let suggestedActions: [SuggestedAction]
    public let estimatedImpact: CampaignImpact
    public let sourcePatterns: [PatternId]
    public let metadata: CampaignMetadata
    public let timestamp: Date

    public init(
        id: CampaignId,
        type: CampaignType,
        priority: CampaignPriority,
        title: String,
        description: String,
        rationale: String,
        suggestedActions: [SuggestedAction],
        estimatedImpact: CampaignImpact,
        sourcePatterns: [PatternId],
        metadata: CampaignMetadata,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.priority = priority
        self.title = title
        self.description = description
        self.rationale = rationale
        self.suggestedActions = suggestedActions
        self.estimatedImpact = estimatedImpact
        self.sourcePatterns = sourcePatterns
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

/// Unique identifier for campaign
public struct CampaignId: Sendable, Codable, Hashable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public static func generate() -> CampaignId {
        return CampaignId(UUID().uuidString)
    }
}

/// Type of campaign
public enum CampaignType: String, Sendable, Codable {
    case failureAnalysis = "failure_analysis"
    case policyImprovement = "policy_improvement"
    case performanceOptimization = "performance_optimization"
    case resourceScaling = "resource_scaling"
    case securityHardening = "security_hardening"

    public var description: String {
        switch self {
        case .failureAnalysis: return "Analyze and fix repeated failures"
        case .policyImprovement: return "Improve governance policies"
        case .performanceOptimization: return "Optimize system performance"
        case .resourceScaling: return "Scale resources appropriately"
        case .securityHardening: return "Harden security measures"
        }
    }
}

/// Priority of campaign
public enum CampaignPriority: String, Sendable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    public var description: String {
        switch self {
        case .low: return "Low priority"
        case .medium: return "Medium priority"
        case .high: return "High priority"
        case .critical: return "Critical priority"
        }
    }
}

/// Suggested action for campaign
public struct SuggestedAction: Sendable, Codable {
    public let id: String
    public let type: ActionType
    public let description: String
    public let parameters: [String: String]
    public let estimatedEffort: EffortEstimate
    public let prerequisites: [String]

    public init(
        id: String,
        type: ActionType,
        description: String,
        parameters: [String: String] = [:],
        estimatedEffort: EffortEstimate = EffortEstimate(),
        prerequisites: [String] = []
    ) {
        self.id = id
        self.type = type
        self.description = description
        self.parameters = parameters
        self.estimatedEffort = estimatedEffort
        self.prerequisites = prerequisites
    }
}

/// Estimated effort for action
public struct EffortEstimate: Sendable, Codable {
    public let hours: Double
    public let complexity: ComplexityLevel
    public let risk: RiskLevel
    public let requiredSkills: [String]

    public init(
        hours: Double = 1.0,
        complexity: ComplexityLevel = .medium,
        risk: RiskLevel = .medium,
        requiredSkills: [String] = []
    ) {
        self.hours = hours
        self.complexity = complexity
        self.risk = risk
        self.requiredSkills = requiredSkills
    }
}

/// Complexity level
public enum ComplexityLevel: String, Sendable, Codable {
    case trivial = "trivial"
    case simple = "simple"
    case medium = "medium"
    case complex = "complex"
    case expert = "expert"

    public var description: String {
        switch self {
        case .trivial: return "Trivial complexity"
        case .simple: return "Simple complexity"
        case .medium: return "Medium complexity"
        case .complex: return "Complex complexity"
        case .expert: return "Expert complexity"
        }
    }
}

/// Estimated impact of campaign
public struct CampaignImpact: Sendable, Codable {
    public let successProbability: Double
    public let expectedBenefit: String
    public let riskReduction: String
    public let resourceRequirement: ResourceEstimate
    public let timeToImplement: TimeInterval

    public init(
        successProbability: Double,
        expectedBenefit: String,
        riskReduction: String,
        resourceRequirement: ResourceEstimate = ResourceEstimate(),
        timeToImplement: TimeInterval = 3600  // 1 hour default
    ) {
        self.successProbability = successProbability
        self.expectedBenefit = expectedBenefit
        self.riskReduction = riskReduction
        self.resourceRequirement = resourceRequirement
        self.timeToImplement = timeToImplement
    }
}

/// Metadata for campaign
public struct CampaignMetadata: Sendable, Codable {
    public let version: String
    public let author: String
    public let tags: [String]
    public let context: [String: String]

    public init(
        version: String = "1.0",
        author: String = "ReflexiveAnalytics",
        tags: [String] = [],
        context: [String: String] = [:]
    ) {
        self.version = version
        self.author = author
        self.tags = tags
        self.context = context
    }
}

// MARK: - String Extension for SHA256

private extension String {
    var sha256: String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
