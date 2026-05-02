import Foundation

/// Severity levels for diagnostic events
public enum DiagnosticLevel: String, Codable, Sendable {
    case debug
    case info
    case warning
    case error
    case critical
    
    public var numericValue: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .critical: return 4
        }
    }
}

/// Status of a diagnostic span
public enum SpanStatus: String, Codable, Sendable {
    case ok
    case error
    case cancelled
    case unknown
}

/// A diagnostic span represents a unit of work with timing and status tracking
public protocol DiagnosticSpan: Sendable {
    /// Unique identifier for this span
    var spanID: String { get }
    
    /// Name of the span
    var name: String { get }
    
    /// Category of the span (e.g., "textpipeline.unicode")
    var category: String { get }
    
    /// Correlation ID for distributed tracing
    var correlationID: String { get }
    
    /// Start time of the span
    var startTime: Date { get }
    
    /// End time of the span (if ended)
    var endTime: Date? { get }
    
    /// Duration in seconds (calculated if span is ended)
    var duration: TimeInterval? { get }
    
    /// Final status of the span
    var status: SpanStatus? { get }
    
    /// Custom tags for this span
    var tags: [String: String] { get }
    
    /// End the span with a status
    func end(status: SpanStatus)
    
    /// Add a tag to the span
    func addTag(key: String, value: String)
    
    /// Record an event within the span
    func recordEvent(level: DiagnosticLevel, message: String)
}

/// The main diagnostics interface for capsules
public protocol CapsuleDiagnostics: Sendable {
    /// Create a new diagnostic span
    func beginSpan(
        name: String,
        category: String,
        correlationID: String?,
        tags: [String: String]
    ) -> DiagnosticSpan
    
    /// Record a diagnostic event
    func event(
        level: DiagnosticLevel,
        category: String,
        message: String,
        correlationID: String?,
        metadata: [String: String]
    )
    
    /// Retrieve events collected since a given date
    func getEvents(since: Date) -> [DiagnosticEvent]
    
    /// Retrieve all collected events
    func getAllEvents() -> [DiagnosticEvent]
    
    /// Clear all collected events
    func clearEvents()
}

public extension CapsuleDiagnostics {
    /// Backward-compatible alias for callers that still pass `tags`.
    func event(
        level: DiagnosticLevel,
        category: String,
        message: String,
        correlationID: String?,
        tags: [String: String]
    ) {
        event(
            level: level,
            category: category,
            message: message,
            correlationID: correlationID,
            metadata: tags
        )
    }
}

// MARK: - Default Implementation

/// Default in-memory implementation of CapsuleDiagnostics
public final class DefaultCapsuleDiagnostics: CapsuleDiagnostics {
    private nonisolated let lock = NSLock()
    private let maxEvents: Int
    
    // Protected by lock - wrap in nonisolated(unsafe) for Sendable conformance
    nonisolated(unsafe) private var events: [DiagnosticEvent] = []
    nonisolated(unsafe) private var spans: [DefaultDiagnosticSpan] = []
    
    public init(maxEvents: Int = 10000) {
        self.maxEvents = maxEvents
    }
    
    public func beginSpan(
        name: String,
        category: String,
        correlationID: String? = nil,
        tags: [String: String] = [:]
    ) -> DiagnosticSpan {
        let span = DefaultDiagnosticSpan(
            spanID: UUID().uuidString,
            name: name,
            category: category,
            correlationID: correlationID ?? CorrelationIDContext.current,
            tags: tags
        )
        
        lock.lock()
        defer { lock.unlock() }
        spans.append(span)
        
        return span
    }
    
    public func event(
        level: DiagnosticLevel,
        category: String,
        message: String,
        correlationID: String? = nil,
        metadata: [String: String] = [:]
    ) {
        let event = DiagnosticEvent(
            timestamp: Date(),
            level: level,
            category: category,
            message: DiagnosticRedactionRules.sanitize(message),
            correlationID: correlationID ?? CorrelationIDContext.current,
            metadata: DiagnosticRedactionRules.sanitizeMetadata(metadata)
        )
        
        lock.lock()
        defer { lock.unlock() }
        
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }
    
    public func getEvents(since: Date) -> [DiagnosticEvent] {
        lock.lock()
        defer { lock.unlock() }
        
        return events.filter { $0.timestamp >= since }
    }
    
    public func getAllEvents() -> [DiagnosticEvent] {
        lock.lock()
        defer { lock.unlock() }
        
        return events
    }
    
    public func clearEvents() {
        lock.lock()
        defer { lock.unlock() }
        
        events.removeAll()
    }
}

/// Default implementation of DiagnosticSpan
final class DefaultDiagnosticSpan: DiagnosticSpan {
    let spanID: String
    let name: String
    let category: String
    let correlationID: String
    let startTime: Date
    
    private nonisolated let lock = NSLock()
    nonisolated(unsafe) private var _endTime: Date?
    nonisolated(unsafe) private var _status: SpanStatus?
    nonisolated(unsafe) private var _tags: [String: String]
    nonisolated(unsafe) private var _events: [DiagnosticEvent] = []
    
    var endTime: Date? {
        lock.lock()
        defer { lock.unlock() }
        return _endTime
    }
    
    var duration: TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let endTime = _endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
    
    var status: SpanStatus? {
        lock.lock()
        defer { lock.unlock() }
        return _status
    }
    
    var tags: [String: String] {
        lock.lock()
        defer { lock.unlock() }
        return _tags
    }
    
    init(
        spanID: String,
        name: String,
        category: String,
        correlationID: String,
        tags: [String: String] = [:]
    ) {
        self.spanID = spanID
        self.name = name
        self.category = category
        self.correlationID = correlationID
        self.startTime = Date()
        self._tags = tags
    }
    
    func end(status: SpanStatus) {
        lock.lock()
        defer { lock.unlock() }
        
        _endTime = Date()
        _status = status
    }
    
    func addTag(key: String, value: String) {
        lock.lock()
        defer { lock.unlock() }
        
        _tags[key] = value
    }
    
    func recordEvent(level: DiagnosticLevel, message: String) {
        lock.lock()
        defer { lock.unlock() }
        
        let event = DiagnosticEvent(
            timestamp: Date(),
            level: level,
            category: category,
            message: DiagnosticRedactionRules.sanitize(message),
            correlationID: correlationID,
            metadata: [:]
        )
        
        _events.append(event)
    }
}

// MARK: - Correlation ID Context

/// Thread-safe correlation ID context for distributed tracing
public enum CorrelationIDContext {
    private static let contextKey = "com.anigma.diagnostics.correlationID"
    
    @TaskLocal
    public static var currentID: String?
    
    /// Get the current correlation ID
    public static var current: String {
        // Prefer TaskLocal if available (Swift Concurrency)
        if let taskLocalID = currentID {
            return taskLocalID
        }
        
        // Fallback to thread dictionary for synchronous code
        if let existing = Thread.current.threadDictionary[contextKey] as? String {
            return existing
        }
        
        let id = UUID().uuidString
        Thread.current.threadDictionary[contextKey] = id
        return id
    }
    
    /// Set a correlation ID for the current context (thread-local fallback)
    public static func setCurrent(_ id: String) {
        Thread.current.threadDictionary[contextKey] = id
    }
    
    /// Clear the current correlation ID (thread-local fallback)
    public static func clear() {
        Thread.current.threadDictionary.removeObject(forKey: contextKey)
    }
    
    /// Execute a block with a specific correlation ID in a TaskLocal context
    public static func withID<T>(_ id: String, operation: () throws -> T) rethrows -> T {
        try $currentID.withValue(id) {
            try operation()
        }
    }
    
    /// Execute an async block with a specific correlation ID in a TaskLocal context
    public static func withID<T>(_ id: String, operation: () async throws -> T) async rethrows -> T {
        try await $currentID.withValue(id) {
            try await operation()
        }
    }
}
