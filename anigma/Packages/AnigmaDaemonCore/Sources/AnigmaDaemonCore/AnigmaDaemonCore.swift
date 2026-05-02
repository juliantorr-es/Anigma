import Foundation
import TelemetryCore

public struct CapsuleSpanSummary: Codable, Sendable {
    public let spanID: String
    public let name: String
    public let category: String
    public let correlationID: String
    public let startTime: Date
    public let endTime: Date?
    public let duration: TimeInterval?
    public let status: SpanStatus?
    public let tags: [String: String]
}

public struct ExecutionOutput: Codable, Sendable {
    public let pipeline: VerticalSlicePipelineOutput

    public init(pipeline: VerticalSlicePipelineOutput) {
        self.pipeline = pipeline
    }
}

public struct ExecutionReceipt: Codable, Sendable {
    public let jobID: String
    public let correlationID: String
    public let status: String
    public let startedAt: Date
    public let finishedAt: Date
    public let diagnosticEvents: [DiagnosticEvent]
    public let capsuleSpanSummaries: [CapsuleSpanSummary]
    public let output: ExecutionOutput?

    public var duration: TimeInterval {
        finishedAt.timeIntervalSince(startedAt)
    }
}

public final class JobContext: @unchecked Sendable {
    public let jobID: String
    public let correlationID: String
    public let requestID: String
    public let runID: String?
    public let startedAt: Date

    private nonisolated let lock = NSLock()
    nonisolated(unsafe) private var events: [DiagnosticEvent] = []
    nonisolated(unsafe) private var spanSummaries: [CapsuleSpanSummary] = []

    public init(
        jobID: String,
        correlationID: String,
        requestID: String? = nil,
        runID: String? = nil,
        startedAt: Date = Date()
    ) {
        self.jobID = jobID
        self.correlationID = correlationID
        self.requestID = requestID ?? correlationID
        self.runID = runID
        self.startedAt = startedAt
    }

    public func record(event: DiagnosticEvent) {
        lock.lock()
        defer { lock.unlock() }
        events.append(event)
    }

    public func record(spanSummary: CapsuleSpanSummary) {
        lock.lock()
        defer { lock.unlock() }
        spanSummaries.append(spanSummary)
    }

    public func snapshotEvents() -> [DiagnosticEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    public func snapshotSpanSummaries() -> [CapsuleSpanSummary] {
        lock.lock()
        defer { lock.unlock() }
        return spanSummaries
    }

    public func executionReceipt(status: String, output: ExecutionOutput? = nil, finishedAt: Date = Date()) -> ExecutionReceipt {
        ExecutionReceipt(
            jobID: jobID,
            correlationID: correlationID,
            status: status,
            startedAt: startedAt,
            finishedAt: finishedAt,
            diagnosticEvents: snapshotEvents(),
            capsuleSpanSummaries: snapshotSpanSummaries(),
            output: output
        )
    }

    public func withCorrelationID<T>(operation: () throws -> T) rethrows -> T {
        try CorrelationIDContext.withID(correlationID, operation: operation)
    }

    public func withCorrelationID<T>(operation: () async throws -> T) async rethrows -> T {
        try await CorrelationIDContext.withID(correlationID, operation: operation)
    }

    public var structuredMetadata: [String: String] {
        var metadata: [String: String] = [
            "job_id": jobID,
            "request_id": requestID,
            "correlation_id": correlationID
        ]

        if let runID {
            metadata["run_id"] = runID
        }

        return metadata
    }
}

public final class CapsuleDiagnosticsRouter: CapsuleDiagnostics, @unchecked Sendable {
    private let context: JobContext
    private let downstream: CapsuleDiagnostics

    public init(context: JobContext, downstream: CapsuleDiagnostics = DefaultCapsuleDiagnostics()) {
        self.context = context
        self.downstream = downstream
    }

    public func beginSpan(
        name: String,
        category: String,
        correlationID: String? = nil,
        tags: [String: String] = [:]
    ) -> DiagnosticSpan {
        let resolvedCorrelationID = correlationID ?? context.correlationID
        let resolvedTags = context.structuredMetadata.merging(tags) { _, new in new }
        let span = downstream.beginSpan(
            name: name,
            category: category,
            correlationID: resolvedCorrelationID,
            tags: resolvedTags
        )
        return RoutedSpan(span: span, context: context)
    }

    public func event(
        level: DiagnosticLevel,
        category: String,
        message: String,
        correlationID: String? = nil,
        metadata: [String: String] = [:]
    ) {
        let resolvedCorrelationID = correlationID ?? context.correlationID
        let resolvedMetadata = context.structuredMetadata.merging(metadata) { _, new in new }
        downstream.event(
            level: level,
            category: category,
            message: message,
            correlationID: resolvedCorrelationID,
            metadata: resolvedMetadata
        )
        let event = DiagnosticEvent(
            timestamp: Date(),
            level: level,
            category: category,
            message: DiagnosticRedactionRules.sanitize(message),
            correlationID: resolvedCorrelationID,
            metadata: DiagnosticRedactionRules.sanitizeMetadata(resolvedMetadata)
        )
        context.record(event: event)
    }

    public func getEvents(since: Date) -> [DiagnosticEvent] {
        downstream.getEvents(since: since)
    }

    public func getAllEvents() -> [DiagnosticEvent] {
        downstream.getAllEvents()
    }

    public func clearEvents() {
        downstream.clearEvents()
    }
}

private final class RoutedSpan: DiagnosticSpan {
    private let span: DiagnosticSpan
    private let context: JobContext
    private nonisolated let lock = NSLock()
    nonisolated(unsafe) private var hasRecordedSummary = false

    init(span: DiagnosticSpan, context: JobContext) {
        self.span = span
        self.context = context
    }

    var spanID: String { span.spanID }
    var name: String { span.name }
    var category: String { span.category }
    var correlationID: String { span.correlationID }
    var startTime: Date { span.startTime }
    var endTime: Date? { span.endTime }
    var duration: TimeInterval? { span.duration }
    var status: SpanStatus? { span.status }
    var tags: [String: String] { span.tags }

    func end(status: SpanStatus) {
        span.end(status: status)

        lock.lock()
        defer { lock.unlock() }
        guard !hasRecordedSummary else { return }
        hasRecordedSummary = true

        let summary = CapsuleSpanSummary(
            spanID: spanID,
            name: name,
            category: category,
            correlationID: correlationID,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            status: status,
            tags: tags
        )
        context.record(spanSummary: summary)
    }

    func addTag(key: String, value: String) {
        span.addTag(key: key, value: value)
    }

    func recordEvent(level: DiagnosticLevel, message: String) {
        span.recordEvent(level: level, message: message)

        let event = DiagnosticEvent(
            timestamp: Date(),
            level: level,
            category: category,
            message: DiagnosticRedactionRules.sanitize(message),
            correlationID: correlationID,
            spanID: spanID,
            metadata: [:]
        )
        context.record(event: event)
    }
}
