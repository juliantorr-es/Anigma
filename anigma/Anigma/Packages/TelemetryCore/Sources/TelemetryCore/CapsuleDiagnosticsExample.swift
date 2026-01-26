import Foundation

// MARK: - Example Integration Guide

/// This file demonstrates how to integrate CapsuleDiagnostics into a capsule.
/// 
/// ## Basic Usage
///
/// ```swift
/// // 1. Create a diagnostics instance (typically as a property in your capsule)
/// let diagnostics = DefaultCapsuleDiagnostics()
///
/// // 2. Set a correlation ID for the current context
/// let jobID = "job-123"
/// CorrelationIDContext.setCurrent(jobID)
///
/// // 3. Begin a span for a major operation
/// let span = diagnostics.beginSpan(
///     name: "process",
///     category: "textpipeline.unicode",
///     correlationID: jobID,
///     tags: ["input_size": "1000"]
/// )
/// defer { span.end(status: .ok) }
///
/// // 4. Record diagnostic events throughout your work
/// diagnostics.event(
///     level: .info,
///     category: "textpipeline.unicode",
///     message: "processed 1000 chars successfully",
///     correlationID: jobID,
///     metadata: ["chars_processed": "1000"]
/// )
///
/// // 5. Add events to the span for finer granularity
/// span.addTag(key: "output_size", value: "850")
/// span.recordEvent(level: .info, message: "normalization completed")
///
/// // 6. Retrieve events for analysis or export
/// let recentEvents = diagnostics.getEvents(since: Date(timeIntervalSinceNow: -3600))
/// for event in recentEvents {
///     if let jsonData = event.toJSONData() {
///         // Send to logging backend
///     }
/// }
/// ```
///
/// ## Key Features
///
/// ### Automatic Correlation ID Propagation
/// - If no correlationID is provided, the current context ID is used
/// - Set a correlation ID for tracing across async operations
/// ```swift
/// CorrelationIDContext.setCurrent("unique-job-id")
/// // All subsequent events will automatically use this ID
/// ```
///
/// ### Automatic Redaction
/// - All messages are automatically scanned for sensitive data
/// - Passwords, API keys, tokens, and PII are redacted
/// - Never worry about accidentally logging secrets
/// ```swift
/// diagnostics.event(
///     level: .info,
///     category: "auth",
///     message: "authenticated user with password=supersecret123",
///     correlationID: "op-456"
/// )
/// // Message becomes: "authenticated user with [REDACTED_PASSWORD]"
/// ```
///
/// ### Structured JSON Output
/// - All events serialize to structured JSON (not string soup)
/// - Ready for ingestion into observability platforms
/// ```swift
/// let event = diagnostics.getAllEvents().first!
/// let json = event.toJSON()
/// // Results in:
/// // {
/// //   "timestamp": "2024-01-26T10:30:45Z",
/// //   "level": "info",
/// //   "category": "textpipeline.unicode",
/// //   "message": "...",
/// //   "correlationID": "job-123",
/// //   "metadata": { "input_size": "1000" }
/// // }
/// ```
///
/// ### Span Timing and Status Tracking
/// - Spans automatically track start time
/// - Duration is calculated when span ends
/// - Status is recorded for error tracking
/// ```swift
/// let span = diagnostics.beginSpan(
///     name: "validation",
///     category: "textpipeline.unicode",
///     correlationID: "job-123"
/// )
/// do {
///     try validateInput(data)
///     span.end(status: .ok)
/// } catch {
///     span.end(status: .error)
///     diagnostics.event(
///         level: .error,
///         category: "textpipeline.unicode",
///         message: "validation failed: \(error)",
///         correlationID: "job-123"
///     )
/// }
/// ```
///
/// ## Integration with Capsule Lifecycle
///
/// ### In a TextProcessingCapsule
/// ```swift
/// public final class TextProcessingCapsule: Capsule {
///     private let diagnostics = DefaultCapsuleDiagnostics()
///
///     public func process(_ text: String, correlationID: String) async -> String {
///         CorrelationIDContext.setCurrent(correlationID)
///         defer { CorrelationIDContext.clear() }
///
///         let span = diagnostics.beginSpan(
///             name: "textProcessing",
///             category: "textpipeline.unicode",
///             correlationID: correlationID
///         )
///         defer { span.end(status: .ok) }
///
///         // Do work...
///         return processedText
///     }
/// }
/// ```
///
/// ## Best Practices
///
/// 1. **Set correlation IDs at entry points**: Set the context ID when entering your capsule
/// 2. **Use categories for organization**: Use hierarchical categories like "textpipeline.unicode.normalization"
/// 3. **Add metadata for context**: Use metadata to add queryable tags
/// 4. **Don't rely on manual redaction**: Trust the built-in redaction rules
/// 5. **Export periodically**: Retrieve and export events on a schedule
///

public struct CapsuleDiagnosticsExample {
    // This file is for documentation only and provides no runnable code
}
