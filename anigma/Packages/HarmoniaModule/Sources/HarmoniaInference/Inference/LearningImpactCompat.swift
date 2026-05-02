//
//  LearningImpactCompat.swift
//  HarmoniaModule
//
//  Minimal compatibility surface for learning-impact APIs that are still
//  referenced across the inference layer. The heavier training-curation
//  implementation is excluded from the target to reduce module-emission load.
//

import Foundation
import HarmoniaCore
import AnigmaCore
import AnigmaPrimitives
import InferenceCore
@preconcurrency import Foundation

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
        quality: TraceQuality,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.domain = domain
        self.taskType = taskType
        self.input = input
        self.reasoning = reasoning
        self.output = output
        self.metadata = metadata
        self.quality = quality
        self.timestamp = timestamp
    }
}

public enum TrainingDomain: String, Sendable, Codable, CaseIterable {
    case dsps
    case transcriptum
    case compliance
    case coding
    case general
    case institutional
}

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

public enum TraceSourceType: String, Sendable, Codable {
    case production
    case synthetic
    case curated
    case distilled
}

public struct TraceQuality: Sendable, Codable {
    public let overallScore: Double
    public let structureScore: Double
    public let correctnessScore: Double?
    public let clarityScore: Double
    public let followsDomainPatterns: Bool
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

    public var meetsQualityBar: Bool {
        overallScore >= 0.7 && structureScore >= 0.6 && clarityScore >= 0.6
    }
}

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

public struct ExtractedPrefix: Sendable, Codable, Identifiable {
    public let id: String
    public let sourceTraceId: String
    public let domain: TrainingDomain
    public let prefixText: String
    public let estimatedTokens: Int
    public let timestamp: Date

    public init(
        id: String = UUID().uuidString,
        sourceTraceId: String,
        domain: TrainingDomain,
        prefixText: String,
        estimatedTokens: Int,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.sourceTraceId = sourceTraceId
        self.domain = domain
        self.prefixText = prefixText
        self.estimatedTokens = estimatedTokens
        self.timestamp = timestamp
    }
}

public actor LearningImpactMeasurer {
    private var tracesByDomain: [TrainingDomain: [ReasoningTrace]] = [:]

    public init() {}

    func record(_ trace: ReasoningTrace) {
        tracesByDomain[trace.domain, default: []].append(trace)
    }

    func traces(for domain: TrainingDomain) -> [ReasoningTrace] {
        tracesByDomain[domain] ?? []
    }
}

public actor UPFTExtractor {
    public init() {}

    func extractPrefix(from trace: ReasoningTrace) -> ExtractedPrefix? {
        guard trace.quality.meetsQualityBar else { return nil }
        let prefix = String(trace.reasoning.prefix(256))
        guard !prefix.isEmpty else { return nil }
        return ExtractedPrefix(
            sourceTraceId: trace.id,
            domain: trace.domain,
            prefixText: prefix,
            estimatedTokens: max(1, prefix.count / 4)
        )
    }
}
