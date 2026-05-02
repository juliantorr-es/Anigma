// HarmoniaCore - Shared Infrastructure
// Version: 0.1.0-migration
//
// This module provides shared types and protocols for all HarmoniaV2 modules.
// All types are pure values with zero side effects.

import Foundation
import AnigmaFoundation

/// Shared types and protocols across all Harmonia modules

// MARK: - Versioning

public let harmoniaVersion = "2.0.0-alpha"

// MARK: - Type Organization
//
// Types are organized in separate files:
// - ReasoningTypes.swift: Two-tier reasoning, puzzles, TRM config
// - InferenceTypes.swift: Inference tasks, constraints, results

// MARK: - Core Protocols

/// Capability marker for modules that provide inference
public protocol InferenceCapability {
    associatedtype InputType
    associatedtype OutputType
    
    func infer(_ input: InputType) async throws -> OutputType
}

/// Capability marker for modules that provide memory/storage
public protocol MemoryCapability {
    associatedtype ItemType
    
    func store(_ item: ItemType) async throws
    func retrieve(matching query: String) async throws -> [ItemType]
}

/// Capability marker for modules that orchestrate workflows
public protocol OrchestrationCapability {
    func execute() async throws
    func cancel() async throws
}

// MARK: - Shared Value Types

/// Generic result wrapper for operations
public struct OperationResult<T> {
    public let value: T?
    public let error: Error?
    public let timestamp: Date
    
    public init(value: T?, error: Error? = nil, timestamp: Date = Date()) {
        self.value = value
        self.error = error
        self.timestamp = timestamp
    }
    
    public var isSuccess: Bool { error == nil }
}

/// Execution context shared across modules
public struct ExecutionContext: Sendable {
    public let sessionId: String
    public let userId: String?
    public let timestamp: Date
    
    public init(sessionId: String, userId: String? = nil, timestamp: Date = Date()) {
        self.sessionId = sessionId
        self.userId = userId
        self.timestamp = timestamp
    }
}

// MARK: - Module Registration

/// Registry for module initialization and lifecycle
public actor ModuleRegistry {
    private var registeredModules: Set<String> = []
    
    public init() {}
    
    public func register(module name: String) {
        registeredModules.insert(name)
    }
    
    public func isRegistered(_ name: String) -> Bool {
        registeredModules.contains(name)
    }
}

// MARK: - Errors

// Compatibility alias for HarmoniaError is now in AnigmaFoundation/MemoryTypes.swift
// but we re-export it here if needed, or just let AnigmaFoundation handle it.
// Actually, MemoryTypes.swift already defines public typealias HarmoniaError = MemoryStoreError.

// MARK: - Embedding Utilities

/// Utilities for encoding and decoding embeddings as Float32 little-endian BLOB.
/// These are pure functions reused across memory storage and chunk storage.
public enum EmbeddingCodec {
    /// Encode a Float array to little-endian Float32 BLOB
    public static func encode(_ embedding: [Float]) -> Data {
        var data = Data(capacity: embedding.count * 4)
        for value in embedding {
            var float32 = Float32(value)
            withUnsafeBytes(of: &float32) { bytes in
                data.append(contentsOf: bytes)
            }
        }
        return data
    }
    
    /// Decode little-endian Float32 BLOB to Float array
    /// - Throws: HarmoniaError.invalidArgument if data length is not multiple of 4
    public static func decode(_ data: Data, expectedDim: Int? = nil) throws -> [Float] {
        guard data.count % 4 == 0 else {
            throw HarmoniaError.invalidArgument("Embedding data length \(data.count) is not multiple of 4")
        }
        
        let count = data.count / 4
        if let expectedDim = expectedDim, count != expectedDim {
            throw HarmoniaError.embeddingDimensionMismatch("Expected \(expectedDim) dimensions, got \(count)")
        }
        
        var result: [Float] = []
        result.reserveCapacity(count)
        
        for i in 0..<count {
            let offset = i * 4
            let bytes = data.subdata(in: offset..<offset+4)
            let float32 = bytes.withUnsafeBytes { $0.load(as: Float32.self) }
            result.append(Float(float32))
        }
        
        return result
    }
}
