import Foundation

// MARK: - Log Formatter Protocol

/// Protocol for formatting log entries
public protocol LogFormatter: Sendable {
    /// Format a log entry into a string
    /// - Parameter entry: Log entry to format
    /// - Returns: Formatted log string
    func format(_ entry: LogEntry) -> String
}

// MARK: - JSON Formatter

/// JSON log formatter
public struct JSONFormatter: LogFormatter {
    private let encoder: JSONEncoder
    
    public init() {
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
    }
    
    public func format(_ entry: LogEntry) -> String {
        do {
            let data = try encoder.encode(entry)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\":\"Failed to format log entry\",\"message\":\"\(entry.message.replacingOccurrences(of: "\"", with: "\\\""))\"}"
        }
    }
}

// MARK: - Text Formatter

/// Plain text log formatter
public struct TextFormatter: LogFormatter {
    private let includeMetadata: Bool
    private let dateFormat: DateFormatter
    
    public init(includeMetadata: Bool = true) {
        self.includeMetadata = includeMetadata
        self.dateFormat = DateFormatter()
        dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    public func format(_ entry: LogEntry) -> String {
        let timestamp = dateFormat.string(from: entry.timestamp)
        var result = "[\(timestamp)] [\(entry.level.rawValue.uppercased())] [\(entry.category)] \(entry.message)"
        
        if includeMetadata && !entry.metadata.isEmpty {
            let metadataString = entry.metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            result += " {\(metadataString)}"
        }
        
        return result
    }
}

// MARK: - Log Output Protocol

/// Protocol for log output destinations
public protocol LogOutput: Sendable {
    /// Write a formatted log message
    /// - Parameter message: Formatted log message
    func write(_ message: String)
    
    /// Description of the output destination
    var description: String { get }
}

// MARK: - Console Output

/// Console log output
public struct ConsoleOutput: LogOutput {
    public let description = "console"
    
    public func write(_ message: String) {
        print(message)
    }
}

// MARK: - File Output

/// File log output
public class FileOutput: LogOutput {
    public let description: String
    private let fileHandle: FileHandle
    private let encoder: JSONEncoder
    
    public init(filePath: String) throws {
        self.description = "file://\(filePath)"
        
        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: filePath) {
            FileManager.default.createFile(atPath: filePath, contents: nil)
        }
        
        // Open file handle
        self.fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: filePath))
        self.fileHandle.seekToEndOfFile()
        
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }
    
    deinit {
        fileHandle.closeFile()
    }
    
    public func write(_ message: String) {
        guard let data = (message + "\n").data(using: .utf8) else { return }
        fileHandle.write(data)
    }
}

// MARK: - Log Filter Protocol

/// Protocol for filtering log entries
public protocol LogFilter: Sendable {
    /// Determine if a log entry should be logged
    /// - Parameter entry: Log entry to evaluate
    /// - Returns: True if the entry should be logged
    func shouldLog(_ entry: LogEntry) -> Bool
}

// MARK: - Level Filter

/// Filter logs by minimum level
public struct LevelFilter: LogFilter {
    private let minimumLevel: LogLevel
    
    public init(minimumLevel: LogLevel) {
        self.minimumLevel = minimumLevel
    }
    
    public func shouldLog(_ entry: LogEntry) -> Bool {
        return entry.level.numericValue >= minimumLevel.numericValue
    }
}

// MARK: - Category Filter

/// Filter logs by category
public struct CategoryFilter: LogFilter {
    private let allowedCategories: Set<String>
    private let deniedCategories: Set<String>
    
    public init(allowed: Set<String> = [], denied: Set<String> = []) {
        self.allowedCategories = allowed
        self.deniedCategories = denied
    }
    
    public func shouldLog(_ entry: LogEntry) -> Bool {
        if !deniedCategories.isEmpty && deniedCategories.contains(entry.category) {
            return false
        }
        
        if !allowedCategories.isEmpty && !allowedCategories.contains(entry.category) {
            return false
        }
        
        return true
    }
}

// MARK: - Composite Filter

/// Combine multiple filters
public struct CompositeFilter: LogFilter {
    private let filters: [LogFilter]
    private let operation: FilterOperation
    
    public enum FilterOperation {
        case and // All filters must pass
        case or  // At least one filter must pass
    }
    
    public init(filters: [LogFilter], operation: FilterOperation = .and) {
        self.filters = filters
        self.operation = operation
    }
    
    public func shouldLog(_ entry: LogEntry) -> Bool {
        switch operation {
        case .and:
            return filters.allSatisfy { $0.shouldLog(entry) }
        case .or:
            return filters.contains { $0.shouldLog(entry) }
        }
    }
}

// MARK: - Logger Extensions

extension LoggerCapsule {
    
    /// Log performance metrics
    /// - Parameters:
    ///   - operation: Operation name
    ///   - duration: Operation duration
    ///   - metadata: Additional metadata
    ///   - correlationID: Request ID for tracing
    public func performance(
        operation: String,
        duration: TimeInterval,
        metadata: [String: String] = [:],
        correlationID: String? = nil
    ) {
        var perfMetadata = metadata
        perfMetadata["operation"] = operation
        perfMetadata["duration_ms"] = String(format: "%.3f", duration * 1000)
        
        info(
            "Performance: \(operation) completed",
            category: "performance",
            metadata: perfMetadata,
            correlationID: correlationID
        )
    }
    
    /// Log user action
    /// - Parameters:
    ///   - action: Action name
    ///   - userID: User identifier
    ///   - metadata: Additional metadata
    ///   - correlationID: Request ID for tracing
    public func userAction(
        action: String,
        userID: String? = nil,
        metadata: [String: String] = [:],
        correlationID: String? = nil
    ) {
        var actionMetadata = metadata
        actionMetadata["action"] = action
        if let userID = userID {
            actionMetadata["user_id"] = userID
        }
        
        info(
            "User action: \(action)",
            category: "user_action",
            metadata: actionMetadata,
            correlationID: correlationID
        )
    }
    
    /// Log security event
    /// - Parameters:
    ///   - event: Security event name
    ///   - severity: Event severity
    ///   - metadata: Additional metadata
    ///   - correlationID: Request ID for tracing
    public func security(
        event: String,
        severity: String = "medium",
        metadata: [String: String] = [:],
        correlationID: String? = nil
    ) {
        var securityMetadata = metadata
        securityMetadata["security_event"] = event
        securityMetadata["severity"] = severity
        
        warning(
            "Security event: \(event)",
            category: "security",
            metadata: securityMetadata,
            correlationID: correlationID
        )
    }
    
    /// Log audit event
    /// - Parameters:
    ///   - action: Audit action
    ///   - resource: Resource being accessed
    ///   - userID: User performing action
    ///   - result: Action result
    ///   - metadata: Additional metadata
    ///   - correlationID: Request ID for tracing
    public func audit(
        action: String,
        resource: String,
        userID: String,
        result: String,
        metadata: [String: String] = [:],
        correlationID: String? = nil
    ) {
        var auditMetadata = metadata
        auditMetadata["audit_action"] = action
        auditMetadata["resource"] = resource
        auditMetadata["user_id"] = userID
        auditMetadata["result"] = result
        
        info(
            "Audit: \(action) on \(resource) by \(userID) - \(result)",
            category: "audit",
            metadata: auditMetadata,
            correlationID: correlationID
        )
    }
}

// MARK: - Utility Functions

/// Create a logger with default configuration
public func createLogger(
    id: String = UUID().uuidString,
    diagnostics: CapsuleDiagnostics,
    minimumLevel: LogLevel = .info,
    format: LogFormat = .json
) -> LoggerCapsule {
    let configuration = LoggerConfiguration(minimumLevel: minimumLevel)
    let formatter: LogFormatter = format == .json ? JSONFormatter() : TextFormatter()
    
    return LoggerCapsule(
        id: id,
        diagnostics: diagnostics,
        configuration: configuration,
        formatter: formatter
    )
}

/// Log format options
public enum LogFormat {
    case json
    case text
}

/// Create a composite filter with multiple criteria
public func filter(
    minimumLevel: LogLevel? = nil,
    allowedCategories: Set<String>? = nil,
    deniedCategories: Set<String>? = nil
) -> LogFilter {
    var filters: [LogFilter] = []
    
    if let minimumLevel = minimumLevel {
        filters.append(LevelFilter(minimumLevel: minimumLevel))
    }
    
    if let allowedCategories = allowedCategories, let deniedCategories = deniedCategories {
        filters.append(CategoryFilter(allowed: allowedCategories, denied: deniedCategories))
    } else if let allowedCategories = allowedCategories {
        filters.append(CategoryFilter(allowed: allowedCategories))
    } else if let deniedCategories = deniedCategories {
        filters.append(CategoryFilter(denied: deniedCategories))
    }
    
    if filters.isEmpty {
        return LevelFilter(minimumLevel: .debug) // Allow everything
    } else if filters.count == 1 {
        return filters[0]
    } else {
        return CompositeFilter(filters: filters, operation: .and)
    }
}