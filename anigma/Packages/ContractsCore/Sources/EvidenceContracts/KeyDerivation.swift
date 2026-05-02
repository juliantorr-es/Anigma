//
//  KeyDerivation.swift
//  ContractsCore
//
//  Contract definition for KeyDerivation in ContractsCore.
//

import FoundationContracts
import GovernanceContracts
import AnigmaPrimitives
import CryptoKit
import Foundation

/// Deterministic input key for a contract run.
public struct InputKey: Hashable, Codable, Sendable {
    public let raw: String
    public init(raw: String) { self.raw = raw }
}

/// Deterministic artifact key used for content-addressed storage.
public struct ArtifactKey: Hashable, Codable, Sendable {
    public let raw: String
    public init(raw: String) { self.raw = raw }
}

/// Utility helpers for canonical hashing.
public enum ContractKeyDerivation {
    /// Derive a deterministic queue key for scheduling a contract execution.
    public static func queueKey(sessionID: String, contractID: String, inputKey: InputKey) -> String {
        let raw = "job:\(sessionID):\(contractID):\(inputKey.raw)"
        return blake3Hex(Data(raw.utf8))
    }

    public static func inputKey(
        inputArtifactKeys: [String],
        inputSchemaVersion: Int
    ) throws -> InputKey {
        let sorted = inputArtifactKeys.sorted()
        let payload = InputKeyPayload(artifactKeys: sorted, schemaVersion: inputSchemaVersion)
        let data = try canonicalJSON(payload)
        return InputKey(raw: blake3Hex(data))
    }

    public static func artifactKey(
        contractID: ContractID,
        inputHash: InputKey,
        outputSchemaVersion: Int,
        modelID: String? = nil,
        modelVersion: String? = nil
    ) throws -> ArtifactKey {
        let payload = ArtifactKeyPayload(
            contractID: contractID,
            inputKey: inputHash.raw,
            outputSchemaVersion: outputSchemaVersion,
            modelID: modelID,
            modelVersion: modelVersion
        )
        let data = try canonicalJSON(payload)
        return ArtifactKey(raw: blake3Hex(data))
    }

    private static func canonicalJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    public static func blake3Hex(_ data: Data) -> String {
        return BLAKE3Digest.hex(of: data)
    }

    private struct InputKeyPayload: Encodable {
        let artifactKeys: [String]
        let schemaVersion: Int
    }

    private struct ArtifactKeyPayload: Encodable {
        let contractID: ContractID
        let inputKey: String
        let outputSchemaVersion: Int
        let modelID: String?
        let modelVersion: String?
    }

}
