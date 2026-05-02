import GovernanceContracts
import AnigmaPrimitives
import Foundation
import FoundationContracts

/// Evidence head for cryptographic provenance
public struct EvidenceHead: Sendable, Codable {
  public let headId: String
  public let headHash: String
  public let timestamp: Date
  public let lastActor: String

  public init(headId: String, headHash: String, timestamp: Date = Date(), lastActor: String) {
    self.headId = headId
    self.headHash = headHash
    self.timestamp = timestamp
    self.lastActor = lastActor
  }
}

/// Protocol for evidence recording - minimal boundary interface
public protocol EvidenceRecording: Sendable {
  func recordEvidence(
    head: EvidenceHead,
    content: Data
  ) async throws

  func recordStateDelta(
    sessionId: String,
    delta: StateDelta,
    timestamp: Date
  ) async throws
}
