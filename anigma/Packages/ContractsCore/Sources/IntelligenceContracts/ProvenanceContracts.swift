import EvidenceContracts
import AnigmaPrimitives
import Foundation
import FoundationContracts
import GovernanceContracts

// MARK: - Assistant Provenance Contracts

public struct AnswerProvenanceSource: Identifiable, Codable, Sendable, Equatable {
  public let id: String
  public let title: String
  public let path: String?
  public let excerpt: String?
  public let similarity: Double
  public let sourceHash: String

  public init(
    id: String,
    title: String,
    path: String? = nil,
    excerpt: String? = nil,
    similarity: Double,
    sourceHash: String
  ) {
    self.id = id
    self.title = title
    self.path = path
    self.excerpt = excerpt
    self.similarity = similarity
    self.sourceHash = sourceHash
  }
}

public struct AnswerProvenanceReceipt: Identifiable, Codable, Sendable, Equatable {
  public let id: String
  public let operationType: String
  public let timestamp: Date
  public let hash: String?

  public init(
    id: String = UUID().uuidString,
    operationType: String,
    timestamp: Date = Date(),
    hash: String? = nil
  ) {
    self.id = id
    self.operationType = operationType
    self.timestamp = timestamp
    self.hash = hash
  }
}

public struct AnswerProvenanceReplay: Codable, Sendable, Equatable {
  public let mode: String
  public let replayable: Bool
  public let deterministic: Bool
  public let nondeterminismReasons: [String]
  public let replayToken: String
  public let sourceGraphHash: String
  public let contextPolicyHash: String
  public let receiptChainHash: String
  public let notes: String

  private enum CodingKeys: String, CodingKey {
    case mode
    case replayable
    case deterministic
    case nondeterminismReasons
    case replayToken
    case sourceGraphHash
    case contextPolicyHash
    case receiptChainHash
    case notes
  }

  public init(
    mode: String,
    replayable: Bool,
    deterministic: Bool = true,
    nondeterminismReasons: [String] = [],
    replayToken: String,
    sourceGraphHash: String,
    contextPolicyHash: String = "",
    receiptChainHash: String,
    notes: String
  ) {
    self.mode = mode
    self.replayable = replayable
    self.deterministic = deterministic
    self.nondeterminismReasons = nondeterminismReasons
    self.replayToken = replayToken
    self.sourceGraphHash = sourceGraphHash
    self.contextPolicyHash = contextPolicyHash
    self.receiptChainHash = receiptChainHash
    self.notes = notes
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    mode = try container.decode(String.self, forKey: .mode)
    replayable = try container.decode(Bool.self, forKey: .replayable)
    let decodedNondeterminismReasons =
      try container.decodeIfPresent([String].self, forKey: .nondeterminismReasons) ?? []
    nondeterminismReasons = decodedNondeterminismReasons
    deterministic = try container.decodeIfPresent(Bool.self, forKey: .deterministic)
      ?? (decodedNondeterminismReasons.isEmpty ? replayable : false)
    replayToken = try container.decode(String.self, forKey: .replayToken)
    sourceGraphHash = try container.decode(String.self, forKey: .sourceGraphHash)
    contextPolicyHash = try container.decodeIfPresent(String.self, forKey: .contextPolicyHash) ?? ""
    receiptChainHash = try container.decode(String.self, forKey: .receiptChainHash)
    notes = try container.decode(String.self, forKey: .notes)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(mode, forKey: .mode)
    try container.encode(replayable, forKey: .replayable)
    try container.encode(deterministic, forKey: .deterministic)
    try container.encode(nondeterminismReasons, forKey: .nondeterminismReasons)
    try container.encode(replayToken, forKey: .replayToken)
    try container.encode(sourceGraphHash, forKey: .sourceGraphHash)
    try container.encode(contextPolicyHash, forKey: .contextPolicyHash)
    try container.encode(receiptChainHash, forKey: .receiptChainHash)
    try container.encode(notes, forKey: .notes)
  }
}

public struct AnswerProvenanceContextPolicy: Sendable, Codable, Equatable {
  public var pinnedSourceIDs: [String]
  public var excludedSourceIDs: [String]
  public var updatedAt: Date

  public init(
    pinnedSourceIDs: [String] = [],
    excludedSourceIDs: [String] = [],
    updatedAt: Date = Date()
  ) {
    self.pinnedSourceIDs = pinnedSourceIDs
    self.excludedSourceIDs = excludedSourceIDs
    self.updatedAt = updatedAt
  }

  public func isPinned(_ sourceID: String) -> Bool {
    pinnedSourceIDs.contains(sourceID)
  }

  public func isExcluded(_ sourceID: String) -> Bool {
    excludedSourceIDs.contains(sourceID)
  }

  public mutating func pin(_ sourceID: String) {
    pinnedSourceIDs.removeAll { $0 == sourceID }
    excludedSourceIDs.removeAll { $0 == sourceID }
    pinnedSourceIDs.append(sourceID)
    updatedAt = Date()
  }

  public mutating func exclude(_ sourceID: String) {
    excludedSourceIDs.removeAll { $0 == sourceID }
    pinnedSourceIDs.removeAll { $0 == sourceID }
    excludedSourceIDs.append(sourceID)
    updatedAt = Date()
  }

  public mutating func clear(_ sourceID: String) {
    pinnedSourceIDs.removeAll { $0 == sourceID }
    excludedSourceIDs.removeAll { $0 == sourceID }
    updatedAt = Date()
  }

  public var conflictSourceIDs: [String] {
    Array(Set(pinnedSourceIDs).intersection(excludedSourceIDs)).sorted()
  }
}

public struct AnswerProvenanceRecord: Identifiable, Codable, Sendable {
  public let id: String
  public let query: String
  public let answerText: String
  public let modelName: String
  public let projectId: String
  public let projectName: String
  public let sessionId: String
  public let principalId: String
  public let topK: Int
  public let scanLimit: Int
  public let threshold: Double
  public let confidence: Double
  public let sources: [AnswerProvenanceSource]
  public let receipts: [AnswerProvenanceReceipt]
  public let missingContext: [String]
  public let contextPolicy: AnswerProvenanceContextPolicy
  public let replay: AnswerProvenanceReplay
  public let generatedAt: Date

  private enum CodingKeys: String, CodingKey {
    case id
    case query
    case answerText
    case modelName
    case projectId
    case projectName
    case sessionId
    case principalId
    case topK
    case scanLimit
    case threshold
    case confidence
    case sources
    case receipts
    case missingContext
    case contextPolicy
    case replay
    case generatedAt
  }

  public init(
    id: String,
    query: String,
    answerText: String,
    modelName: String,
    projectId: String,
    projectName: String,
    sessionId: String,
    principalId: String,
    topK: Int,
    scanLimit: Int,
    threshold: Double,
    confidence: Double,
    sources: [AnswerProvenanceSource],
    receipts: [AnswerProvenanceReceipt],
    missingContext: [String],
    contextPolicy: AnswerProvenanceContextPolicy = AnswerProvenanceContextPolicy(),
    replay: AnswerProvenanceReplay,
    generatedAt: Date
  ) {
    self.id = id
    self.query = query
    self.answerText = answerText
    self.modelName = modelName
    self.projectId = projectId
    self.projectName = projectName
    self.sessionId = sessionId
    self.principalId = principalId
    self.topK = topK
    self.scanLimit = scanLimit
    self.threshold = threshold
    self.confidence = confidence
    self.sources = sources
    self.receipts = receipts
    self.missingContext = missingContext
    self.contextPolicy = contextPolicy
    self.replay = replay
    self.generatedAt = generatedAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    query = try container.decode(String.self, forKey: .query)
    answerText = try container.decode(String.self, forKey: .answerText)
    modelName = try container.decode(String.self, forKey: .modelName)
    projectId = try container.decode(String.self, forKey: .projectId)
    projectName = try container.decode(String.self, forKey: .projectName)
    sessionId = try container.decode(String.self, forKey: .sessionId)
    principalId = try container.decode(String.self, forKey: .principalId)
    topK = try container.decode(Int.self, forKey: .topK)
    scanLimit = try container.decode(Int.self, forKey: .scanLimit)
    threshold = try container.decode(Double.self, forKey: .threshold)
    confidence = try container.decode(Double.self, forKey: .confidence)
    sources = try container.decodeIfPresent([AnswerProvenanceSource].self, forKey: .sources) ?? []
    receipts = try container.decodeIfPresent([AnswerProvenanceReceipt].self, forKey: .receipts) ?? []
    missingContext = try container.decodeIfPresent([String].self, forKey: .missingContext) ?? []
    contextPolicy = try container.decodeIfPresent(AnswerProvenanceContextPolicy.self, forKey: .contextPolicy) ?? AnswerProvenanceContextPolicy()
    replay = try container.decode(AnswerProvenanceReplay.self, forKey: .replay)
    generatedAt = try container.decode(Date.self, forKey: .generatedAt)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(query, forKey: .query)
    try container.encode(answerText, forKey: .answerText)
    try container.encode(modelName, forKey: .modelName)
    try container.encode(projectId, forKey: .projectId)
    try container.encode(projectName, forKey: .projectName)
    try container.encode(sessionId, forKey: .sessionId)
    try container.encode(principalId, forKey: .principalId)
    try container.encode(topK, forKey: .topK)
    try container.encode(scanLimit, forKey: .scanLimit)
    try container.encode(threshold, forKey: .threshold)
    try container.encode(confidence, forKey: .confidence)
    try container.encode(sources, forKey: .sources)
    try container.encode(receipts, forKey: .receipts)
    try container.encode(missingContext, forKey: .missingContext)
    try container.encode(contextPolicy, forKey: .contextPolicy)
    try container.encode(replay, forKey: .replay)
    try container.encode(generatedAt, forKey: .generatedAt)
  }
}

public typealias AssistantAnswerProvenance = AnswerProvenanceRecord
public typealias AssistantSourceChip = AnswerProvenanceSource
public typealias AssistantReceipt = AnswerProvenanceReceipt
public typealias AssistantReplayMetadata = AnswerProvenanceReplay
public typealias AssistantContextSourcePolicy = AnswerProvenanceContextPolicy

// MARK: - Calibrated Confidence

public enum CalibratedConfidence: String, Codable, Sendable, CaseIterable {
  case veryLow    // 0.0 - 0.5
  case low        // 0.5 - 0.7
  case medium     // 0.7 - 0.9
  case high       // 0.9 - 1.0

  public var description: String {
    switch self {
    case .veryLow: return "Very Low"
    case .low: return "Low"
    case .medium: return "Medium"
    case .high: return "High"
    }
  }

  public var explanatoryNote: String {
    switch self {
    case .veryLow: return "Answer may be incomplete or unreliable"
    case .low: return "Answer should be verified with additional sources"
    case .medium: return "Answer is reasonably grounded but has limitations"
    case .high: return "Answer is well-grounded with strong evidence"
    }
  }
}

// MARK: - Missing Context Warnings

public enum MissingContextType: String, Codable, Sendable {
  case insufficientSources
  case lowRelevance
  case staleContext
  case weakProvenance
  case lowConfidence
  case conflictingSources
  case policyViolation
}

public enum MissingContextSeverity: String, Codable, Sendable {
  case low
  case medium
  case high
  case critical
}

public struct MissingContextWarning: Identifiable, Codable, Sendable, Equatable {
  public let id: UUID
  public let type: MissingContextType
  public let message: String
  public let severity: MissingContextSeverity
  public let suggestedAction: String

  public init(
    id: UUID = UUID(),
    type: MissingContextType,
    message: String,
    severity: MissingContextSeverity,
    suggestedAction: String
  ) {
    self.id = id
    self.type = type
    self.message = message
    self.severity = severity
    self.suggestedAction = suggestedAction
  }
}

// MARK: - Answer Coverage Summary

public struct AnswerCoverageSummary: Codable, Sendable, Equatable {
  public let sourceCount: Int
  public let highRelevanceCount: Int
  public let receiptCount: Int
  public let missingContext: [MissingContextWarning]

  public init(
    sourceCount: Int,
    highRelevanceCount: Int,
    receiptCount: Int,
    missingContext: [MissingContextWarning]
  ) {
    self.sourceCount = sourceCount
    self.highRelevanceCount = highRelevanceCount
    self.receiptCount = receiptCount
    self.missingContext = missingContext
  }

  public var coverageRatio: Double {
    guard sourceCount > 0 else { return 0.0 }
    return Double(highRelevanceCount) / Double(sourceCount)
  }
}

// MARK: - Data Quality Conformance

extension AnswerProvenanceRecord: DataQualityInspectable {
  public var dataProductKind: DataProductKind { .evalRecord }

  public var dataProductIdentifier: String { id }

  public var dataProductCreatedAt: Date { generatedAt }

  public var dataProductUpdatedAt: Date? { nil }

  public var dataProductLineage: DataProductLineage? {
    DataProductLineage(
      sourceArtifactID: query,
      sourceArtifactHash: replay.sourceGraphHash,
      transformName: "answer-provenance",
      transformVersion: replay.mode,
      modelVersion: modelName,
      toolVersion: nil,
      derivedRecordID: id,
      createdAt: generatedAt
    )
  }

  public var dataProductPayloadReferences: [String] {
    [
      projectId,
      sessionId,
      principalId,
      replay.sourceGraphHash,
      replay.receiptChainHash
    ]
  }

  public var dataProductSummaryFingerprint: String? {
    answerText
  }

  public var dataProductEmbeddingModel: String? { nil }

  public var dataProductEmbeddingGeneratedAt: Date? { nil }

  public var dataProductSourceFidelity: Double? { nil }

  public var dataProductHandoffState: String? { nil }
}
