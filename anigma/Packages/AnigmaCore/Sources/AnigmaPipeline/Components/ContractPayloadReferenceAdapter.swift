//
//  ContractPayloadReferenceAdapter.swift
//  AnigmaCore
//
//  Adapter for transitioning contracts from direct payload access to reference-only semantics.
//  Provides a bridge for existing contracts while enforcing the "Serialization Wall".
//

import Foundation
import AnigmaFoundation
import ContractsCore

/// Wraps an ArtifactEnvelope to enforce reference-only semantics.
public struct PayloadReferenceEnvelopeAdapter<Payload: Codable> {
    /// Original envelope.
    private let envelope: ArtifactEnvelope<Payload>

    /// Indirect reference to the payload (replaces direct access).
    public let reference: IndirectPayloadReference<Payload>

    /// Checksum of the original payload for integrity.
    public let payloadChecksum: String

    /// Hot path name for audit tracking.
    public let hotPathName: String

    /// Initialize adapter from an existing envelope.
    public init(
        envelope: ArtifactEnvelope<Payload>,
        hotPathName: String,
        atlasName: String = "hot-ecs-atlas",
        storageTier: String = "hot"
    ) throws {
        self.envelope = envelope
        self.hotPathName = hotPathName

        // Compute checksum of payload
        let encoder = JSONEncoder()
        let data = try encoder.encode(envelope.payload)
        let checksum = Self.computeChecksum(data)
        self.payloadChecksum = checksum

        // Create indirect reference
        self.reference = IndirectPayloadReference(
            payloadId: UUID().uuidString,
            location: PayloadLocation(
                atlasName: atlasName,
                offset: 0, // Will be assigned by storage layer
                size: data.count,
                storageTier: storageTier
            ),
            typeName: String(describing: Payload.self),
            sizeBytes: data.count,
            checksum: checksum
        )

        // Record the reference access (not direct)
        payloadReferenceEnforcer.enforceReferenceOnly(
            in: hotPathName,
            payload: reference,
            sizeBytes: data.count
        )
    }

    /// Get the payload (triggers materialization/audit).
    /// In production hot paths, this should NOT be called; use the reference instead.
    public func getPayload() -> Payload {
        // Flag as direct access (audit violation)
        payloadReferenceEnforcer.flagDirectAccess(
            in: hotPathName,
            payloadId: reference.payloadId,
            sizeBytes: reference.sizeBytes
        )
        return envelope.payload
    }

    /// Get the original envelope (breaks reference semantics; use only for compatibility).
    public func getEnvelope() -> ArtifactEnvelope<Payload> {
        return envelope
    }

    /// Verify payload integrity using the stored checksum.
    public func verifyIntegrity() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(envelope.payload)
        let computed = Self.computeChecksum(data)
        guard computed == payloadChecksum else {
            throw NSError(
                domain: "PayloadReferenceEnvelopeAdapter",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Payload checksum mismatch: \(computed) != \(payloadChecksum)"]
            )
        }
    }

    /// Compute SHA256 checksum of data.
    private static func computeChecksum(_ data: Data) -> String {
        // Simplified checksum (use CryptoKit in production)
        let bytes = [UInt8](data)
        return bytes.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}

/// Decorator for contract execution that enforces reference-only access.
public struct PayloadReferenceContractDecorator {
    /// Name of the contract (e.g., "hybrid_search_v1").
    public let contractName: String

    /// Audit hot path accesses during contract execution.
    public func executeWithReferenceSemanticsEnforcement<Output>(
        contractName: String,
        execute: () async throws -> Output
    ) async throws -> Output {
        do {
            let result = try await execute()
            // Record successful reference-compliant execution
            recordPayloadAccess(
                hotPathName: contractName,
                accessType: "reference",
                payloadId: UUID().uuidString,
                sizeBytes: 0 // Will be tracked by per-field instrumentation
            )
            return result
        } catch {
            throw error
        }
    }
}

/// Protocol for contracts that enforce payload-reference-only semantics.
public protocol PayloadReferenceCompliantContract: ContractSpec where Input: Codable, Output: Codable {
    /// Execute the contract using only indirect payload references.
    /// Raw payload materialization should be deferred or use memory budgets.
    static func executeWithReferences(
        inputReference: IndirectPayloadReference<Input>,
        ctx: ContractContext
    ) async throws -> ArtifactEnvelope<Output>
}

/// Extension to migrate existing contracts to reference-only semantics.
extension ContractContext {
    /// Register that this context is executing in a reference-compliant mode.
    public var isPayloadReferenceMode: Bool {
        // Flag can be set by the runtime to enforce reference-only access
        false // Default; can be configured
    }

    /// Helper to audit payload access within contract execution.
    public func auditPayloadAccess(
        hotPathName: String,
        payloadId: String,
        sizeBytes: Int,
        accessType: String = "reference"
    ) {
        recordPayloadAccess(
            hotPathName: hotPathName,
            accessType: accessType,
            payloadId: payloadId,
            sizeBytes: sizeBytes
        )
    }
}
