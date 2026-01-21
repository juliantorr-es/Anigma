//
//  KeyDerivation.swift
//  ContractsCore
//
//  Contract definition for KeyDerivation in ContractsCore.
//

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
        return sha256Hex(Data(raw.utf8))
    }

    public static func inputKey(
        inputArtifactKeys: [String],
        inputSchemaVersion: Int
    ) throws -> InputKey {
        let sorted = inputArtifactKeys.sorted()
        let payload = InputKeyPayload(artifactKeys: sorted, schemaVersion: inputSchemaVersion)
        let data = try canonicalJSON(payload)
        return InputKey(raw: sha256Hex(data))
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
        return ArtifactKey(raw: sha256Hex(data))
    }

    private static func canonicalJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    public static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
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
