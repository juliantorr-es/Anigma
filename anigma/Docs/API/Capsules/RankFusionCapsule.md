# Rank Fusion Capsule API Reference

**Header**: `anigma_rank_fusion_capsule.h`  
**Determinism Tier**: Tier 1 (bitwise identical across runs)  
**Thread Safety**: Thread-safe for concurrent operations with distinct handles

## Overview

The Rank Fusion Capsule implements reciprocal rank fusion (RRF) for combining multiple ranked lists into a single consensus ranking. It is used in search and retrieval systems to merge results from different ranking algorithms or sources. The capsule supports standard RRF with configurable k parameter and top-K result extraction.

## Types

### Opaque Handle
```c
typedef anigma_capsule_handle_t anigma_rank_fusion_capsule_t;
```

## Core Functions

### `anigma_rank_fusion_capsule_get_identity`
```c
anigma_capsule_identity_t anigma_rank_fusion_capsule_get_identity(void);
```
Returns capsule identity information.

### `anigma_rank_fusion_capsule_create`
```c
anigma_status_t anigma_rank_fusion_capsule_create(
    anigma_rank_fusion_capsule_t* out_handle,
    anigma_capsule_error_t* err
);
```
Creates a rank fusion capsule handle.

### `anigma_rank_fusion_capsule_destroy`
```c
anigma_status_t anigma_rank_fusion_capsule_destroy(
    anigma_rank_fusion_capsule_t handle,
    anigma_capsule_error_t* err
);
```
Destroys a rank fusion capsule handle.

## Rank Fusion Operations

### `anigma_rank_fusion_capsule_add_rank_list`
```c
anigma_status_t anigma_rank_fusion_capsule_add_rank_list(
    anigma_rank_fusion_capsule_t handle,
    const uint64_t* ids,
    const uint32_t* ranks,
    size_t count,
    anigma_capsule_error_t* err
);
```
Adds a rank list to the fusion context.

**Parameters**:
- `handle`: Capsule handle
- `ids`: Array of chunk IDs (64-bit integers)
- `ranks`: Array of ranks (0-based positions)
- `count`: Number of items in arrays
- `err`: Error output

**Note**: Each rank list should contain unique IDs. Duplicate IDs within the same list are not allowed.

### `anigma_rank_fusion_capsule_fuse`
```c
anigma_status_t anigma_rank_fusion_capsule_fuse(
    anigma_rank_fusion_capsule_t handle,
    uint32_t k,
    double* out_scores,
    uint64_t* out_ids,
    size_t max_results,
    anigma_capsule_error_t* err
);
```
Performs reciprocal rank fusion (RRF) with k=60 parameter.

**Parameters**:
- `handle`: Capsule handle
- `k`: RRF constant (typically 60)
- `out_scores`: Buffer for output scores (caller-allocated)
- `out_ids`: Buffer for output IDs (caller-allocated)
- `max_results`: Maximum number of results to return
- `err`: Error output

**RRF Formula**: `score = Σ (1 / (k + rank))` across all rank lists where the ID appears.

The results are sorted by descending score. The number of results returned is the minimum of `max_results` and the number of unique IDs across all rank lists.

### `anigma_rank_fusion_capsule_fuse_top_k`
```c
anigma_status_t anigma_rank_fusion_capsule_fuse_top_k(
    anigma_rank_fusion_capsule_t handle,
    uint32_t k,
    size_t top_k,
    double* out_scores,
    uint64_t* out_ids,
    anigma_capsule_error_t* err
);
```
Performs reciprocal rank fusion and gets top-K results. This is a convenience function that combines fusion and top-K selection.

**Parameters**:
- `handle`: Capsule handle
- `k`: RRF constant (typically 60)
- `top_k`: Number of top results to return
- `out_scores`: Buffer for output scores (caller-allocated)
- `out_ids`: Buffer for output IDs (caller-allocated)
- `err`: Error output

### `anigma_rank_fusion_capsule_clear`
```c
anigma_status_t anigma_rank_fusion_capsule_clear(
    anigma_rank_fusion_capsule_t handle,
    anigma_capsule_error_t* err
);
```
Clears all rank lists from the fusion context, allowing reuse of the same handle for new data.

### `anigma_rank_fusion_capsule_get_unique_count`
```c
anigma_status_t anigma_rank_fusion_capsule_get_unique_count(
    anigma_rank_fusion_capsule_t handle,
    size_t* out_count,
    anigma_capsule_error_t* err
);
```
Gets the number of unique IDs across all rank lists. Useful for buffer allocation before calling `fuse`.

## Error Handling

All functions return `anigma_status_t` with `ANIGMA_OK` (0) on success. Common error codes:

- `ANIGMA_ERR_INVALID_ARG`: Invalid argument (e.g., null handle, mismatched array sizes)
- `ANIGMA_ERR_BUFFER_TOO_SMALL`: Output buffer too small (required size in `aux`)
- `ANIGMA_ERR_INTERNAL`: Internal capsule error

## Swift Usage Example

```swift
import AnigmaNativeShims
import CapsuleCore

// Create rank fusion capsule
func createRankFusionCapsule() throws -> CapsuleHandle<AnyObject> {
    var handle: anigma_rank_fusion_capsule_t?
    var error = anigma_capsule_error_t()
    
    let status = anigma_rank_fusion_capsule_create(&handle, &error)
    guard status == ANIGMA_OK, let handle = handle else {
        throw CapsuleError(status: status, error: error)
    }
    
    return CapsuleHandle<AnyObject>(
        rawHandle: handle,
        destroyFunction: anigma_rank_fusion_capsule_destroy
    )
}

// Add rank lists and perform fusion
func fuseRankLists(_ capsule: CapsuleHandle<AnyObject>, rankLists: [[UInt64]]) throws -> [(id: UInt64, score: Double)] {
    var error = anigma_capsule_error_t()
    
    // Clear any previous data
    let clearStatus = anigma_rank_fusion_capsule_clear(try capsule.rawHandle, &error)
    guard clearStatus == ANIGMA_OK else {
        throw CapsuleError(status: clearStatus, error: error)
    }
    
    // Add each rank list
    for rankList in rankLists {
        let ids = rankList
        var ranks = [UInt32](0..<UInt32(rankList.count))
        
        let addStatus = ids.withUnsafeBufferPointer { idsBuffer in
            ranks.withUnsafeBufferPointer { ranksBuffer in
                anigma_rank_fusion_capsule_add_rank_list(
                    try capsule.rawHandle,
                    idsBuffer.baseAddress,
                    ranksBuffer.baseAddress,
                    idsBuffer.count,
                    &error
                )
            }
        }
        
        guard addStatus == ANIGMA_OK else {
            throw CapsuleError(status: addStatus, error: error)
        }
    }
    
    // Get unique count for buffer allocation
    var uniqueCount: size_t = 0
    let countStatus = anigma_rank_fusion_capsule_get_unique_count(
        try capsule.rawHandle,
        &uniqueCount,
        &error
    )
    guard countStatus == ANIGMA_OK else {
        throw CapsuleError(status: countStatus, error: error)
    }
    
    // Perform fusion
    var scores = [Double](repeating: 0.0, count: uniqueCount)
    var ids = [UInt64](repeating: 0, count: uniqueCount)
    
    let fuseStatus = anigma_rank_fusion_capsule_fuse(
        try capsule.rawHandle,
        60, // RRF constant
        &scores,
        &ids,
        uniqueCount,
        &error
    )
    
    guard fuseStatus == ANIGMA_OK else {
        throw CapsuleError(status: fuseStatus, error: error)
    }
    
    // Combine results
    return zip(ids, scores).map { (id: $0, score: $1) }
}

// Convenience function for top-K fusion
func fuseTopK(_ capsule: CapsuleHandle<AnyObject>, rankLists: [[UInt64]], topK: Int) throws -> [(id: UInt64, score: Double)] {
    var error = anigma_capsule_error_t()
    
    // Clear and add rank lists (same as above)
    // ...
    
    var scores = [Double](repeating: 0.0, count: topK)
    var ids = [UInt64](repeating: 0, count: topK)
    
    let fuseStatus = anigma_rank_fusion_capsule_fuse_top_k(
        try capsule.rawHandle,
        60,
        topK,
        &scores,
        &ids,
        &error
    )
    
    guard fuseStatus == ANIGMA_OK else {
        throw CapsuleError(status: fuseStatus, error: error)
    }
    
    return zip(ids, scores).map { (id: $0, score: $1) }
}
```