# TelemetryCore

Canonical observability and diagnostics API for the Anigma capsule remediation plan (Phase 0).

## Overview

TelemetryCore provides a structured, thread-safe diagnostics API designed specifically for Anigma capsules. It ensures that all diagnostic information is correlated, redacted for secrets, and ready for ingestion by observability platforms.

## Key Features

- **Structured Diagnostic Events**: All events are fully `Codable` and follow the Phase 0 schema.
- **Thread-Safe Correlation**: Automatic propagation of correlation IDs across threads and Swift Concurrency Tasks.
- **Built-in Redaction**: Automatic scanning and redaction of passwords, API keys, JWTs, and other sensitive PII.
- **Span Tracking**: Support for time-bounded operations with status and duration tracking.

## Integration Guide

### Basic Usage

```swift
import TelemetryCore

// 1. Create a diagnostics instance
let diagnostics = DefaultCapsuleDiagnostics()

// 2. Set a correlation ID for the current context
let jobID = "job-123"
CorrelationIDContext.setCurrent(jobID)

// 3. Begin a span for a major operation
let span = diagnostics.beginSpan(
    name: "process",
    category: "textpipeline.unicode",
    correlationID: jobID,
    tags: ["input_size": "1000"]
)
defer { span.end(status: .ok) }

// 4. Record diagnostic events
diagnostics.event(
    level: .info,
    category: "textpipeline.unicode",
    message: "processed 1000 chars successfully",
    tags: ["chars_processed": "1000"]
)
```

### Swift Concurrency Support

For `async/await` code, use `withID` to ensure the correlation ID propagates correctly across task boundaries:

```swift
await CorrelationIDContext.withID("request-456") {
    // This ID is now available to all code called within this block,
    // even across child tasks.
    let result = await capsule.process(data)
}
```

### Automatic Redaction

TelemetryCore automatically protects your logs from leaking secrets:

```swift
diagnostics.event(
    level: .info,
    category: "auth",
    message: "Login attempt for user@example.com with password=secret123"
)
// Resulting message: "Login attempt for [REDACTED_EMAIL] with [REDACTED_PASSWORD]"
```

## Data Structures

### DiagnosticEvent

The core unit of observability, compliant with the Phase 0 Remediation Contract.

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | `Date` | ISO8601 formatted timestamp |
| `level` | `DiagnosticLevel` | debug, info, warning, error, critical |
| `category` | `String` | Hierarchical grouping (e.g. `network.http`) |
| `message` | `String` | Redacted diagnostic message |
| `correlationID` | `String` | ID for distributed tracing |
| `duration` | `TimeInterval?` | Optional timing information |
| `tags` | `[String: String]` | Key-value pairs for filtering |

## Best Practices

1. **Hierarchy**: Use categories like `capsule.engine.pipeline`.
2. **Context**: Prefer `tags` over embedding IDs in message strings for better searchability.
3. **Safety**: Never manually redact; let `TelemetryCore` handle it via `DiagnosticRedactionRules`.
4. **Lifecycle**: End spans in `defer` blocks to ensure they always close.
