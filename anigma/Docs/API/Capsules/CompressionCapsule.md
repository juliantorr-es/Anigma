# Compression Capsule API Reference

**Header**: `anigma_compression_capsule.h`  
**Determinism Tier**: Tier 1 (bitwise identical across runs) for deterministic mode  
**Thread Safety**: Thread-safe for concurrent operations with distinct handles

## Overview

The Compression Capsule provides high-performance compression and decompression using industry-standard algorithms (zstd, brotli, lz4) with streaming support, dictionary training, and buffer pooling. It supports both deterministic (Tier 1) and optimized (Tier 2) compression modes.

## Types

### Opaque Handle
```c
typedef anigma_capsule_handle_t anigma_compression_capsule_t;
```

### Compression Algorithm
```c
enum anigma_compression_algo_t {
    ANIGMA_COMPRESSION_ALGO_ZSTD = 0,
    ANIGMA_COMPRESSION_ALGO_BROTLI = 1,
    ANIGMA_COMPRESSION_ALGO_LZ4 = 2
};
```

### Compression Mode
```c
enum anigma_compression_mode_t {
    ANIGMA_COMPRESSION_MODE_STREAMING = 0,
    ANIGMA_COMPRESSION_MODE_DETERMINISTIC = 1,  // Tier 1 for receipts (fixed parameters)
    ANIGMA_COMPRESSION_MODE_OPTIMIZED = 2       // Tier 2 for performance
};
```

### Compression Level
```c
enum anigma_compression_level_t {
    ANIGMA_COMPRESSION_LEVEL_DEFAULT = 0,
    ANIGMA_COMPRESSION_LEVEL_FAST = 1,
    ANIGMA_COMPRESSION_LEVEL_BEST = 9
};
```

### Compression Configuration
```c
struct anigma_compression_config_t {
    enum anigma_compression_algo_t algorithm;
    enum anigma_compression_mode_t mode;
    enum anigma_compression_level_t level;
    size_t buffer_pool_size;           // Size of buffer pool (0 = no pooling)
    uint32_t determinism_tier;         // ANIGMA_DETERMINISM_TIER_* value
};
```

### Dictionary Training Configuration
```c
struct anigma_compression_dict_config_t {
    size_t dictionary_size;            // Target dictionary size
    size_t min_sample_size;            // Minimum sample size
    size_t max_sample_size;            // Maximum sample size
    size_t max_samples;                // Maximum number of samples
};
```

## Core Functions

### `anigma_compression_capsule_get_identity`
```c
anigma_capsule_identity_t anigma_compression_capsule_get_identity(void);
```
Returns capsule identity information.

### `anigma_compression_capsule_create`
```c
anigma_status_t anigma_compression_capsule_create(
    const struct anigma_compression_config_t* config,
    anigma_compression_capsule_t* out_handle,
    anigma_capsule_error_t* err
);
```
Creates a compression capsule context with given configuration.

### `anigma_compression_capsule_destroy`
```c
anigma_status_t anigma_compression_capsule_destroy(
    anigma_compression_capsule_t handle,
    anigma_capsule_error_t* err
);
```
Destroys a compression capsule context.

## Compression/Decompression Operations

### `anigma_compression_capsule_compress`
```c
anigma_status_t anigma_compression_capsule_compress(
    anigma_compression_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err
);
```
Compresses data using streaming API with two-phase buffer fill pattern.

**Parameters**:
- `handle`: Capsule handle
- `input`: Input buffer descriptor
- `output`: Output buffer descriptor (caller-allocated with sufficient capacity)
- `err`: Error output

**Returns**: `ANIGMA_OK` on success, `ANIGMA_ERR_BUFFER_TOO_SMALL` if output buffer too small.

### `anigma_compression_capsule_decompress`
```c
anigma_status_t anigma_compression_capsule_decompress(
    anigma_compression_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err
);
```
Decompresses data using streaming API with two-phase buffer fill pattern.

## Streaming API (for Large Files)

### `anigma_compression_capsule_begin_compress_stream`
```c
anigma_status_t anigma_compression_capsule_begin_compress_stream(
    anigma_compression_capsule_t handle,
    anigma_capsule_handle_t* out_stream_handle,
    anigma_capsule_error_t* err
);
```
Begins a streaming compression operation, returning a stream handle for subsequent operations.

### `anigma_compression_capsule_compress_stream`
```c
anigma_status_t anigma_compression_capsule_compress_stream(
    anigma_capsule_handle_t stream_handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    bool flush,
    anigma_capsule_error_t* err
);
```
Continues streaming compression.

**Parameters**:
- `stream_handle`: Stream handle from `begin_compress_stream`
- `input`: Input buffer descriptor (can be partial data)
- `output`: Output buffer descriptor (compressed data if any)
- `flush`: Whether to flush internal buffers
- `err`: Error output

### `anigma_compression_capsule_end_compress_stream`
```c
anigma_status_t anigma_compression_capsule_end_compress_stream(
    anigma_capsule_handle_t stream_handle,
    anigma_capsule_error_t* err
);
```
Ends a streaming compression operation.

### Decompression Streaming Functions
Similar functions exist for decompression streaming: `begin_decompress_stream`, `decompress_stream`, `end_decompress_stream`.

## Dictionary Training

### `anigma_compression_capsule_train_dictionary`
```c
anigma_status_t anigma_compression_capsule_train_dictionary(
    anigma_compression_capsule_t handle,
    const struct anigma_compression_dict_config_t* config,
    const anigma_capsule_buffer_t* samples,
    size_t sample_count,
    anigma_capsule_buffer_t* dictionary,
    anigma_capsule_error_t* err
);
```
Trains a compression dictionary from sample data for domain-specific compression optimization.

### `anigma_compression_capsule_load_dictionary`
```c
anigma_status_t anigma_compression_capsule_load_dictionary(
    anigma_compression_capsule_t handle,
    const anigma_capsule_buffer_t* dictionary,
    anigma_capsule_error_t* err
);
```
Loads a compression dictionary for use with subsequent operations.

## Buffer Pool Management

### `anigma_compression_capsule_acquire_buffer`
```c
anigma_status_t anigma_compression_capsule_acquire_buffer(
    anigma_compression_capsule_t handle,
    size_t size,
    anigma_capsule_buffer_t* buffer,
    anigma_capsule_error_t* err
);
```
Acquires a buffer from the capsule's buffer pool, reducing allocation overhead for repeated operations.

### `anigma_compression_capsule_release_buffer`
```c
anigma_status_t anigma_compression_capsule_release_buffer(
    anigma_compression_capsule_t handle,
    anigma_capsule_buffer_t* buffer,
    anigma_capsule_error_t* err
);
```
Releases a buffer back to the capsule's buffer pool.

## Utility Functions

### `anigma_compression_capsule_get_default_config`
```c
struct anigma_compression_config_t anigma_compression_capsule_get_default_config(
    enum anigma_compression_algo_t algorithm
);
```
Gets default configuration for an algorithm.

### `anigma_compression_capsule_estimate_compressed_size`
```c
anigma_status_t anigma_compression_capsule_estimate_compressed_size(
    anigma_compression_capsule_t handle,
    size_t input_size,
    size_t* out_estimated_size,
    anigma_capsule_error_t* err
);
```
Estimates compressed size for given input, useful for buffer preallocation.

### `anigma_compression_capsule_validate_config`
```c
anigma_status_t anigma_compression_capsule_validate_config(
    const struct anigma_compression_config_t* config,
    anigma_capsule_error_t* err
);
```
Validates configuration parameters.

## Error Handling

All functions return `anigma_status_t` with `ANIGMA_OK` (0) on success. Common error codes:

- `ANIGMA_ERR_INVALID_ARG`: Invalid argument (e.g., null handle)
- `ANIGMA_ERR_BUFFER_TOO_SMALL`: Output buffer too small (required size in `aux`)
- `ANIGMA_ERR_INTERNAL`: Internal capsule error
- `ANIGMA_ERR_NOT_INITIALIZED`: Capsule not properly initialized

## Swift Usage Example

```swift
import AnigmaNativeShims
import CapsuleCore

// Create compression capsule with zstd algorithm
func createZstdCapsule() throws -> CapsuleHandle<AnyObject> {
    var config = anigma_compression_capsule_get_default_config(ANIGMA_COMPRESSION_ALGO_ZSTD)
    config.determinism_tier = ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    
    var handle: anigma_compression_capsule_t?
    var error = anigma_capsule_error_t()
    let status = anigma_compression_capsule_create(&config, &handle, &error)
    guard status == ANIGMA_OK, let handle = handle else {
        throw CapsuleError(status: status, error: error)
    }
    return CapsuleHandle<AnyObject>(
        rawHandle: handle,
        destroyFunction: anigma_compression_capsule_destroy
    )
}

// Compress data
func compressData(_ capsule: CapsuleHandle<AnyObject>, data: Data) throws -> Data {
    var error = anigma_capsule_error_t()
    
    // Phase 1: Get required size
    var inputBuffer = anigma_capsule_buffer_t(
        ptr: UnsafeMutablePointer<UInt8>(mutating: data.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }),
        len: data.count,
        cap: data.count
    )
    var outputBuffer = anigma_capsule_buffer_t(
        ptr: nil,
        len: 0,
        cap: 0
    )
    
    let queryStatus = anigma_compression_capsule_compress(
        try capsule.rawHandle,
        &inputBuffer,
        &outputBuffer,
        &error
    )
    guard queryStatus == ANIGMA_ERR_BUFFER_TOO_SMALL else {
        throw CapsuleError(status: queryStatus, error: error)
    }
    
    let requiredSize = error.aux
    var compressedData = Data(count: requiredSize)
    
    // Phase 2: Compress
    outputBuffer.ptr = compressedData.withUnsafeMutableBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }
    outputBuffer.cap = requiredSize
    
    let compressStatus = anigma_compression_capsule_compress(
        try capsule.rawHandle,
        &inputBuffer,
        &outputBuffer,
        &error
    )
    guard compressStatus == ANIGMA_OK else {
        throw CapsuleError(status: compressStatus, error: error)
    }
    
    compressedData.count = outputBuffer.len
    return compressedData
}
```