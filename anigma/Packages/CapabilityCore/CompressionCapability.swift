//
//  CompressionCapability.swift
//  CapabilityCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Supported compression algorithms.
public enum CompressionAlgorithm: String, Sendable, Codable {
    case zstd
    case lz4
    case gzip
}

/// Capability for compressing and decompressing data.
public protocol CompressionCapability: Capability {
    /// Compresses data using the specified algorithm.
    func compress(_ data: Data, algorithm: CompressionAlgorithm) async throws -> Data

    /// Decompress data using the specified algorithm.
    func decompress(_ data: Data, algorithm: CompressionAlgorithm) async throws -> Data
}

extension CompressionCapability {
    public static var capabilityId: String { CapabilityIds.compression }
}
