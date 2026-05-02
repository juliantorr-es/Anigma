# TelemetryCore Diagnostics Schema

This document defines the canonical `DiagnosticEvent` format and redaction policy used by TelemetryCore.

## Event Format

All diagnostics events are encoded as JSON objects with ISO8601 timestamps and sorted keys.

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `timestamp` | `String` | Yes | ISO8601 timestamp (UTC) when the event occurred. |
| `level` | `String` | Yes | Severity: `debug`, `info`, `warning`, `error`, `critical`. |
| `category` | `String` | Yes | Hierarchical category (e.g., `textpipeline.unicode`). |
| `message` | `String` | Yes | Human-readable message with redaction applied. |
| `correlationID` | `String` | Yes | Trace identifier shared across spans/services. |
| `spanID` | `String` | No | Identifier for the span emitting the event. |
| `parentSpanID` | `String` | No | Identifier of the parent span, if any. |
| `duration` | `Number` | No | Duration in seconds for time-bounded events. |
| `metadata` | `Object` | Yes | Free-form tags for filtering/aggregation. |

Identity mapping:
- `correlationID` maps to `TraceID.rawValue` from `TraceContext`.
- `spanID` maps to `SpanID.rawValue`.
- `parentSpanID` maps to `TraceContext.parentSpanID?.rawValue`.
- `runID` is tracked in `TraceContext` for cross-span run grouping and can be emitted via metadata when needed.

### Example

```json
{
  "category" : "textpipeline.unicode",
  "correlationID" : "job-123",
  "level" : "info",
  "message" : "processed 1000 chars successfully",
  "metadata" : {
    "chars_processed" : "1000",
    "id" : "capsule-42"
  },
  "spanID" : "2B3D85B4-2D62-4F13-9E6E-48C0D3E4C3B1",
  "timestamp" : "2026-01-26T18:07:45Z"
}
```

## Redaction Policy

TelemetryCore sanitizes diagnostic payloads before storage or export.

- Message redaction: passwords, API keys, tokens, private keys, PII, IPs, and related secrets are replaced with `[REDACTED_*]` tokens.
- Metadata redaction: values for non-whitelisted keys are sanitized using the same rules.
- Safe keys: `id`, `count`, and `duration` are always allowed and never redacted (case-insensitive).
- Deep clean mode: when enabled, hexadecimal keys or base64 blobs longer than 32 characters are replaced with `[REDACTED_HEX_KEY]` or `[REDACTED_BASE64_BLOB]`.

Use `DiagnosticRedactionRules.sanitize(_:deepClean:)` and `DiagnosticRedactionRules.sanitizeMetadata(_:deepClean:)` to apply the policy.
