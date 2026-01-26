# CapsuleCore Error Handling Guide

## Overview

`CapsuleError` is the canonical error type for all Anigma capsules. Every capsule MUST use this unified type for consistent error handling across the ecosystem.

This guide explains the canonical error cases and how to properly integrate `CapsuleError` into your capsule.

## Canonical Error Cases

### `.invalidConfiguration(reason: String)`
Use when configuration validation fails before an operation begins.
- **Example:** `throw .invalidConfiguration(reason: "timeout must be positive")`

### `.operationFailed(code: UInt32, message: String, context: [String: String])`
Use for runtime failures that leave the system in a recoverable state.
- **Example:** `throw .operationFailed(code: 500, message: "Upload failed", context: ["job_id": "123"])`

### `.resourceExhausted(resource: String, limit: String)`
Use when memory, file handles, connections, or disk space are exhausted.
- **Example:** `throw .resourceExhausted(resource: "memory", limit: "1GB")`

### `.invalidInput(field: String, constraint: String)`
Use when input data format or constraints are violated.
- **Example:** `throw .invalidInput(field: "email", constraint: "must contain @")`

### `.nativeError(code: Int32, libraryName: String)`
Use when an underlying C/C++ library returns an error.
- **Example:** `throw .nativeError(code: -1, libraryName: "libffmpeg")`

### `.timeout(operation: String, deadline: TimeInterval)`
Use when an operation or deadline is exceeded.
- **Example:** `throw .timeout(operation: "image_processing", deadline: 30.0)`

### `.internalError(details: String)`
Use only for bugs, assertion failures, or invariant violations.
- **Example:** `throw .internalError(details: "null pointer in critical section")`

## Integration Patterns

### C Bridge Mapping
Use `capsuleErrorToC` and `capsuleErrorFromC` for bidirectional mapping between Swift and C-compatible structures.

### Serialization
`CapsuleError` conforms to `Codable`. Use `jsonString` for structured logging in daemon logs.

```swift
do {
    try capsule.process()
} catch let error as CapsuleError {
    print(error.jsonString ?? "Unknown error")
}
```
