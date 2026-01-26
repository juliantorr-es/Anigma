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

## How to Test Your Errors

`CapsuleCore` provides consistent error assertion utilities to verify both the error case and associated metadata.

### `XCTAssertCapsuleError`

Use this assertion in your tests to verify that a block or value matches an expected `CapsuleError` case.

```swift
import CapsuleCore

func testMyCapsule() {
    // Assert on a thrown error
    XCTAssertCapsuleError(
        try myCapsule.performAction(),
        matches: .invalidInput,
        message: "email"
    )
    
    // Assert on a returned error
    let result = myCapsule.process()
    if case .failure(let error) = result {
        XCTAssertCapsuleError(
            error, 
            matches: .operationFailed, 
            underlyingCode: 404
        )
    }
}
```

- **`matches`**: The `CapsuleErrorCode` case expected.
- **`message`**: (Optional) Substring expected in the error message.
- **`underlyingCode`**: (Optional) For `.operationFailed` and `.nativeError`, verifies the internal code.
