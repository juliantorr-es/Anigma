# [Capsule Name] Capsule Specification

## 1. Overview

*Brief description of the capsule’s purpose, what problem it solves, and how it fits into the “Swift governs, C++ computes” architecture.*

## 2. Determinism Tier

- **Tier 1 (Bitwise Identical)**: Required for evidence, hashing, and receipts.  
- **Tier 2 (Epsilon‑Stable)**: Allowed for vector/layout operations where floating‑point differences are acceptable within a defined epsilon.

*This capsule is **Tier 1** / **Tier 2**.*

## 3. Performance Budgets

| Budget | Limit | Rationale |
|--------|-------|-----------|
| Max ABI calls per operation | 2 | Minimize marshalling overhead |
| Max string conversions | 0 | Zero‑copy marshalling only |
| Max bytes copied | 1 MiB | Large operations must use streaming |
| Max buffer allocations | 1 | Buffer pooling required |

## 4. C API (Header Draft)

```c
#ifndef ANIGMA_[NAME]_CAPSULE_H
#define ANIGMA_[NAME]_CAPSULE_H

#include "anigma_capsule_core.h"

#if defined(__cplusplus)
extern "C" {
#endif

// ============================================================================
// [Name] Capsule Types
// ============================================================================

typedef anigma_capsule_handle_t anigma_[name]_capsule_t;

// Optional: enumerations, structures specific to this capsule
typedef enum {
    ANIGMA_[NAME]_OP_FOO = 0,
    ANIGMA_[NAME]_OP_BAR = 1
} anigma_[name]_op_t;

// ============================================================================
// Core Capsule Functions
// ============================================================================

/**
 * Get capsule identity.
 */
anigma_capsule_identity_t anigma_[name]_capsule_get_identity(void);

/**
 * Create a capsule handle.
 */
anigma_status_t anigma_[name]_capsule_create(
    anigma_[name]_capsule_t* out_handle,
    anigma_capsule_error_t* err
);

/**
 * Destroy a capsule handle.
 */
anigma_status_t anigma_[name]_capsule_destroy(
    anigma_[name]_capsule_t handle,
    anigma_capsule_error_t* err
);

// ============================================================================
// Primary Operations
// ============================================================================

/**
 * Perform [operation] on input data.
 * Uses two‑phase buffer filling: call with NULL output buffer to get required size,
 * then call again with allocated buffer.
 */
anigma_status_t anigma_[name]_capsule_operation(
    anigma_[name]_capsule_t handle,
    const anigma_capsule_buffer_t* input,
    anigma_capsule_buffer_t* output,
    anigma_capsule_error_t* err
);

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Query resource usage (optional).
 */
anigma_status_t anigma_[name]_capsule_get_stats(
    anigma_[name]_capsule_t handle,
    anigma_capsule_telemetry_t* out_stats,
    anigma_capsule_error_t* err
);

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_[NAME]_CAPSULE_H
```

## 5. Swift Wrapper Interface

```swift
import AnigmaNativeShims
import CapsuleCore

public actor [Name]Capsule: CapsuleProtocol {
    public typealias HandleType = AnyObject

    public static var identity: anigma_capsule_identity_t {
        anigma_[name]_capsule_get_identity()
    }

    public static func createHandle() throws -> CapsuleHandle<HandleType> {
        var handle: anigma_[name]_capsule_t?
        var error = anigma_capsule_error_t()
        let status = anigma_[name]_capsule_create(&handle, &error)
        guard status == ANIGMA_OK, let rawHandle = handle else {
            throw CapsuleError(status: status, error: error)
        }
        return CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: anigma_[name]_capsule_destroy
        )
    }

    private let handle: CapsuleHandle<AnyObject>

    public init() throws {
        self.handle = try Self.createHandle()
    }

    public func operation(input: Data) throws -> Data {
        try handle.withHandle { rawHandle in
            // Prepare input buffer
            let inputBuffer = anigma_capsule_buffer_t(
                ptr: UnsafeMutablePointer<UInt8>(mutating: input.withUnsafeBytes { $0.baseAddress }),
                len: input.count,
                cap: input.count
            )
            // Phase 1: query size
            var error = anigma_capsule_error_t()
            let status = anigma_[name]_capsule_operation(rawHandle, &inputBuffer, nil, &error)
            guard status == ANIGMA_ERR_BUFFER_TOO_SMALL else {
                throw CapsuleError(status: status, error: error)
            }
            let requiredSize = error.aux
            // Phase 2: allocate and fill
            var outputData = Data(count: requiredSize)
            let outputBuffer = anigma_capsule_buffer_t(
                ptr: outputData.withUnsafeMutableBytes { $0.baseAddress },
                len: 0,
                cap: requiredSize
            )
            let finalStatus = anigma_[name]_capsule_operation(rawHandle, &inputBuffer, &outputBuffer, &error)
            guard finalStatus == ANIGMA_OK else {
                throw CapsuleError(status: finalStatus, error: error)
            }
            outputData.count = outputBuffer.len
            return outputData
        }
    }
}
```

## 6. Integration Points

*List the Swift modules and workflows where this capsule will be integrated.*

- **Module A**: Description of integration (e.g., replace existing Swift implementation).
- **Module B**: New functionality enabled by the capsule.

## 7. Testing Strategy

### 7.1 Unit Tests

- Golden‑corpus tests for Tier 1 determinism (bitwise identical outputs).
- Edge‑case validation (empty input, maximum size, malformed data).
- Memory‑safety tests (ASAN, UBSAN).

### 7.2 Performance Benchmarks

- Compare capsule vs. existing Swift implementation on representative workloads.
- Measure marshalling overhead (ABI calls, buffer allocations).
- Validate against performance budgets.

### 7.3 Integration Tests

- End‑to‑end workflow using the capsule in a real scenario (e.g., indexing a PDF).
- Verify fallback behavior when capsule is unavailable (conditional compilation).

## 8. Dependencies

| Dependency | Version | License | Integration Method |
|------------|---------|---------|-------------------|
| Library X | ≥ 1.0 | MIT | System library (apt/brew) |
| Library Y | ≥ 2.5 | BSD | Vendored source |

## 9. Open Issues

- [ ] Issue 1: Need to decide on XYZ algorithm parameter.
- [ ] Issue 2: Dependency version locking for determinism.
- [ ] Issue 3: Fallback implementation strategy.

## 10. Revision History

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| YYYY‑MM‑DD | 1.0 | Initial specification | Name |

---

*This document is a template. Replace bracketed items (`[Name]`, `[name]`, `[NAME]`) with the actual capsule name.*