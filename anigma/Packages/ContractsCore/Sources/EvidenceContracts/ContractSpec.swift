//
//  ContractSpec.swift
//  ContractsCore
//
//  Contract definition for ContractSpec in ContractsCore.
//

import FoundationContracts
import GovernanceContracts
import AnigmaPrimitives
import Foundation

/// Executable contract interface. Each contract defines its input/output schema and validation rules.
public protocol ContractSpec {
    associatedtype Input: Codable & Sendable
    associatedtype Output: Codable & Sendable

    static var id: ContractID { get }
    static var inputSchemaVersion: Int { get }
    static var outputSchemaVersion: Int { get }
    
    /// Minimum trust tier required to execute this contract
    static var requiredTrustTier: TrustTier { get }

    static func validate(output: ArtifactEnvelope<Output>) throws
    static func execute(input: ArtifactEnvelope<Input>, ctx: ContractContext) async throws -> ArtifactEnvelope<Output>
    static func artifactKeyMetadata(input: ArtifactEnvelope<Input>) -> (modelID: String?, modelVersion: String?)
}

/// A contract spec optimized for hardware saturation, specifying a preferred execution lane.
public protocol SaturatedContractSpec: ContractSpec {
    static var preferredLane: HardwareLane { get }
}

extension SaturatedContractSpec {
    public static var preferredLane: HardwareLane { .inference }
}

extension ContractSpec {
    public static func validate(output: ArtifactEnvelope<Output>) throws {
        // Default no-op validator; contracts should override.
    }

    public static func artifactKeyMetadata(input: ArtifactEnvelope<Input>) -> (modelID: String?, modelVersion: String?) {
        (nil, nil)
    }
    
    /// Default trust tier requirement is bronze (lowest)
    public static var requiredTrustTier: TrustTier {
        return .bronze
    }
}

/// Type eraser for heterogeneous contract registry storage.
public struct AnyContractSpec: Sendable {
    public let id: ContractID
    public let inputSchemaVersion: Int
    public let outputSchemaVersion: Int
    public let preferredLane: HardwareLane?
    public let requiredTrustTier: TrustTier
    public let inputType: Any.Type
    public let outputType: Any.Type
    public let inputTypeName: String
    public let outputTypeName: String

    private let implementation: any ContractImplementationBox

    public init<C: ContractSpec>(_ type: C.Type) {
        self.id = C.id
        self.inputSchemaVersion = C.inputSchemaVersion
        self.outputSchemaVersion = C.outputSchemaVersion
        self.preferredLane = (type as? any SaturatedContractSpec.Type)?.preferredLane
        self.requiredTrustTier = C.requiredTrustTier
        self.inputType = C.Input.self
        self.outputType = C.Output.self
        self.inputTypeName = String(describing: C.Input.self)
        self.outputTypeName = String(describing: C.Output.self)

        let contractID = C.id
        let inputTypeName = String(reflecting: C.Input.self)
        let outputTypeName = String(reflecting: C.Output.self)
        self.implementation = ContractImplementation<C>(
            contractID: contractID,
            inputTypeName: inputTypeName,
            outputTypeName: outputTypeName
        )
    }

    public func executeErased(input: Any, ctx: ContractContext) async throws -> Any {
        try await implementation.executeErased(input, ctx: ctx)
    }

    public func validateErased(output: Any) throws {
        try implementation.validateErased(output)
    }

    public func decodeInput(from data: Data, using decoder: JSONDecoder) throws -> Any {
        try implementation.decodeInput(from: data, using: decoder)
    }

    public func encodeOutput(_ value: Any, using encoder: JSONEncoder) throws -> Data {
        try implementation.encodeOutput(value, using: encoder)
    }

    public func decodeOutput(from data: Data, using decoder: JSONDecoder) throws -> Any {
        try implementation.decodeOutput(from: data, using: decoder)
    }

    public func extractOutputComponents(from data: Data, encoder: JSONEncoder, decoder: JSONDecoder) throws -> OutputComponents {
        try implementation.extractOutputComponents(from: data, encoder: encoder, decoder: decoder)
    }

    public func decodeOutputPayload(from data: Data, using decoder: JSONDecoder) throws -> Any {
        try implementation.decodeOutputPayload(from: data, using: decoder)
    }

    public func artifactKeyMetadata(from input: Any) -> (String?, String?) {
        implementation.artifactKeyMetadata(from: input)
    }
}

private protocol ContractImplementationBox: Sendable {
    func executeErased(_ input: Any, ctx: ContractContext) async throws -> Any
    func validateErased(_ output: Any) throws
    func decodeInput(from data: Data, using decoder: JSONDecoder) throws -> Any
    func encodeOutput(_ value: Any, using encoder: JSONEncoder) throws -> Data
    func decodeOutput(from data: Data, using decoder: JSONDecoder) throws -> Any
    func extractOutputComponents(from data: Data, encoder: JSONEncoder, decoder: JSONDecoder) throws -> OutputComponents
    func decodeOutputPayload(from data: Data, using decoder: JSONDecoder) throws -> Any
    func artifactKeyMetadata(from input: Any) -> (String?, String?)
}

private struct ContractImplementation<C: ContractSpec>: ContractImplementationBox {
    let contractID: ContractID
    let inputTypeName: String
    let outputTypeName: String

    func executeErased(_ input: Any, ctx: ContractContext) async throws -> Any {
        guard let typedInput = input as? ArtifactEnvelope<C.Input> else {
            throw ContractExecutionError.underlying(
                code: "contract.input.type_mismatch",
                message: "Contract \(contractID) expected input \(inputTypeName)"
            )
        }
        return try await C.execute(input: typedInput, ctx: ctx)
    }

    func validateErased(_ output: Any) throws {
        guard let typedOutput = output as? ArtifactEnvelope<C.Output> else {
            throw ContractValidationError.invalidSchema(
                code: "contract.output.type_mismatch",
                message: "Contract \(contractID) expected output \(outputTypeName)"
            )
        }
        try C.validate(output: typedOutput)
    }

    func decodeInput(from data: Data, using decoder: JSONDecoder) throws -> Any {
        try decoder.decode(ArtifactEnvelope<C.Input>.self, from: data)
    }

    func encodeOutput(_ value: Any, using encoder: JSONEncoder) throws -> Data {
        guard let typedOutput = value as? ArtifactEnvelope<C.Output> else {
            throw ContractExecutionError.underlying(
                code: "contract.output.type_mismatch",
                message: "Contract \(contractID) expected output \(outputTypeName)"
            )
        }
        return try encoder.encode(typedOutput)
    }

    func decodeOutput(from data: Data, using decoder: JSONDecoder) throws -> Any {
        try decoder.decode(ArtifactEnvelope<C.Output>.self, from: data)
    }

    func extractOutputComponents(from data: Data, encoder: JSONEncoder, decoder: JSONDecoder) throws -> OutputComponents {
        let envelope = try decoder.decode(ArtifactEnvelope<C.Output>.self, from: data)
        return OutputComponents(
            schemaVersion: envelope.schemaVersion,
            payloadData: try encoder.encode(envelope.payload),
            evidenceRefs: envelope.evidenceRefs,
            metrics: envelope.metrics,
            receipt: envelope.receipt
        )
    }

    func decodeOutputPayload(from data: Data, using decoder: JSONDecoder) throws -> Any {
        try decoder.decode(C.Output.self, from: data)
    }

    func artifactKeyMetadata(from input: Any) -> (String?, String?) {
        guard let typed = input as? ArtifactEnvelope<C.Input> else { return (nil, nil) }
        return C.artifactKeyMetadata(input: typed)
    }
}

/// Decomposed components of an encoded output envelope for storage and hashing.
public struct OutputComponents: Sendable {
    public let schemaVersion: Int
    public let payloadData: Data
    public let evidenceRefs: [EvidenceRef]
    public let metrics: ExecutionMetrics
    public let receipt: ContractReceipt
}
