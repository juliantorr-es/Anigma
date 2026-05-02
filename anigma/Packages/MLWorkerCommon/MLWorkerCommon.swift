//
//  MLWorkerCommon.swift
//  MLWorkerCommon
//
//  Shared ML worker protocol definitions used by Harmonia and worker executables.
//  Now re-exports canonical contracts from ContractsCore for type authority.
//

import Foundation
import ArgumentParser
import ContractsCore
import CryptoKit
import AnigmaPrimitives

// MARK: - Type Aliases for Canonical Contracts

/// Re-export canonical ML worker types with compatibility shims
public typealias MLWorkerEngine = ContractsCore.MLWorkerEngine
public typealias MLTaskKind = ContractsCore.MLWorkerTask  // Map to canonical enum
public typealias MLTaskOptions = ContractsCore.MLTaskOptions

// MARK: - Legacy Compatibility Types

/// Use ContractsCore types to avoid conflicts
public typealias MLArtifactRef = ContractsCore.MLArtifactRef

/// Legacy ML worker engine metadata for backward compatibility
public struct MLWorkerEngineMetadata: Codable, Sendable, Equatable {
    public let binaryHash: String
    public let version: String
    public let modelId: String?
    public let modelHash: String?
    public let binaryVersion: String?

    public init(
        binaryHash: String,
        version: String,
        modelId: String? = nil,
        modelHash: String? = nil,
        binaryVersion: String? = nil
    ) {
        self.binaryHash = binaryHash
        self.version = version
        self.modelId = modelId
        self.modelHash = modelHash
        self.binaryVersion = binaryVersion
    }
}

/// Use ContractsCore types to avoid conflicts
public typealias MLWorkerMetrics = ContractsCore.MLWorkerMetrics

/// Legacy ML worker artifact for backward compatibility
public struct MLWorkerArtifact: Codable, Sendable {
    public let path: String
    public let hash: String
    public let size: Int?
    public let mimeType: String?
    public let normalizedHash: String?

    public init(path: String, hash: String, size: Int? = nil, mimeType: String? = nil, normalizedHash: String? = nil) {
        self.path = path
        self.hash = hash
        self.size = size
        self.mimeType = mimeType
        self.normalizedHash = normalizedHash
    }
}

// MARK: - Legacy Request/Response Types

// Use ContractsCore types to avoid conflicts
public typealias MLWorkerRequest = ContractsCore.MLWorkerRequest

/// Legacy ML worker response for backward compatibility
public struct MLWorkerResponse: Codable, Sendable {
    public let requestId: String
    public let status: Status
    public let outputs: [MLWorkerArtifact]
    public let metrics: MLWorkerMetrics?
    public let engineMeta: MLWorkerEngineMetadata?
    public let errorMessage: String?

    public enum Status: String, Codable, Sendable {
        case queued
        case processing
        case completed
        case failed
    }

    public init(
        requestId: String,
        status: Status,
        outputs: [MLWorkerArtifact],
        metrics: MLWorkerMetrics? = nil,
        engineMeta: MLWorkerEngineMetadata? = nil,
        errorMessage: String? = nil
    ) {
        self.requestId = requestId
        self.status = status
        self.outputs = outputs
        self.metrics = metrics
        self.engineMeta = engineMeta
        self.errorMessage = errorMessage
    }
}

// MARK: - Canonical Encoding & Hashing

/// Deterministic helpers for hashing worker payloads for evidence envelopes.
public enum MLWorkerHasher {
    /// Canonical JSON encoder with sorted keys to ensure stable hashes.
    private static func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    /// Compute a BLAKE3 hex digest for an encodable value using canonical JSON.
    public static func hash<T: Encodable>(_ value: T) throws -> String {
        let encoder = canonicalEncoder()
        let data = try encoder.encode(value)
        return BLAKE3Digest.hex(of: data)
    }

    /// Hash an ML worker request with canonical JSON.
    public static func hashRequest(_ request: MLWorkerRequest) throws -> String {
        try hash(request)
    }

    /// Hash an ML worker response with canonical JSON.
    public static func hashResponse(_ response: MLWorkerResponse) throws -> String {
        try hash(response)
    }

    /// Hash arbitrary data (e.g., raw embedding bytes).
    public static func hashData(_ data: Data) -> String {
        return BLAKE3Digest.hex(of: data)
    }
}
