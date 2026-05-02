import Foundation
import AnigmaPrimitives

/// Universal contract identifier with versioning and schema validation
public struct ContractID: Hashable, Sendable, Codable {
  public let name: String  // "harmonia.retrieve.request"
  public let major: Int  // breaking
  public let minor: Int  // additive
  public let schemaHash: String  // stable snapshot hash

  public init(name: String, major: Int, minor: Int, schemaHash: String) {
    self.name = name
    self.major = major
    self.schemaHash = schemaHash
    self.minor = minor
  }
}

/// Protocol for all workflow boundary contracts
public protocol WorkflowContract: Sendable, Codable {
  static var id: ContractID { get }
  static func validateInvariants(_ value: Self) throws
}

/// Versioned contract envelope that carries identity and validation
public struct ContractEnvelope<Payload: WorkflowContract>: Sendable, Codable {
  public let id: ContractID
  public let payload: Payload

  public init(_ payload: Payload) {
    self.id = Payload.id
    self.payload = payload
  }
}

/// Default validation implementation for contracts
extension WorkflowContract {
  public static func validateInvariants(_ value: Self) throws {
    // Base implementation - override for specific validation
    // Schema hash validation happens at envelope level
  }
}

// MARK: - Validation Errors

/// Validation errors for contracts
public enum ValidationError: Error, Sendable {
  case invalidRequest(String)
  case invalidResponse(String)
  case invalidEvidence(String)
  case policyViolation(String)
  case securityViolation(String)
  case schemaViolation(String)
}
