//
//  CompressionKit.swift
//  CompressionKit
//
//  Unified compression interface.
//  Modern implementation using CompressionCapsuleWrapper.
//

import Foundation
import CapsuleCore
import AnigmaNativeShims

public protocol Compressor: Sendable {
    func compress(_ data: Data, algorithm: CompressionAlgorithm) throws -> Data
    func decompress(_ data: Data, algorithm: CompressionAlgorithm) throws -> Data
}

/// Thread-safe compressor using CompressionCapsuleWrapper.
/// Provides backward compatibility with the original NativeCompressor API.
public final class NativeCompressor: Compressor, @unchecked Sendable {
    private let lock = NSLock()
    private var capsuleCache: [CompressionAlgorithm: CompressionCapsuleWrapper] = [:]
    
    public init() {}
    
    public func compress(_ data: Data, algorithm: CompressionAlgorithm) throws -> Data {
        let capsule = try getOrCreateCapsule(for: algorithm)
        return try capsule.compress(data)
    }
    
    public func decompress(_ data: Data, algorithm: CompressionAlgorithm) throws -> Data {
        let capsule = try getOrCreateCapsule(for: algorithm)
        return try capsule.decompress(data)
    }
    
    private func getOrCreateCapsule(for algorithm: CompressionAlgorithm) throws -> CompressionCapsuleWrapper {
        lock.lock()
        defer { lock.unlock() }
        
        if let existing = capsuleCache[algorithm] {
            return existing
        }
        
        // Create configuration with deterministic mode (Tier 1) for receipt-grade compression
        let config = CompressionConfig(
            algorithm: algorithm,
            mode: .deterministic,
            level: .default,
            bufferPoolSize: 0,
            determinismTier: 1
        )
        
        let capsule = try CompressionCapsuleWrapper(config: config)
        capsuleCache[algorithm] = capsule
        return capsule
    }
    
    deinit {
        lock.withLock {
            capsuleCache.removeAll()
        }
    }
}
