# CompressionCapsule Specification

**Date**: 2026-01-13  
**Author**: opencode  
**Status**: Draft  
**Determinism Tier**: Tier 1 (bitwise identical across runs) for canonical compression  
**Priority**: Medium  
**Dependencies**: zstd, brotli, lz4 system libraries (or vendored source)

## 1. Overview

The CompressionCapsule provides high‑performance compression and decompression using industry‑standard algorithms (zstd, brotli, lz4) with streaming support, dictionary training, and buffer pooling. It replaces the mock implementation in `CompressionKit` with real compression libraries while maintaining the capsule pattern of "Swift governs, C++ computes".

## 2. Requirements

### 2.1 Functional Requirements

1. **Multiple algorithm support**:
   - **zstd** (Zstandard): High compression ratio with good speed
   - **brotli**: Excellent compression ratio (web‑oriented)
   - **lz4**: Extremely fast compression/decompression
   - **deflate/gzip**: Legacy support via zlib

2. **Streaming API**:
   - Compress/decompress data in chunks
   - Support for indefinite streams (network, logs)
   - Flush/finish semantics

3. **Dictionary training**:
   - Train custom dictionaries on domain‑specific data
   - Save/load dictionaries for reuse
   - Improve compression ratio for similar data

4. **Buffer pooling**:
   - Reuse compression/decompression buffers
   - Reduce allocation overhead for high‑throughput scenarios
   - Configurable pool sizes

5. **Deterministic compression**:
   - Tier 1: Bitwise identical output for same input with fixed parameters
   - Tier 2: High‑performance compression with runtime optimizations

6. **Compression levels**:
   - Preset levels for each algorithm (e.g., zstd levels 1‑22)
   - Custom parameter tuning (window size, strategy, etc.)

7. **Format compatibility**:
   - Produce standard‑compliant compressed formats
   - Interoperable with standard tools (zstd, brotli, lz4 commands)
   - Header/footer metadata for self‑describing streams

### 2.2 Non‑Functional Requirements

1. **Performance**: Near‑native library speed (2–5× speedup vs. Swift‑only mock)
2. **Memory**: Configurable memory limits for dictionary training and streaming
3. **Determinism**: Tier 1 for canonical compression (fixed parameters)
4. **Thread safety**: Capsule must be thread‑safe for concurrent operations
5. **Error handling**: Graceful handling of corrupted data, out‑of‑memory conditions

## 3. C API Design

### 3.1 Header File Draft (`anigma_compression_capsule.h`)

```c
#ifndef ANIGMA_COMPRESSION_CAPSULE_H
#define ANIGMA_COMPRESSION_CAPSULE_H

#include "anigma_capsule_core.h"
#include <stddef.h>
#include <stdint.h>

#if defined(__cplusplus)
extern "C" {
#endif

// ============================================================================
// Compression Capsule Types
// ============================================================================

typedef anigma_capsule_handle_t anigma_compression_capsule_t;

// Compression algorithm enumeration
enum anigma_compression_algorithm_t {
    ANIGMA_COMPRESSION_ZSTD = 0,
    ANIGMA_COMPRESSION_BROTLI = 1,
    ANIGMA_COMPRESSION_LZ4 = 2,
    ANIGMA_COMPRESSION_DEFLATE = 3,
    ANIGMA_COMPRESSION_GZIP = 4
};

// Compression operation mode
enum anigma_compression_mode_t {
    ANIGMA_COMPRESSION_MODE_COMPRESS = 0,
    ANIGMA_COMPRESSION_MODE_DECOMPRESS = 1,
    ANIGMA_COMPRESSION_MODE_DICTIONARY_TRAIN = 2
};

// Compression level preset
enum anigma_compression_level_t {
    ANIGMA_COMPRESSION_LEVEL_FASTEST = 0,
    ANIGMA_COMPRESSION_LEVEL_DEFAULT = 1,
    ANIGMA_COMPRESSION_LEVEL_BEST = 2,
    ANIGMA_COMPRESSION_LEVEL_CUSTOM = 3
};

// Configuration structure
struct anigma_compression_config_t {
    enum anigma_compression_algorithm_t algorithm;
    enum anigma_compression_mode_t mode;
    enum anigma_compression_level_t level;
    uint32_t custom_level;          // Used when level == CUSTOM
    uint32_t determinism_tier;      // ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    uint8_t use_dictionary;         // Whether to use dictionary
    uint8_t streaming;              // Whether to use streaming API
    uint32_t window_size;           // Sliding window size (bytes)
    uint32_t dictionary_size;       // Dictionary size for training (bytes)
    uint32_t max_memory_mb;         // Maximum memory usage (MB)
    uint32_t buffer_pool_size;      // Buffer pool capacity
};

// Dictionary handle (opaque)
typedef struct anigma_compression_dict_t* anigma_compression_dict_handle_t;

// Streaming context (opaque)
typedef struct anigma_compression_stream_t* anigma_compression_stream_handle_t;

// Buffer descriptor for pooling
struct anigma_compression_buffer_t {
    uint8_t* data;
    size_t size;
    size_t capacity;
    uint64_t timestamp;     // Last use timestamp for LRU eviction
};

// Compression statistics
struct anigma_compression_stats_t {
    uint64_t input_bytes;
    uint64_t output_bytes;
    double compression_ratio;       // output / input
    double throughput_mbps;         // Megabytes per second
    uint64_t processing_time_ns;
    uint32_t dictionary_size;       // Size of dictionary used (0 if none)
};

// ============================================================================
// Core Capsule Functions
// ============================================================================

/**
 * Get compression capsule identity.
 */
anigma_capsule_identity_t anigma_compression_capsule_get_identity(void);

/**
 * Create a compression capsule context with given configuration.
 */
anigma_status_t anigma_compression_capsule_create(
    const struct anigma_compression_config_t* config,
    anigma_compression_capsule_t* out_handle,
    anigma_capsule_error_t* err
);

/**
 * Destroy a compression capsule context.
 */
anigma_status_t anigma_compression_capsule_destroy(
    anigma_compression_capsule_t handle,
    anigma_capsule_error_t* err
);

// ============================================================================
// One-Shot Compression/Decompression
// ============================================================================

/**
 * Compress data in one shot.
 * Two‑phase buffer fill pattern.
 * 
 * Phase 1: Call with out_data = NULL to get required size (in err->aux)
 * Phase 2: Allocate buffer and call again
 */
anigma_status_t anigma_compression_capsule_compress(
    anigma_compression_capsule_t handle,
    const uint8_t* input_data,
    size_t input_size,
    uint8_t* out_data,
    size_t out_capacity,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

/**
 * Decompress data in one shot.
 * Two‑phase buffer fill pattern.
 */
anigma_status_t anigma_compression_capsule_decompress(
    anigma_compression_capsule_t handle,
    const uint8_t* input_data,
    size_t input_size,
    uint8_t* out_data,
    size_t out_capacity,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

// ============================================================================
// Streaming API
// ============================================================================

/**
 * Create a streaming context for compression/decompression.
 */
anigma_status_t anigma_compression_capsule_stream_create(
    anigma_compression_capsule_t handle,
    anigma_compression_stream_handle_t* out_stream,
    anigma_capsule_error_t* err
);

/**
 * Destroy a streaming context.
 */
anigma_status_t anigma_compression_capsule_stream_destroy(
    anigma_compression_stream_handle_t stream,
    anigma_capsule_error_t* err
);

/**
 * Process data through streaming context.
 * 
 * @param stream Streaming context
 * @param input Input data
 * @param input_size Input data size
 * @param output Output buffer
 * @param output_capacity Output buffer capacity
 * @param out_consumed Actual input bytes consumed
 * @param out_produced Actual output bytes produced
 * @param flush 0 = no flush, 1 = sync flush, 2 = full flush
 * @param err Error output
 * 
 * @return ANIGMA_OK on success, ANIGMA_ERR_BUFFER_TOO_SMALL if output buffer too small
 */
anigma_status_t anigma_compression_capsule_stream_process(
    anigma_compression_stream_handle_t stream,
    const uint8_t* input,
    size_t input_size,
    uint8_t* output,
    size_t output_capacity,
    size_t* out_consumed,
    size_t* out_produced,
    int flush,
    anigma_capsule_error_t* err
);

/**
 * Finish streaming operation (emit any pending data).
 */
anigma_status_t anigma_compression_capsule_stream_finish(
    anigma_compression_stream_handle_t stream,
    uint8_t* output,
    size_t output_capacity,
    size_t* out_produced,
    anigma_capsule_error_t* err
);

/**
 * Reset streaming context for reuse with same parameters.
 */
anigma_status_t anigma_compression_capsule_stream_reset(
    anigma_compression_stream_handle_t stream,
    anigma_capsule_error_t* err
);

// ============================================================================
// Dictionary Management
// ============================================================================

/**
 * Train a compression dictionary from sample data.
 */
anigma_status_t anigma_compression_capsule_train_dictionary(
    anigma_compression_capsule_t handle,
    const uint8_t* samples[],
    const size_t sample_sizes[],
    size_t sample_count,
    anigma_compression_dict_handle_t* out_dict,
    anigma_capsule_error_t* err
);

/**
 * Load a previously saved dictionary.
 */
anigma_status_t anigma_compression_capsule_load_dictionary(
    anigma_compression_capsule_t handle,
    const uint8_t* dict_data,
    size_t dict_size,
    anigma_compression_dict_handle_t* out_dict,
    anigma_capsule_error_t* err
);

/**
 * Save dictionary to buffer.
 * Two‑phase buffer fill pattern.
 */
anigma_status_t anigma_compression_capsule_save_dictionary(
    anigma_compression_dict_handle_t dict,
    uint8_t* out_data,
    size_t out_capacity,
    size_t* out_actual,
    anigma_capsule_error_t* err
);

/**
 * Destroy a dictionary.
 */
anigma_status_t anigma_compression_capsule_destroy_dictionary(
    anigma_compression_dict_handle_t dict,
    anigma_capsule_error_t* err
);

/**
 * Use dictionary for subsequent compression/decompression.
 */
anigma_status_t anigma_compression_capsule_use_dictionary(
    anigma_compression_capsule_t handle,
    anigma_compression_dict_handle_t dict,
    anigma_capsule_error_t* err
);

// ============================================================================
// Buffer Pool Management
// ============================================================================

/**
 * Get buffer from pool (or allocate new one).
 */
anigma_status_t anigma_compression_capsule_buffer_get(
    anigma_compression_capsule_t handle,
    size_t min_size,
    struct anigma_compression_buffer_t* out_buffer,
    anigma_capsule_error_t* err
);

/**
 * Return buffer to pool for reuse.
 */
anigma_status_t anigma_compression_capsule_buffer_return(
    anigma_compression_capsule_t handle,
    struct anigma_compression_buffer_t* buffer,
    anigma_capsule_error_t* err
);

/**
 * Clear buffer pool (release all buffers).
 */
anigma_status_t anigma_compression_capsule_buffer_pool_clear(
    anigma_compression_capsule_t handle,
    anigma_capsule_error_t* err
);

// ============================================================================
// Statistics and Diagnostics
// ============================================================================

/**
 * Get compression statistics.
 */
anigma_status_t anigma_compression_capsule_get_stats(
    anigma_compression_capsule_t handle,
    struct anigma_compression_stats_t* out_stats,
    anigma_capsule_error_t* err
);

/**
 * Reset statistics counters.
 */
anigma_status_t anigma_compression_capsule_reset_stats(
    anigma_compression_capsule_t handle,
    anigma_capsule_error_t* err
);

/**
 * Estimate decompressed size from compressed data.
 */
anigma_status_t anigma_compression_capsule_estimate_decompressed_size(
    const uint8_t* compressed_data,
    size_t compressed_size,
    size_t* out_estimate,
    anigma_capsule_error_t* err
);

// ============================================================================
// Configuration and Utility Functions
// ============================================================================

/**
 * Get default configuration for given algorithm.
 */
struct anigma_compression_config_t anigma_compression_capsule_get_default_config(
    enum anigma_compression_algorithm_t algorithm
);

/**
 * Validate configuration parameters.
 */
anigma_status_t anigma_compression_capsule_validate_config(
    const struct anigma_compression_config_t* config,
    anigma_capsule_error_t* err
);

/**
 * Get algorithm name as string.
 */
const char* anigma_compression_capsule_get_algorithm_name(
    enum anigma_compression_algorithm_t algorithm
);

/**
 * Check if algorithm supports streaming.
 */
uint8_t anigma_compression_capsule_supports_streaming(
    enum anigma_compression_algorithm_t algorithm
);

/**
 * Check if algorithm supports dictionary training.
 */
uint8_t anigma_compression_capsule_supports_dictionary(
    enum anigma_compression_algorithm_t algorithm
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_COMPRESSION_CAPSULE_H
```

## 4. Swift Wrapper Interface

### 4.1 Swift Actor Wrapper (`CompressionCapsuleWrapper.swift`)

```swift
import Foundation
import AnigmaNativeShims
import CapsuleCore

public actor CompressionCapsuleWrapper {
    public static var identity: anigma_capsule_identity_t {
        anigma_compression_capsule_get_identity()
    }
    
    private var handle: CapsuleHandle<AnyObject>?
    private let config: CompressionConfig
    private var currentDictionary: CompressionDictionary?
    
    public enum Algorithm: UInt32 {
        case zstd = 0
        case brotli = 1
        case lz4 = 2
        case deflate = 3
        case gzip = 4
    }
    
    public enum Level: UInt32 {
        case fastest = 0
        case `default` = 1
        case best = 2
        case custom = 3
    }
    
    public struct CompressionConfig: Sendable {
        public var algorithm: Algorithm
        public var level: Level
        public var customLevel: UInt32
        public var determinismTier: UInt32
        public var useDictionary: Bool
        public var streaming: Bool
        public var windowSize: UInt32
        public var dictionarySize: UInt32
        public var maxMemoryMB: UInt32
        public var bufferPoolSize: UInt32
        
        public static func `default`(for algorithm: Algorithm) -> CompressionConfig {
            let cConfig = anigma_compression_capsule_get_default_config(
                anigma_compression_algorithm_t(rawValue: algorithm.rawValue)
            )
            return CompressionConfig(from: cConfig)
        }
        
        // Conversion methods to/from C struct
    }
    
    public init(config: CompressionConfig) throws {
        var rawHandle: anigma_compression_capsule_t?
        var error = anigma_capsule_error_t()
        
        var cConfig = config.toCStruct()
        let status = anigma_compression_capsule_create(&cConfig, &rawHandle, &error)
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: anigma_compression_capsule_destroy
        )
        self.config = config
    }
    
    deinit {
        handle?.invalidate()
    }
    
    // MARK: - One-Shot Operations
    
    public func compress(_ data: Data) throws -> Data {
        var outputSize: size_t = 0
        var error = anigma_capsule_error_t()
        
        // Phase 1: Get required size
        let queryStatus = data.withUnsafeBytes { inputBytes in
            anigma_compression_capsule_compress(
                try handle!.rawHandle,
                inputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                0,
                &outputSize,
                &error
            )
        }
        
        guard queryStatus == ANIGMA_ERR_BUFFER_TOO_SMALL else {
            throw CapsuleError(status: queryStatus, error: error)
        }
        
        // Phase 2: Allocate and compress
        var outputData = Data(count: outputSize)
        let compressStatus = data.withUnsafeBytes { inputBytes in
            outputData.withUnsafeMutableBytes { outputBytes in
                anigma_compression_capsule_compress(
                    try handle!.rawHandle,
                    inputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    outputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    outputSize,
                    &outputSize,
                    &error
                )
            }
        }
        
        guard compressStatus == ANIGMA_OK else {
            throw CapsuleError(status: compressStatus, error: error)
        }
        
        outputData.count = outputSize
        return outputData
    }
    
    public func decompress(_ data: Data) throws -> Data {
        var outputSize: size_t = 0
        var error = anigma_capsule_error_t()
        
        // Phase 1: Get required size (estimate)
        let queryStatus = data.withUnsafeBytes { inputBytes in
            anigma_compression_capsule_decompress(
                try handle!.rawHandle,
                inputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                0,
                &outputSize,
                &error
            )
        }
        
        guard queryStatus == ANIGMA_ERR_BUFFER_TOO_SMALL else {
            throw CapsuleError(status: queryStatus, error: error)
        }
        
        // Phase 2: Allocate and decompress
        var outputData = Data(count: outputSize)
        let decompressStatus = data.withUnsafeBytes { inputBytes in
            outputData.withUnsafeMutableBytes { outputBytes in
                anigma_compression_capsule_decompress(
                    try handle!.rawHandle,
                    inputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    outputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    outputSize,
                    &outputSize,
                    &error
                )
            }
        }
        
        guard decompressStatus == ANIGMA_OK else {
            throw CapsuleError(status: decompressStatus, error: error)
        }
        
        outputData.count = outputSize
        return outputData
    }
    
    // MARK: - Streaming Operations
    
    public func createStream() throws -> CompressionStream {
        var streamHandle: anigma_compression_stream_handle_t?
        var error = anigma_capsule_error_t()
        
        let status = anigma_compression_capsule_stream_create(
            try handle!.rawHandle,
            &streamHandle,
            &error
        )
        guard status == ANIGMA_OK, let streamHandle = streamHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        return CompressionStream(handle: streamHandle, capsule: self)
    }
    
    // MARK: - Dictionary Management
    
    public func trainDictionary(from samples: [Data]) throws -> CompressionDictionary {
        // Implementation for dictionary training
        fatalError("Not yet implemented")
    }
    
    // Additional methods for buffer pooling, statistics, etc.
}

public class CompressionStream {
    private let handle: anigma_compression_stream_handle_t
    private weak var capsule: CompressionCapsuleWrapper?
    
    fileprivate init(handle: anigma_compression_stream_handle_t, capsule: CompressionCapsuleWrapper) {
        self.handle = handle
        self.capsule = capsule
    }
    
    deinit {
        // Destroy stream when wrapper deinits
    }
    
    public func process(_ input: Data, flush: Bool = false) throws -> Data {
        // Streaming compression/decompression implementation
        fatalError("Not yet implemented")
    }
    
    public func finish() throws -> Data {
        // Finish streaming operation
        fatalError("Not yet implemented")
    }
}

public class CompressionDictionary {
    private let handle: anigma_compression_dict_handle_t
    
    fileprivate init(handle: anigma_compression_dict_handle_t) {
        self.handle = handle
    }
    
    deinit {
        // Destroy dictionary
    }
    
    public func save() throws -> Data {
        // Save dictionary to data
        fatalError("Not yet implemented")
    }
}
```

## 5. Performance Requirements

| Algorithm | Compression Speed (MB/s) | Decompression Speed (MB/s) | Ratio (typical) |
|-----------|-------------------------|----------------------------|-----------------|
| **zstd** (level 3) | 300 MB/s | 600 MB/s | 2.8:1 |
| **zstd** (level 15) | 50 MB/s | 400 MB/s | 3.5:1 |
| **brotli** (quality 4) | 150 MB/s | 300 MB/s | 3.0:1 |
| **brotli** (quality 11) | 10 MB/s | 200 MB/s | 4.0:1 |
| **lz4** | 500 MB/s | 2000 MB/s | 2.1:1 |
| **deflate** (level 6) | 100 MB/s | 200 MB/s | 2.5:1 |

**Speedup target**: 2–5× vs. current Swift‑only mock implementation.

**Memory target**: < 100 MB working memory for typical operations.

## 6. Determinism Requirements

**Tier 1 (Receipt‑grade)**: For canonical compression mode (fixed parameters, no runtime optimizations):
- Bitwise identical compressed output for same input
- Across different runs, machines, operating systems
- With same library versions (zstd ≥ 1.5, brotli ≥ 1.0)

**Tier 2 (Performance‑optimized)**: For high‑performance compression:
- Epsilon‑stable (minor differences in compression ratio acceptable)
- Runtime optimizations allowed (adaptive compression, heuristics)

**Validation procedure**:
1. Golden corpus of diverse data types (text, binary, structured data)
2. Hash verification for Tier 1 mode
3. Ratio verification for Tier 2 mode (within 1% tolerance)
4. Round‑trip verification (compress → decompress → compare)

## 7. Integration Example

```swift
// Example: High‑performance compression for artifact storage
let config = CompressionConfig(
    algorithm: .zstd,
    level: .default,
    determinismTier: ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE,
    streaming: false
)

let capsule = try CompressionCapsuleWrapper(config: config)

// One-shot compression
let originalData = try Data(contentsOf: largeFileURL)
let compressed = try capsule.compress(originalData)
print("Compressed \(originalData.count) → \(compressed.count) bytes (\(Double(originalData.count)/Double(compressed.count)):1)")

// Save with metadata
let artifact = Artifact(
    id: UUID(),
    data: compressed,
    metadata: [
        "compression": "zstd",
        "original_size": "\(originalData.count)",
        "compression_ratio": String(format: "%.2f", Double(originalData.count)/Double(compressed.count))
    ]
)

// Later decompression
let decompressed = try capsule.decompress(artifact.data)
assert(decompressed == originalData)

// Streaming example for logs
let stream = try capsule.createStream()
var logBuffer = Data()
for logEntry in continuousLogStream {
    let compressedChunk = try stream.process(logEntry.data)
    logBuffer.append(compressedChunk)
    
    if logBuffer.count > 1_000_000 {
        try persistLogBuffer(logBuffer)
        logBuffer.removeAll()
    }
}
let finalChunk = try stream.finish()
logBuffer.append(finalChunk)
```

## 8. Integration Points

1. **CompressionKit**: Replace `NativeCompressor` with capsule‑based implementation
2. **Receipt serialization**: Use Tier 1 deterministic compression for receipt generation
3. **Artifact storage**: Compress artifacts before storage (configurable algorithm)
4. **Network transport**: Compress RPC payloads (especially for large embeddings)
5. **Database storage**: Compress large BLOB columns in SQLite

## 9. Risk Mitigation

1. **Fallback implementation**: Keep Swift‑only implementation as fallback
2. **Feature detection**: Check for library availability at runtime
3. **Graceful degradation**: If dictionary training fails, fall back to standard compression
4. **Memory limits**: Enforce configurable memory bounds
5. **Corruption detection**: Validate compressed data integrity

## 10. Implementation Timeline

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Specification & library integration | 1 week | This document, build system updates |
| zstd integration | 1 week | Core zstd support, one‑shot API |
| brotli integration | 1 week | Brotli support, streaming API |
| lz4 integration | 1 week | Lz4 support, buffer pooling |
| Dictionary training | 1 week | Dictionary creation/management |
| Swift wrapper & tests | 1 week | Swift actor, integration tests |
| Performance optimization | 1 week | Benchmarking, memory optimization |
| Integration & deployment | 1 week | Feature flags, fallback mechanisms |

**Total**: 8 weeks (2 months)

---

*This specification provides the complete design for CompressionCapsule. Next step: review and begin implementation.*