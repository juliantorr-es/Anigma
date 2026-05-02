//
//  InferenceContracts.swift
//  InferenceContracts
//
//  Portable contracts for saturated local inference architecture.
//  Tier 1 - Platform-agnostic contracts only.
//
//  Compliance: 100% TD Doctrine compliant
//  - No platform framework imports
//  - Uses Anigma-owned types only
//  - All types are Sendable
//  - No @_exported imports
//

import Foundation

/// Unique identifier for inference contracts
public struct InferenceContractID: Sendable, Codable, Hashable {
  public let name: String
  public let major: Int
  public let minor: Int
  public let schemaHash: String

  public init(name: String, major: Int, minor: Int, schemaHash: String) {
    self.name = name
    self.major = major
    self.minor = minor
    self.schemaHash = schemaHash
  }
}

/// Reference to a tensor in unified memory
/// Portable wrapper that abstracts platform-specific buffer types
public struct UnifiedTensorReference: Sendable, Codable, Hashable {
  public let id: String
  public let shape: [Int]
  public let dataType: TensorDataType
  public let memoryPoolID: String
  public let offset: Int
  public let stride: [Int]?

  public init(
    id: String,
    shape: [Int],
    dataType: TensorDataType,
    memoryPoolID: String,
    offset: Int = 0,
    stride: [Int]? = nil
  ) {
    self.id = id
    self.shape = shape
    self.dataType = dataType
    self.memoryPoolID = memoryPoolID
    self.offset = offset
    self.stride = stride
  }
}

/// Supported tensor data types for inference
public enum TensorDataType: String, Codable, Sendable, CaseIterable, Hashable {
  case float32
  case float16
  case float8
  case bfloat16
  case int8
  case int4
  case int32
  case uint8

  public var byteSize: Int {
    switch self {
    case .float32: return 4
    case .float16: return 2
    case .float8: return 1
    case .bfloat16: return 2
    case .int8: return 1
    case .int4: return 1  // Packed representation
    case .int32: return 4
    case .uint8: return 1
    }
  }
}

/// Configuration for KV cache behavior
public struct KVCacheConfig: Sendable, Codable, Hashable {
  public let maxTokens: Int
  public let compressionMode: KVCacheCompressionMode
  public let compressionThreshold: Int
  public let evictionPolicy: KVCacheEvictionPolicy

  public init(
    maxTokens: Int,
    compressionMode: KVCacheCompressionMode = .disabled,
    compressionThreshold: Int = 2048,
    evictionPolicy: KVCacheEvictionPolicy = .fifo
  ) {
    self.maxTokens = maxTokens
    self.compressionMode = compressionMode
    self.compressionThreshold = compressionThreshold
    self.evictionPolicy = evictionPolicy
  }
}

/// KV cache compression modes
public enum KVCacheCompressionMode: String, Codable, Sendable, CaseIterable {
  case disabled
  case int8Symmetric
  case int8Asymmetric
  case int4Symmetric
  case int4Asymmetric
  case adaptive

  public var compressionRatio: Double {
    switch self {
    case .disabled: return 1.0
    case .int8Symmetric, .int8Asymmetric: return 2.0
    case .int4Symmetric, .int4Asymmetric: return 4.0
    case .adaptive: return 3.0  // Average
    }
  }
}

/// KV cache eviction policy
public enum KVCacheEvictionPolicy: String, Codable, Sendable, CaseIterable {
  case fifo
  case lru
  case lfu
  case priorityBased
}

/// Memory pool configuration
public struct MemoryPoolConfig: Sendable, Codable, Hashable {
  public let poolID: String
  public let initialSize: Int
  public let maxSize: Int
  public let heapSizes: [Int]
  public let alignment: Int

  public static let `default` = MemoryPoolConfig(
    poolID: "default",
    initialSize: 256 * 1024 * 1024,  // 256MB
    maxSize: 2 * 1024 * 1024 * 1024,  // 2GB
    heapSizes: [64 * 1024 * 1024, 128 * 1024 * 1024, 256 * 1024 * 1024],
    alignment: 256
  )

  public init(
    poolID: String, initialSize: Int, maxSize: Int, heapSizes: [Int], alignment: Int = 256
  ) {
    self.poolID = poolID
    self.initialSize = initialSize
    self.maxSize = maxSize
    self.heapSizes = heapSizes
    self.alignment = alignment
  }
}

/// Saturation monitoring configuration
public struct SaturationConfig: Sendable, Codable, Hashable {
  public let targetCPUSaturation: Double
  public let targetGPUSaturation: Double
  public let targetANESaturation: Double
  public let samplingIntervalMs: Int
  public let backpressureThreshold: Double

  public static let `default` = SaturationConfig(
    targetCPUSaturation: 0.95,
    targetGPUSaturation: 0.95,
    targetANESaturation: 0.90,
    samplingIntervalMs: 100,
    backpressureThreshold: 0.85
  )

  public init(
    targetCPUSaturation: Double = 0.95,
    targetGPUSaturation: Double = 0.95,
    targetANESaturation: Double = 0.90,
    samplingIntervalMs: Int = 100,
    backpressureThreshold: Double = 0.85
  ) {
    self.targetCPUSaturation = targetCPUSaturation
    self.targetGPUSaturation = targetGPUSaturation
    self.targetANESaturation = targetANESaturation
    self.samplingIntervalMs = samplingIntervalMs
    self.backpressureThreshold = backpressureThreshold
  }
}

/// Inference phase (prefill vs decode)
public enum InferencePhase: String, Codable, Sendable, CaseIterable {
  case prefill
  case decode
}

/// Compute unit preference for scheduling
public enum ComputeUnitPreference: String, Codable, Sendable, CaseIterable {
  case any
  case cpuOnly
  case gpuPreferred
  case gpuOnly
  case anePreferred
  case aneOnly
}

/// Inference configuration with saturation-specific options
public struct SaturatedInferenceConfig: Sendable, Codable, Hashable {
  public static let id = InferenceContractID(
    name: "inference.saturated.config",
    major: 1,
    minor: 0,
    schemaHash: "sli-2026-v1"
  )

  public let phase: InferencePhase
  public let kvCacheConfig: KVCacheConfig
  public let saturationConfig: SaturationConfig
  public let computeUnitPreference: ComputeUnitPreference
  public let numThreads: Int?
  public let batchSize: Int?

  public init(
    phase: InferencePhase = .prefill,
    kvCacheConfig: KVCacheConfig = KVCacheConfig(maxTokens: 4096),
    saturationConfig: SaturationConfig = .default,
    computeUnitPreference: ComputeUnitPreference = .any,
    numThreads: Int? = nil,
    batchSize: Int? = nil
  ) {
    self.phase = phase
    self.kvCacheConfig = kvCacheConfig
    self.saturationConfig = saturationConfig
    self.computeUnitPreference = computeUnitPreference
    self.numThreads = numThreads
    self.batchSize = batchSize
  }
}

/// Portable reference to an inference model with saturation metadata
public struct SaturatedModelReference: Sendable, Codable, Hashable {
  public let id: String
  public let modelHash: String
  public let parameterCount: Int
  public let quantized: Bool
  public let quantizationBits: Int?
  public let predigested: Bool
  public let memoryEstimate: Int

  public init(
    id: String,
    modelHash: String,
    parameterCount: Int,
    quantized: Bool = false,
    quantizationBits: Int? = nil,
    predigested: Bool = false,
    memoryEstimate: Int = 0
  ) {
    self.id = id
    self.modelHash = modelHash
    self.parameterCount = parameterCount
    self.quantized = quantized
    self.quantizationBits = quantizationBits
    self.predigested = predigested
    self.memoryEstimate = memoryEstimate
  }
}

/// Receipt for saturated inference execution
public struct SaturatedInferenceReceipt: Sendable, Codable, Hashable {
  public static let id = InferenceContractID(
    name: "inference.saturated.receipt",
    major: 1,
    minor: 0,
    schemaHash: "sli-2026-v1"
  )

  public let requestId: String
  public let modelHash: String
  public let backend: String
  public let computeUnits: [String]
  public let osVersion: String
  public let executionTimeMs: Int
  public let cpuSaturation: Double
  public let gpuSaturation: Double?
  public let aneSaturation: Double?
  public let memoryUsedBytes: Int
  public let kvCacheCompressionRatio: Double?
  public let tokensProcessed: Int
  public let phase: InferencePhase

  public init(
    requestId: String,
    modelHash: String,
    backend: String,
    computeUnits: [String],
    osVersion: String,
    executionTimeMs: Int,
    cpuSaturation: Double,
    gpuSaturation: Double? = nil,
    aneSaturation: Double? = nil,
    memoryUsedBytes: Int,
    kvCacheCompressionRatio: Double? = nil,
    tokensProcessed: Int,
    phase: InferencePhase
  ) {
    self.requestId = requestId
    self.modelHash = modelHash
    self.backend = backend
    self.computeUnits = computeUnits
    self.osVersion = osVersion
    self.executionTimeMs = executionTimeMs
    self.cpuSaturation = cpuSaturation
    self.gpuSaturation = gpuSaturation
    self.aneSaturation = aneSaturation
    self.memoryUsedBytes = memoryUsedBytes
    self.kvCacheCompressionRatio = kvCacheCompressionRatio
    self.tokensProcessed = tokensProcessed
    self.phase = phase
  }
}

/// Memory allocation receipt for tracking
public struct MemoryAllocationReceipt: Sendable, Codable, Hashable {
  public let allocationId: String
  public let poolId: String
  public let size: Int
  public let tensorReference: UnifiedTensorReference?
  public let allocatedAt: Date
  public let deallocatedAt: Date?

  public init(
    allocationId: String,
    poolId: String,
    size: Int,
    tensorReference: UnifiedTensorReference? = nil,
    allocatedAt: Date = Date(),
    deallocatedAt: Date? = nil
  ) {
    self.allocationId = allocationId
    self.poolId = poolId
    self.size = size
    self.tensorReference = tensorReference
    self.allocatedAt = allocatedAt
    self.deallocatedAt = deallocatedAt
  }
}

/// Pool statistics for monitoring
public struct MemoryPoolStats: Sendable, Codable, Hashable {
  public let poolId: String
  public let totalAllocated: Int
  public let totalUsed: Int
  public let totalAvailable: Int
  public let heapCount: Int
  public let allocationCount: Int
  public let fragmentationRatio: Double

  public init(
    poolId: String,
    totalAllocated: Int,
    totalUsed: Int,
    totalAvailable: Int,
    heapCount: Int,
    allocationCount: Int,
    fragmentationRatio: Double
  ) {
    self.poolId = poolId
    self.totalAllocated = totalAllocated
    self.totalUsed = totalUsed
    self.totalAvailable = totalAvailable
    self.heapCount = heapCount
    self.allocationCount = allocationCount
    self.fragmentationRatio = fragmentationRatio
  }
}
