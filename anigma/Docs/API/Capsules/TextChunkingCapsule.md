# Text Chunking Capsule API Reference

**Header**: `anigma_text_chunking_capsule.h`  
**Determinism Tier**: Tier 1 (bitwise identical across runs)  
**Thread Safety**: Thread-safe for concurrent operations with distinct handles

## Overview

The Text Chunking Capsule performs content‑defined chunking using Rabin fingerprinting to split text into variable‑sized chunks with deterministic boundaries. It supports both streaming API for large documents and one‑shot operations for small buffers. The capsule is designed for text deduplication, version control, and incremental processing.

## Types

### Opaque Handle
```c
typedef anigma_capsule_handle_t anigma_text_chunking_capsule_t;
```

### Configuration Structure
```c
struct anigma_text_chunking_config_t {
    size_t target_chunk_size;   // Target chunk size in bytes (e.g., 512-4096)
    size_t min_chunk_size;      // Minimum allowed chunk size
    size_t max_chunk_size;      // Maximum allowed chunk size  
    size_t window_size;         // Rabin sliding window size (e.g., 48)
    uint64_t polynomial;        // Irreducible polynomial for Rabin fingerprinting
    uint32_t determinism_tier;  // ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
};
```

### Chunk Boundary Information
```c
struct anigma_chunk_boundary_t {
    uint64_t offset;           // Start offset in bytes
    uint64_t length;           // Length in bytes
};
```

## Core Functions

### `anigma_text_chunking_capsule_get_identity`
```c
anigma_capsule_identity_t anigma_text_chunking_capsule_get_identity(void);
```
Returns capsule identity information.

### `anigma_text_chunking_capsule_create`
```c
anigma_status_t anigma_text_chunking_capsule_create(
    const struct anigma_text_chunking_config_t* config,
    anigma_text_chunking_capsule_t* out_handle,
    anigma_capsule_error_t* err
);
```
Creates a text chunking capsule context with given configuration.

### `anigma_text_chunking_capsule_destroy`
```c
anigma_status_t anigma_text_chunking_capsule_destroy(
    anigma_text_chunking_capsule_t handle,
    anigma_capsule_error_t* err
);
```
Destroys a text chunking capsule context.

## Streaming API

### `anigma_text_chunking_capsule_process_bytes`
```c
anigma_status_t anigma_text_chunking_capsule_process_bytes(
    anigma_text_chunking_capsule_t handle,
    const uint8_t* data,
    size_t data_len,
    anigma_capsule_error_t* err
);
```
Processes bytes through the chunking capsule. This is a streaming operation that maintains internal state.

**Parameters**:
- `handle`: Capsule handle
- `data`: Input data bytes
- `data_len`: Length of input data
- `err`: Error output

**Returns**: `ANIGMA_OK` on success.

### `anigma_text_chunking_capsule_finalize`
```c
anigma_status_t anigma_text_chunking_capsule_finalize(
    anigma_text_chunking_capsule_t handle,
    anigma_capsule_error_t* err
);
```
Finalizes chunking and computes remaining boundaries. Must be called after all input data has been processed.

### `anigma_text_chunking_capsule_reset`
```c
anigma_status_t anigma_text_chunking_capsule_reset(
    anigma_text_chunking_capsule_t handle,
    anigma_capsule_error_t* err
);
```
Resets the chunking capsule state, allowing reuse of the same handle for new input.

## Boundary Retrieval (Two-Phase Buffer Fill)

### `anigma_text_chunking_capsule_get_boundary_count`
```c
anigma_status_t anigma_text_chunking_capsule_get_boundary_count(
    anigma_text_chunking_capsule_t handle,
    size_t* out_count,
    anigma_capsule_error_t* err
);
```
Gets the number of chunk boundaries detected so far.

### `anigma_text_chunking_capsule_get_boundaries`
```c
anigma_status_t anigma_text_chunking_capsule_get_boundaries(
    anigma_text_chunking_capsule_t handle,
    uint64_t* out_offsets,
    size_t max_offsets,
    size_t* out_actual,
    anigma_capsule_error_t* err
);
```
Gets chunk boundaries (offsets within the processed data). Uses two‑phase buffer fill pattern.

**Two‑phase pattern**:
1. Phase 1: Call with `out_offsets = NULL` to get required size (in `err->aux`)
2. Phase 2: Allocate buffer and call again

**Parameters**:
- `handle`: Capsule handle
- `out_offsets`: Output array of start offsets (caller‑allocated)
- `max_offsets`: Maximum number of offsets that can be stored
- `out_actual`: Actual number of offsets written
- `err`: Error output

**Returns**: `ANIGMA_OK` on success, `ANIGMA_ERR_BUFFER_TOO_SMALL` if buffer too small.

### `anigma_text_chunking_capsule_get_chunk_info`
```c
anigma_status_t anigma_text_chunking_capsule_get_chunk_info(
    anigma_text_chunking_capsule_t handle,
    struct anigma_chunk_boundary_t* out_boundaries,
    size_t max_boundaries,
    size_t* out_actual,
    anigma_capsule_error_t* err
);
```
Gets complete chunk information (offsets and lengths). Similar two‑phase pattern as `get_boundaries`.

## One-Shot Convenience Functions

### `anigma_text_chunking_capsule_chunk_buffer`
```c
anigma_status_t anigma_text_chunking_capsule_chunk_buffer(
    const struct anigma_text_chunking_config_t* config,
    const anigma_capsule_buffer_t* input,
    uint64_t* out_offsets,
    size_t max_offsets,
    size_t* out_actual,
    anigma_capsule_error_t* err
);
```
One‑shot chunking of a complete buffer. Convenience function for small buffers that don't need streaming.

**Parameters**:
- `config`: Configuration (can be NULL for defaults)
- `input`: Input buffer descriptor
- `out_offsets`: Output array of offsets (caller‑allocated)
- `max_offsets`: Maximum number of offsets that can be stored
- `out_actual`: Actual number of offsets written
- `err`: Error output

## Configuration and Utility Functions

### `anigma_text_chunking_capsule_get_default_config`
```c
struct anigma_text_chunking_config_t anigma_text_chunking_capsule_get_default_config(void);
```
Gets default configuration. Returns recommended defaults for typical text chunking.

### `anigma_text_chunking_capsule_validate_config`
```c
anigma_status_t anigma_text_chunking_capsule_validate_config(
    const struct anigma_text_chunking_config_t* config,
    anigma_capsule_error_t* err
);
```
Validates configuration parameters. Returns `ANIGMA_OK` if configuration is valid.

## Error Handling

All functions return `anigma_status_t` with `ANIGMA_OK` (0) on success. Common error codes:

- `ANIGMA_ERR_INVALID_ARG`: Invalid argument (e.g., null handle, invalid configuration)
- `ANIGMA_ERR_BUFFER_TOO_SMALL`: Output buffer too small (required size in `aux`)
- `ANIGMA_ERR_INTERNAL`: Internal capsule error

## Swift Usage Example

```swift
import AnigmaNativeShims
import CapsuleCore

// Create text chunking capsule with default configuration
func createChunkingCapsule() throws -> CapsuleHandle<AnyObject> {
    let config = anigma_text_chunking_capsule_get_default_config()
    
    var handle: anigma_text_chunking_capsule_t?
    var error = anigma_capsule_error_t()
    
    let status = anigma_text_chunking_capsule_create(&config, &handle, &error)
    guard status == ANIGMA_OK, let handle = handle else {
        throw CapsuleError(status: status, error: error)
    }
    
    return CapsuleHandle<AnyObject>(
        rawHandle: handle,
        destroyFunction: anigma_text_chunking_capsule_destroy
    )
}

// Stream chunking for large document
func chunkLargeDocument(_ capsule: CapsuleHandle<AnyObject>, documentURL: URL) throws -> [Chunk] {
    var error = anigma_capsule_error_t()
    
    // Reset capsule state
    let resetStatus = anigma_text_chunking_capsule_reset(try capsule.rawHandle, &error)
    guard resetStatus == ANIGMA_OK else {
        throw CapsuleError(status: resetStatus, error: error)
    }
    
    let stream = InputStream(url: documentURL)!
    stream.open()
    defer { stream.close() }
    
    let bufferSize = 8192
    var buffer = [UInt8](repeating: 0, count: bufferSize)
    
    while true {
        let bytesRead = stream.read(&buffer, maxLength: bufferSize)
        if bytesRead < 0 {
            throw stream.streamError!
        }
        if bytesRead == 0 {
            break
        }
        
        let processStatus = buffer.withUnsafeBytes { bytes in
            anigma_text_chunking_capsule_process_bytes(
                try capsule.rawHandle,
                bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                bytesRead,
                &error
            )
        }
        
        guard processStatus == ANIGMA_OK else {
            throw CapsuleError(status: processStatus, error: error)
        }
    }
    
    // Finalize
    let finalizeStatus = anigma_text_chunking_capsule_finalize(try capsule.rawHandle, &error)
    guard finalizeStatus == ANIGMA_OK else {
        throw CapsuleError(status: finalizeStatus, error: error)
    }
    
    // Get boundary count
    var boundaryCount: size_t = 0
    let countStatus = anigma_text_chunking_capsule_get_boundary_count(
        try capsule.rawHandle,
        &boundaryCount,
        &error
    )
    guard countStatus == ANIGMA_OK else {
        throw CapsuleError(status: countStatus, error: error)
    }
    
    // Get boundaries
    var offsets = [UInt64](repeating: 0, count: boundaryCount)
    var actual: size_t = 0
    let boundariesStatus = anigma_text_chunking_capsule_get_boundaries(
        try capsule.rawHandle,
        &offsets,
        boundaryCount,
        &actual,
        &error
    )
    
    guard boundariesStatus == ANIGMA_OK else {
        throw CapsuleError(status: boundariesStatus, error: error)
    }
    
    // Convert to chunks
    var chunks: [Chunk] = []
    var prevOffset: UInt64 = 0
    for offset in offsets.prefix(Int(actual)) {
        let length = offset - prevOffset
        chunks.append(Chunk(offset: prevOffset, length: length))
        prevOffset = offset
    }
    
    return chunks
}

// One-shot chunking for small buffer
func chunkBuffer(_ data: Data) throws -> [UInt64] {
    var error = anigma_capsule_error_t()
    
    var inputBuffer = anigma_capsule_buffer_t(
        ptr: UnsafeMutablePointer<UInt8>(mutating: data.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }),
        len: data.count,
        cap: data.count
    )
    
    // Phase 1: Get required size
    var offsets: UnsafeMutablePointer<UInt64>?
    var actual: size_t = 0
    let queryStatus = anigma_text_chunking_capsule_chunk_buffer(
        nil, // default config
        &inputBuffer,
        nil,
        0,
        &actual,
        &error
    )
    
    guard queryStatus == ANIGMA_ERR_BUFFER_TOO_SMALL else {
        throw CapsuleError(status: queryStatus, error: error)
    }
    
    let requiredCount = error.aux
    
    // Phase 2: Perform chunking
    offsets = UnsafeMutablePointer<UInt64>.allocate(capacity: requiredCount)
    defer { offsets?.deallocate() }
    
    let chunkStatus = anigma_text_chunking_capsule_chunk_buffer(
        nil,
        &inputBuffer,
        offsets,
        requiredCount,
        &actual,
        &error
    )
    
    guard chunkStatus == ANIGMA_OK else {
        throw CapsuleError(status: chunkStatus, error: error)
    }
    
    return Array(UnsafeBufferPointer(start: offsets, count: Int(actual)))
}
```