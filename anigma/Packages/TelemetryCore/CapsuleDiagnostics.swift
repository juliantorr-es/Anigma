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
    var spanID: String { get }
    var name: String { get }
    var category: String { get }
    var correlationID: String { get }
    var startTime: Date { get }
    var endTime: Date? { get }
    var duration: TimeInterval? { get }
    var status: SpanStatus? { get }
    var tags: [String: String] { get }

    func end(status: SpanStatus)
    func addTag(key: String, value: String)
    func recordEvent(level: DiagnosticLevel, message: String)
}

/// The main diagnostics interface for capsules
public protocol CapsuleDiagnostics: Sendable {
    func beginSpan(
        name: String,
        category: String,
        correlationID: String?,
        tags: [String: String]
    ) -> DiagnosticSpan

    func event(
        level: DiagnosticLevel,
        category: String,
        message: String,
        correlationID: String?,
        tags: [String: String]
    )

    func getEvents(since: Date) -> [DiagnosticEvent]
    func getAllEvents() -> [DiagnosticEvent]
    func clearEvents()
}

/// Default in-memory implementation of CapsuleDiagnostics
public final class DefaultCapsuleDiagnostics: CapsuleDiagnostics {
    private nonisolated let lock = NSLock()
    private let maxEvents: Int

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
            tags: DiagnosticRedactionRules.sanitizeTags(tags)
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
        tags: [String: String] = [:]
    ) {
        let event = DiagnosticEvent(
            timestamp: Date(),
            level: level,
            category: category,
            message: DiagnosticRedactionRules.sanitize(message),
            correlationID: correlationID ?? CorrelationIDContext.current,
            tags: DiagnosticRedactionRules.sanitizeTags(tags)
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
            tags: [:]
        )

        _events.append(event)
    }
}

public enum CorrelationIDContext {
    private static let contextKey = "com.anigma.diagnostics.correlationID"

    @TaskLocal
    public static var currentID: String?

    public static var current: String {
        if let taskLocalID = currentID {
            return taskLocalID
        }

        if let existing = Thread.current.threadDictionary[contextKey] as? String {
            return existing
        }

        let id = UUID().uuidString
        Thread.current.threadDictionary[contextKey] = id
        return id
    }

    public static func setCurrent(_ id: String) {
        Thread.current.threadDictionary[contextKey] = id
    }

    public static func clear() {
        Thread.current.threadDictionary.removeObject(forKey: contextKey)
    }

    public static func withID<T>(_ id: String, operation: () throws -> T) rethrows -> T {
        try $currentID.withValue(id) {
            try operation()
        }
    }

    public static func withID<T>(_ id: String, operation: () async throws -> T) async rethrows -> T {
        try await $currentID.withValue(id) {
            try await operation()
        }
    }
}
