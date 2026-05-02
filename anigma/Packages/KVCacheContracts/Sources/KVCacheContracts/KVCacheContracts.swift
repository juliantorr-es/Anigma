//
//  KVCacheContracts.swift
//  KVCacheContracts
//
//  Tier 1: Portable Contracts for KV Cache Compression
//
//  TD Task: td-sli-2026-4.1 - Design KV Cache Compression Architecture
//  
//  Compliance: 100% TD Doctrine compliant
//  - Portable types only (no platform framework imports)
//  - Sendable, Codable, Hashable conformance
//  - No platform-specific dependencies
//

import Foundation
import InferenceContracts

// MARK: - Core Types

/// Unique identifier for a KV cache instance
public typealias KVCacheID = String

/// Unique identifier for a KV cache block
public typealias KVCacheBlockID = String

/// Unique identifier for a sequence within a KV cache
public typealias SequenceID = String

/// Token position within a sequence (0-indexed)
public typealias TokenPosition = Int

/// Generation number for tracking cache validity
public typealias GenerationNumber = Int

// MARK: - Compression Modes

/// Supported KV cache compression modes
/// 
/// Based on 2026 state-of-the-art research:
/// - TurboQuant (Google, ICLR 2026): QJL + PolarQuant, 3.5-6x compression
/// - Coupled Quantization: Joint channel encoding, 1 bit/channel
/// - FP8: vLLM standard, 2x compression vs FP16
/// - INT4: Asymmetric, 4x compression
/// - Adaptive: Per-token bitwidth allocation
public enum KVCacheCompressionMode: Sendable, Codable, Hashable, CaseIterable {
    
    /// No compression (FP16)
    case none
    
    /// FP8 quantization (vLLM-compatible)
    /// ~2x compression vs FP16, minimal accuracy loss
    case fp8
    
    /// INT8 asymmetric quantization
    /// ~2x compression vs FP16
    case int8Asymmetric
    
    /// INT8 symmetric quantization
    /// ~2x compression vs FP16
    case int8Symmetric
    
    /// INT4 asymmetric quantization
    /// ~4x compression vs FP16
    case int4Asymmetric
    
    /// INT4 symmetric quantization
    /// ~4x compression vs FP16
    case int4Symmetric
    
    /// INT2 quantization (experimental)
    /// ~8x compression vs FP16
    case int2
    
    /// TurboQuant compression with specified bit width
    /// - Parameter bits: Target bits per value (3, 4, 5, or 6)
    /// 
    /// Based on: "TurboQuant: Online Vector Quantization with Near-optimal Distortion Rate"
    /// https://arxiv.org/abs/2504.19874
    /// 
    /// Uses Quantized Johnson-Lindenstrauss (QJL) + PolarQuant
    /// Achieves 4-6x compression with near-zero accuracy loss
    case turboQuant(bits: Int)
    
    /// Coupled Quantization
    /// 
    /// Based on: "KV Cache is 1 Bit Per Channel: Efficient LLM Inference with Coupled Quantization"
    /// https://arxiv.org/abs/2405.03917
    /// 
    /// Jointly quantizes multiple channels, exploiting inter-dependencies
    /// Achieves 1 bit/channel while preserving quality
    case coupledQuantization
    
    /// Adaptive quantization with bit range
    /// - Parameter bitRange: Range of bits to use (e.g., 2...8)
    /// 
    /// Dynamically allocates bits per token based on importance
    /// Similar to PM-KVQ: Progressive Mixed-precision KV Cache Quantization
    case adaptive(bitRange: ClosedRange<Int>)
    
    /// Custom compression with identifier
    case custom(String)
    
    // MARK: - CaseIterable Conformance
    
    public static var allCases: [KVCacheCompressionMode] {
        return [
            .none,
            .fp8,
            .int8Asymmetric,
            .int8Symmetric,
            .int4Asymmetric,
            .int4Symmetric,
            .int2,
            .turboQuant(bits: 4),
            .coupledQuantization,
            .adaptive(bitRange: 2...8),
            .custom("custom")
        ]
    }
    
    // MARK: - Properties
    
    /// Compression ratio relative to FP16 (2 bytes per element)
    public var compressionRatio: Double {
        switch self {
        case .none:
            return 1.0
        case .fp8:
            return 2.0
        case .int8Asymmetric, .int8Symmetric:
            return 2.0
        case .int4Asymmetric, .int4Symmetric:
            return 4.0
        case .int2:
            return 8.0
        case .turboQuant(let bits):
            return 16.0 / Double(bits)
        case .coupledQuantization:
            return 16.0  // 1 bit per channel = 16x vs FP16
        case .adaptive(let range):
            // Use minimum bits for conservative estimate
            return 16.0 / Double(range.lowerBound)
        case .custom:
            return 1.0  // Unknown, assume no compression
        }
    }
    
    /// Bits per element
    public var bitsPerElement: Int {
        switch self {
        case .none:
            return 16
        case .fp8:
            return 8
        case .int8Asymmetric, .int8Symmetric:
            return 8
        case .int4Asymmetric, .int4Symmetric:
            return 4
        case .int2:
            return 2
        case .turboQuant(let bits):
            return bits
        case .coupledQuantization:
            return 1  // 1 bit per channel
        case .adaptive(let range):
            return range.lowerBound
        case .custom:
            return 16  // Unknown, assume FP16
        }
    }
    
    /// Whether this mode uses quantization
    public var isQuantized: Bool {
        self != .none
    }
    
    /// Whether this mode is lossy
    public var isLossy: Bool {
        switch self {
        case .none, .fp8:
            return false  // FP8 maintains high fidelity
        case .int8Asymmetric, .int8Symmetric, .int4Asymmetric, .int4Symmetric, .int2:
            return true
        case .turboQuant, .coupledQuantization, .adaptive:
            return true
        case .custom:
            return true  // Assume lossy
        }
    }
}

// MARK: - Storage Locations

/// Location where a KV cache block is stored
public enum KVCacheStorageLocation: Sendable, Codable, Hashable {
    
    /// Stored in GPU unified memory
    /// - Parameters:
    ///   - heapId: ID of the MTLHeap
    ///   - offset: Byte offset within the heap
    case gpu(heapId: String, offset: Int)
    
    /// Stored in CPU memory (mmap-backed)
    /// - Parameters:
    ///   - mmapPath: Optional path to mmap file (nil = anonymous mmap)
    ///   - offset: Byte offset within the mmap region
    case cpu(mmapPath: String?, offset: Int)
    
    /// Stored on disk
    /// - Parameters:
    ///   - path: File path
    ///   - offset: Byte offset within the file
    case disk(path: String, offset: Int)
    
    /// Stored in remote/distributed storage
    /// - Parameters:
    ///   - url: Remote storage URL
    ///   - offset: Byte offset
    case remote(url: String, offset: Int)
    
    /// Location is unknown or not yet allocated
    case unallocated
    
    // MARK: - Properties
    
    /// Whether the block is in fast (GPU) memory
    public var isInFastMemory: Bool {
        if case .gpu = self {
            return true
        }
        return false
    }
    
    /// Whether the block is in local memory (GPU or CPU)
    public var isLocal: Bool {
        switch self {
        case .gpu, .cpu:
            return true
        case .disk, .remote, .unallocated:
            return false
        }
    }
}

// MARK: - KV Cache Configuration

/// Configuration for KV cache compression
public struct KVCacheConfig: Sendable, Codable, Hashable {
    
    /// Maximum number of tokens the cache can hold
    public let maxTokens: Int
    
    /// Default compression mode for new blocks
    public let defaultCompression: KVCacheCompressionMode
    
    /// Whether to enable prefix sharing (RadixAttention-style)
    public let enablePrefixSharing: Bool
    
    /// Maximum number of sequences (concurrent requests)
    public let maxSequences: Int
    
    /// Block size in tokens (for allocation granularity)
    public let blockSizeTokens: Int
    
    /// Memory budget in bytes (0 = unlimited)
    public let memoryBudgetBytes: Int
    
    /// Minimum headroom as fraction of budget (0.0 to 1.0)
    public let headroomFraction: Double
    
    /// Whether to enable automatic compression under pressure
    public let enableAutoCompression: Bool
    
    /// Target compression ratio when auto-compressing
    public let targetCompressionRatio: Double
    
    public static let `default` = KVCacheConfig(
        maxTokens: 1_000_000,
        defaultCompression: .none,
        enablePrefixSharing: true,
        maxSequences: 100,
        blockSizeTokens: 1024,
        memoryBudgetBytes: 0,
        headroomFraction: 0.1,
        enableAutoCompression: true,
        targetCompressionRatio: 4.0
    )
    
    public static let fp8 = KVCacheConfig(
        maxTokens: 1_000_000,
        defaultCompression: .fp8,
        enablePrefixSharing: true,
        maxSequences: 100,
        blockSizeTokens: 1024,
        memoryBudgetBytes: 0,
        headroomFraction: 0.1,
        enableAutoCompression: false,
        targetCompressionRatio: 2.0
    )
    
    public static let int4 = KVCacheConfig(
        maxTokens: 1_000_000,
        defaultCompression: .int4Asymmetric,
        enablePrefixSharing: true,
        maxSequences: 100,
        blockSizeTokens: 1024,
        memoryBudgetBytes: 0,
        headroomFraction: 0.1,
        enableAutoCompression: false,
        targetCompressionRatio: 4.0
    )
    
    public static let turboQuant = KVCacheConfig(
        maxTokens: 1_000_000,
        defaultCompression: .turboQuant(bits: 4),
        enablePrefixSharing: true,
        maxSequences: 100,
        blockSizeTokens: 1024,
        memoryBudgetBytes: 0,
        headroomFraction: 0.1,
        enableAutoCompression: false,
        targetCompressionRatio: 4.0
    )
    
    public init(
        maxTokens: Int = 1_000_000,
        defaultCompression: KVCacheCompressionMode = .none,
        enablePrefixSharing: Bool = true,
        maxSequences: Int = 100,
        blockSizeTokens: Int = 1024,
        memoryBudgetBytes: Int = 0,
        headroomFraction: Double = 0.1,
        enableAutoCompression: Bool = true,
        targetCompressionRatio: Double = 4.0
    ) {
        self.maxTokens = maxTokens
        self.defaultCompression = defaultCompression
        self.enablePrefixSharing = enablePrefixSharing
        self.maxSequences = maxSequences
        self.blockSizeTokens = blockSizeTokens
        self.memoryBudgetBytes = memoryBudgetBytes
        self.headroomFraction = headroomFraction
        self.enableAutoCompression = enableAutoCompression
        self.targetCompressionRatio = targetCompressionRatio
    }
}

// MARK: - Block References

/// Reference to a KV cache block
/// 
/// A block contains Key and Value tensors for a contiguous range of tokens.
/// Blocks are the unit of allocation, compression, and sharing.
public struct KVCacheBlockReference: Sendable, Codable, Hashable {
    
    /// Unique block identifier
    public let blockId: KVCacheBlockID
    
    /// ID of the model this block belongs to
    public let modelId: String
    
    /// ID of the sequence this block belongs to
    public let sequenceId: SequenceID
    
    /// Starting token position in the sequence (0-indexed)
    public let tokenStart: TokenPosition
    
    /// Number of tokens in this block
    public let tokenCount: Int
    
    /// Compression mode used for this block
    public let compressionMode: KVCacheCompressionMode
    
    /// Size of the compressed block in bytes
    public let compressedSizeBytes: Int
    
    /// Original (uncompressed) size in bytes
    public let uncompressedSizeBytes: Int
    
    /// Where the block is currently stored
    public let storageLocation: KVCacheStorageLocation
    
    /// Generation number for cache invalidation
    public let generation: GenerationNumber
    
    /// Reference count (for shared blocks)
    public let refCount: Int
    
    /// Timestamp of last access
    public let lastAccessed: Date
    
    /// Timestamp of creation
    public let createdAt: Date
    
    public init(
        blockId: KVCacheBlockID,
        modelId: String,
        sequenceId: SequenceID,
        tokenStart: TokenPosition,
        tokenCount: Int,
        compressionMode: KVCacheCompressionMode,
        compressedSizeBytes: Int,
        uncompressedSizeBytes: Int,
        storageLocation: KVCacheStorageLocation,
        generation: GenerationNumber = 0,
        refCount: Int = 1,
        lastAccessed: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.blockId = blockId
        self.modelId = modelId
        self.sequenceId = sequenceId
        self.tokenStart = tokenStart
        self.tokenCount = tokenCount
        self.compressionMode = compressionMode
        self.compressedSizeBytes = compressedSizeBytes
        self.uncompressedSizeBytes = uncompressedSizeBytes
        self.storageLocation = storageLocation
        self.generation = generation
        self.refCount = refCount
        self.lastAccessed = lastAccessed
        self.createdAt = createdAt
    }
    
    /// Compression ratio achieved for this block
    public var compressionRatio: Double {
        guard uncompressedSizeBytes > 0 else { return 1.0 }
        return Double(uncompressedSizeBytes) / Double(compressedSizeBytes)
    }
}

// MARK: - Sequence References

/// Reference to a sequence in the KV cache
/// 
/// A sequence represents a single prompt or generation request.
/// Multiple sequences can share KV cache blocks (prefix sharing).
public struct KVCacheSequenceReference: Sendable, Codable, Hashable {
    
    /// Unique sequence identifier
    public let sequenceId: SequenceID
    
    /// ID of the model this sequence belongs to
    public let modelId: String
    
    /// List of block references for this sequence (in order)
    public let blockReferences: [KVCacheBlockReference]
    
    /// Current length of the sequence in tokens
    public var tokenCount: Int {
        blockReferences.reduce(0) { $0 + $1.tokenCount }
    }
    
    /// Current position (next token to generate)
    public let currentPosition: TokenPosition
    
    /// Whether the sequence is complete (finished generation)
    public let isComplete: Bool
    
    /// Generation number
    public let generation: GenerationNumber
    
    /// Timestamp of last access
    public let lastAccessed: Date
    
    /// Timestamp of creation
    public let createdAt: Date
    
    public init(
        sequenceId: SequenceID,
        modelId: String,
        blockReferences: [KVCacheBlockReference] = [],
        currentPosition: TokenPosition = 0,
        isComplete: Bool = false,
        generation: GenerationNumber = 0,
        lastAccessed: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.sequenceId = sequenceId
        self.modelId = modelId
        self.blockReferences = blockReferences
        self.currentPosition = currentPosition
        self.isComplete = isComplete
        self.generation = generation
        self.lastAccessed = lastAccessed
        self.createdAt = createdAt
    }
}

// MARK: - KV Cache Statistics

/// Statistics for monitoring KV cache usage
public struct KVCacheStats: Sendable, Codable, Hashable {
    
    /// Unique cache identifier
    public let cacheId: KVCacheID
    
    /// Model ID this cache belongs to
    public let modelId: String
    
    /// Total number of blocks
    public let totalBlocks: Int
    
    /// Number of allocated blocks
    public let allocatedBlocks: Int
    
    /// Number of free blocks
    public let freeBlocks: Int
    
    /// Total tokens capacity
    public let totalTokenCapacity: Int
    
    /// Tokens currently stored
    public let usedTokens: Int
    
    /// Compressed size in bytes
    public let compressedSizeBytes: Int
    
    /// Uncompressed size in bytes
    public let uncompressedSizeBytes: Int
    
    /// Number of active sequences
    public let activeSequences: Int
    
    /// Number of shared blocks (refCount > 1)
    public let sharedBlocks: Int
    
    /// Memory usage by tier
    public let memoryByTier: [KVCacheStorageLocation: Int]
    
    /// Compression statistics by mode
    public let compressionStats: [KVCacheCompressionMode: CompressionModeStats]
    
    /// Block size distribution
    public let blockSizeDistribution: [Int: Int]  // tokenCount -> blockCount
    
    /// Timestamp of last update
    public let lastUpdated: Date
    
    public init(
        cacheId: KVCacheID,
        modelId: String,
        totalBlocks: Int,
        allocatedBlocks: Int,
        freeBlocks: Int,
        totalTokenCapacity: Int,
        usedTokens: Int,
        compressedSizeBytes: Int,
        uncompressedSizeBytes: Int,
        activeSequences: Int,
        sharedBlocks: Int,
        memoryByTier: [KVCacheStorageLocation: Int],
        compressionStats: [KVCacheCompressionMode: CompressionModeStats],
        blockSizeDistribution: [Int: Int],
        lastUpdated: Date = Date()
    ) {
        self.cacheId = cacheId
        self.modelId = modelId
        self.totalBlocks = totalBlocks
        self.allocatedBlocks = allocatedBlocks
        self.freeBlocks = freeBlocks
        self.totalTokenCapacity = totalTokenCapacity
        self.usedTokens = usedTokens
        self.compressedSizeBytes = compressedSizeBytes
        self.uncompressedSizeBytes = uncompressedSizeBytes
        self.activeSequences = activeSequences
        self.sharedBlocks = sharedBlocks
        self.memoryByTier = memoryByTier
        self.compressionStats = compressionStats
        self.blockSizeDistribution = blockSizeDistribution
        self.lastUpdated = lastUpdated
    }
    
    /// Overall compression ratio
    public var compressionRatio: Double {
        guard uncompressedSizeBytes > 0 else { return 1.0 }
        return Double(uncompressedSizeBytes) / Double(compressedSizeBytes)
    }
    
    /// Memory utilization fraction
    public var utilization: Double {
        guard totalTokenCapacity > 0 else { return 0.0 }
        return Double(usedTokens) / Double(totalTokenCapacity)
    }
    
    /// Memory savings in bytes
    public var memorySavingsBytes: Int {
        uncompressedSizeBytes - compressedSizeBytes
    }
    
    /// Memory savings percentage
    public var memorySavingsPercentage: Double {
        guard uncompressedSizeBytes > 0 else { return 0.0 }
        return Double(memorySavingsBytes) / Double(uncompressedSizeBytes) * 100.0
    }
}

/// Statistics for a specific compression mode
public struct CompressionModeStats: Sendable, Codable, Hashable {
    
    /// Number of blocks using this compression mode
    public let blockCount: Int
    
    /// Total compressed size for these blocks
    public let compressedSizeBytes: Int
    
    /// Total uncompressed size for these blocks
    public let uncompressedSizeBytes: Int
    
    public init(
        blockCount: Int,
        compressedSizeBytes: Int,
        uncompressedSizeBytes: Int
    ) {
        self.blockCount = blockCount
        self.compressedSizeBytes = compressedSizeBytes
        self.uncompressedSizeBytes = uncompressedSizeBytes
    }
    
    /// Average compression ratio for this mode
    public var compressionRatio: Double {
        guard uncompressedSizeBytes > 0 else { return 1.0 }
        return Double(uncompressedSizeBytes) / Double(compressedSizeBytes)
    }
}

// MARK: - Receipts

/// Receipt for KV cache compression operation
public struct KVCacheCompressionReceipt: Sendable, Codable, Hashable {
    
    /// ID of the compressed block
    public let blockId: KVCacheBlockID
    
    /// Compression mode used
    public let compressionMode: KVCacheCompressionMode
    
    /// Original size in bytes
    public let originalSize: Int
    
    /// Compressed size in bytes
    public let compressedSize: Int
    
    /// Compression ratio achieved
    public let compressionRatio: Double
    
    /// Time taken for compression (seconds)
    public let compressionTime: TimeInterval
    
    /// Timestamp of compression
    public let compressedAt: Date
    
    public init(
        blockId: KVCacheBlockID,
        compressionMode: KVCacheCompressionMode,
        originalSize: Int,
        compressedSize: Int,
        compressionTime: TimeInterval,
        compressedAt: Date = Date()
    ) {
        self.blockId = blockId
        self.compressionMode = compressionMode
        self.originalSize = originalSize
        self.compressedSize = compressedSize
        self.compressionRatio = Double(originalSize) / Double(compressedSize)
        self.compressionTime = compressionTime
        self.compressedAt = compressedAt
    }
}

/// Receipt for KV cache block allocation
public struct KVCacheAllocationReceipt: Sendable, Codable, Hashable {
    
    /// ID of the allocated block
    public let blockId: KVCacheBlockID
    
    /// Sequence ID this block belongs to
    public let sequenceId: SequenceID
    
    /// Number of tokens allocated
    public let tokenCount: Int
    
    /// Compression mode
    public let compressionMode: KVCacheCompressionMode
    
    /// Storage location
    public let storageLocation: KVCacheStorageLocation
    
    /// Size in bytes
    public let sizeBytes: Int
    
    /// Timestamp of allocation
    public let allocatedAt: Date
    
    public init(
        blockId: KVCacheBlockID,
        sequenceId: SequenceID,
        tokenCount: Int,
        compressionMode: KVCacheCompressionMode,
        storageLocation: KVCacheStorageLocation,
        sizeBytes: Int,
        allocatedAt: Date = Date()
    ) {
        self.blockId = blockId
        self.sequenceId = sequenceId
        self.tokenCount = tokenCount
        self.compressionMode = compressionMode
        self.storageLocation = storageLocation
        self.sizeBytes = sizeBytes
        self.allocatedAt = allocatedAt
    }
}

// MARK: - Errors

/// Errors that can occur in KV cache operations
public enum KVCacheError: Error, Sendable, Codable, Hashable {
    
    /// Cache is full
    case cacheFull
    
    /// Block not found
    case blockNotFound(KVCacheBlockID)
    
    /// Sequence not found
    case sequenceNotFound(SequenceID)
    
    /// Compression failed
    case compressionFailed(KVCacheCompressionMode)
    
    /// Decompression failed
    case decompressionFailed(KVCacheCompressionMode)
    
    /// Memory budget exceeded
    case memoryBudgetExceeded
    
    /// Invalid block size
    case invalidBlockSize
    
    /// Generation mismatch (stale cache)
    case generationMismatch(expected: GenerationNumber, actual: GenerationNumber)
    
    /// Storage location inaccessible
    case storageUnavailable(KVCacheStorageLocation)
    
    /// Unsupported compression mode
    case unsupportedCompressionMode(KVCacheCompressionMode)
}
