# Phase 5 Trace + Error Consistency Report

Scope
- Vertical slice: daemon job pipeline spans emitted in `Sources/anigmad/main.swift`.
- Capsule error consistency: MediaFingerprintCapsule public API error mapping.

Expected span tree (logical)
- Root span: `daemon.job.pipeline` (category: `daemon.job`, tags: `action`).
- Child span: `capsule.<action>` (category: `capsule`, tags: `file`).
- Events: `Capsule execution started` recorded on the capsule span.
- Completion: both spans end with `SpanStatus.ok` on success.

Span capture notes
- TelemetryCore does not model parent/child relationships; span summaries are stored as a flat list on `ExecutionReceipt`.
- The expected logical tree is represented by ordering and naming conventions rather than a parent ID.

Error mapping audit
- MediaFingerprintCapsule public async methods were throwing `MediaFingerprintError` directly, which violates CapsuleError-only boundaries.
- Updated to map all MediaFingerprintError cases to CapsuleError variants and to wrap Codable errors consistently.

Mapping summary
- `nullPointer` -> `.internalError(details: ...)`
- `invalidDimensions` -> `.invalidInput(field: "dimensions", constraint: "invalid image dimensions")`
- `decodeFailed` -> `.invalidInput(field: "imageData", constraint: "decode failed")`
- `memoryAllocation` -> `.resourceExhausted(resource: "memory", limit: "allocation failed")`
- `invalidFormat` -> `.invalidInput(field: "format", constraint: "unsupported format")`
- `bufferTooSmall` -> `.invalidInput(field: "buffer", constraint: "buffer too small")`
- `notImplemented` -> `.operationFailed(code: 0, message: "Feature not implemented", context: native_code)`
- `unknownError(code)` -> `.nativeError(code: code, libraryName: "MediaFingerprintNative")`

Files touched
- `Sources/anigmad/main.swift` (span tree reference).
- `Packages/MediaFingerprintCapsule/Sources/MediaFingerprintCapsule/MediaFingerprintCapsule.swift` (error mapping fixes).
