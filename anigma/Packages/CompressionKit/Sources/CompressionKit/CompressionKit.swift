//
//  CompressionKit.swift
//  CompressionKit
//
//  Unified compression interface.
//  Modern implementation using CompressionCapsule.
//

import Foundation
import CapsuleCore

public protocol Compressor: Sendable {
    func compress(_ data: Data, algorithm: CompressionAlgorithm) async throws -> Data
    func decompress(_ data: Data, algorithm: CompressionAlgorithm) async throws -> Data
}

/// Thread-safe compressor using CompressionCapsule actor.
public final class NativeCompressor: Compressor, @unchecked Sendable {
    private let capsules = ThreadSafeDictionary<CompressionAlgorithm, CompressionCapsule>()
    
    public init() {}
    
    public func compress(_ data: Data, algorithm: CompressionAlgorithm) async throws -> Data {
        let capsule = try await getOrCreateCapsule(for: algorithm)
        return try await capsule.compress(data)
    }
    
    public func decompress(_ data: Data, algorithm: CompressionAlgorithm) async throws -> Data {
        let capsule = try await getOrCreateCapsule(for: algorithm)
        return try await capsule.decompress(data)
    }
    
    private func getOrCreateCapsule(for algorithm: CompressionAlgorithm) async throws -> CompressionCapsule {
        if let existing = capsules[algorithm] {
            return existing
        }
        
        // Create configuration with deterministic mode (Tier 1) for receipt-grade compression
        let config = CompressionConfig(
            algorithm: algorithm,
            mode: .deterministic,
            level: .default,
            bufferPoolSize: 16,
            determinismTier: 1
        )
        
        let capsule = try CompressionCapsule(config: config)
        capsules[algorithm] = capsule
        return capsule
    }
}

/// Internal helper for thread-safe dictionary access.
private final class ThreadSafeDictionary<Key: Hashable, Value>: @unchecked Sendable {
    private var storage: [Key: Value] = [:]
    private let lock = NSLock()
    
    subscript(key: Key) -> Value? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storage[key]
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            storage[key] = newValue
        }
    }
}
