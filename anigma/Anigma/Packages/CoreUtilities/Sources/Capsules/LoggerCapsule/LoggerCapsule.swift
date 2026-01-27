import Foundation
import CapsuleCore
import TelemetryCore

// MARK: - Logger Capsule

/// Structured logging wrapper capsule
public final class LoggerCapsule: Sendable {
    
    // MARK: - Properties
    
    public let id: String
    private let diagnostics: CapsuleDiagnostics
    private let configuration: LoggerConfiguration
    private let formatter: LogFormatter
    private let output: LogOutput
    private let filter: LogFilter
    
    // MARK: - Initialization
    
    /// Initialize LoggerCapsule
    /// - Parameters:
    ///   - id: Unique identifier for this logger instance
    ///   - diagnostics: Diagnostics collector for observability
    ///   - configuration: Logger configuration
    ///   - formatter: Log formatter (default: JSONFormatter)
    ///   - output: Log output destination (default: ConsoleOutput)
    ///   - filter: Log filter (default: LevelFilter)
    public init(
        id: String = UUID().uuidString,
        diagnostics: CapsuleDiagnostics,
        configuration: LoggerConfiguration = .default,
        formatter: LogFormatter? = nil,
        output: LogOutput? = nil,
        filter: LogFilter? = nil
    ) {
        self.id = id
        self.diagnostics = diagnostics
        self.configuration = configuration
        self.formatter = formatter ?? JSONFormatter()
        self.output = output ?? ConsoleOutput()
        self.filter = filter ?? LevelFilter(minimumLevel: configuration.minimumLevel)
    }
    
    // MARK: - Public API
    
    /// Log a debug message
    /// - Parameters:
    ///   - message: Log message
    ///   - category: Log category
    ///   - metadata: Additional metadata
    ///   - correlationID: Request ID for tracing
    public func debug(
        _ message: String,
        category: String = "default",
        metadata: [String: String] = [:],
        correlationID: String? = nil
    ) {
        log(level: .debug, message: message, category: category, metadata: metadata, correlationID: correlationID)
    }
    
    /// Log an info message
    /// - Parameters:
    ///   - message: Log message
    ///   - category: Log category
    ///   - metadata: Additional metadata
    ///   - correlationID: Request ID for tracing
    public func info(
        _ message: String,
        category: String = "default",
        metadata: [String: String] = [:],
        correlationID: String? = nil
    ) {
        log(level: .info, message: message, category: category, metadata: metadata, correlationID: correlationID)
    }
    
    /// Log a warning message
    /// - Parameters:
    ///   - message: Log message
    ///   - category: Log category
    ///   - metadata: Additional metadata
    ///   - correlationID: Request ID for tracing
    public func warning(
        _ message: String,
        category: String = "default",
        metadata: [String: String] = [:],
        correlationID: String? = nil
    ) {
        log(level: .warning, message: message, category: category, metadata: metadata, correlationID: correlationID)
    }
    
    /// Log an error message
    /// - Parameters:
    ///   - message: Log message
    ///   - category: Log category
    ///   - error: Associated error
    ///   - metadata: Additional metadata
    ///   - correlationID: Request ID for tracing
    public func error(
        _ message: String,
        category: String = "default",
        error: Error? = nil,
        metadata: [String: String] = [:],
        correlationID: String? = nil
    ) {
        var errorMetadata = metadata
        if let error = error {
            errorMetadata["error_type"] = String(describing: type(of: error))
            errorMetadata["error_message"] = error.localizedDescription
            if let capsuleError = error as? CapsuleError {
                errorMetadata["capsule_error_code"] = "\(capsuleError.errorCode.rawValue)"
                errorMetadata["capsule_error_details"] = capsuleError.description
            }
        }
        
        log(level: .error, message: message, category: category, metadata: errorMetadata, correlationID: correlationID)
    }
    
    /// Log a critical message
    /// - Parameters:
    ///   - message: Log message
    ///   - category: Log category
    ///   - error: Associated error
    ///   - metadata: Additional metadata
    ///   - correlationID: Request ID for tracing
    public func critical(
        _ message: String,
        category: String = "default",
        error: Error? = nil,
        metadata: [String: String] = [:],
        correlationID: String? = nil
    ) {
        var errorMetadata = metadata
        if let error = error {
            errorMetadata["error_type"] = String(describing: type(of: error))
            errorMetadata["error_message"] = error.localizedDescription
            if let capsuleError = error as? CapsuleError {
                errorMetadata["capsule_error_code"] = "\(capsuleError.errorCode.rawValue)"
                errorMetadata["capsule_error_details"] = capsuleError.description
            }
        }
        
        log(level: .critical, message: message, category: category, metadata: errorMetadata, correlationID: correlationID)
    }
    
    /// Create a child logger with additional context
    /// - Parameters:
    ///   - context: Additional context metadata
    ///   - category: New category for child logger
    /// - Returns: Child logger instance
    public func child(
        context: [String: String],
        category: String? = nil
    ) -> LoggerCapsule {
        return LoggerChild(
            parent: self,
            context: context,
            category: category
        )
    }
    
    /// Get logger health status
    /// - Returns: Health information
    public func getHealthStatus() -> LoggerHealth {
        return LoggerHealth(
            status: .healthy,
            messagesLogged: 0, // Would need to track this
            errorsLogged: 0, // Would need to track this
            lastLogTime: Date(), // Would need to track this
            outputDestination: output.description
        )
    }
    
    // MARK: - Private Methods
    
    private func log(
        level: LogLevel,
        message: String,
        category: String,
        metadata: [String: String],
        correlationID: String?
    ) {
        let logEntry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            correlationID: correlationID ?? CorrelationIDContext.current,
            metadata: metadata,
            loggerID: id
        )
        
        // Apply filter
        guard filter.shouldLog(logEntry) else { return }
        
        // Format and output
        let formattedMessage = formatter.format(logEntry)
        output.write(formattedMessage)
        
        // Also send to diagnostics
        diagnostics.event(
            level: mapLogLevelToDiagnosticLevel(level),
            category: "logger.\(category)",
            message: message,
            correlationID: correlationID,
            metadata: metadata
        )
    }
    
    private func mapLogLevelToDiagnosticLevel(_ logLevel: LogLevel) -> DiagnosticLevel {
        switch logLevel {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .critical: return .critical
        }
    }
}

// MARK: - Child Logger

private class LoggerChild: LoggerCapsule {
    private let parent: LoggerCapsule
    private let context: [String: String]
    private let category: String?
    
    init(parent: LoggerCapsule, context: [String: String], category: String?) {
        self.parent = parent
        self.context = context
        self.category = category
        super.init(
            id: "\(parent.id).child",
            diagnostics: parent.diagnostics,
            configuration: parent.configuration,
            formatter: parent.formatter,
            output: parent.output,
            filter: parent.filter
        )
    }
    
    override func log(
        level: LogLevel,
        message: String,
        category: String,
        metadata: [String: String],
        correlationID: String?
    ) {
        var combinedMetadata = context
        for (key, value) in metadata {
            combinedMetadata[key] = value
        }
        
        super.log(
            level: level,
            message: message,
            category: category ?? self.category ?? category,
            metadata: combinedMetadata,
            correlationID: correlationID
        )
    }
}

// MARK: - Log Models

/// Log entry structure
public struct LogEntry: Codable, Sendable {
    public let timestamp: Date
    public let level: LogLevel
    public let category: String
    public let message: String
    public let correlationID: String
    public let metadata: [String: String]
    public let loggerID: String
    
    public init(
        timestamp: Date,
        level: LogLevel,
        category: String,
        message: String,
        correlationID: String,
        metadata: [String: String],
        loggerID: String
    ) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.correlationID = correlationID
        self.metadata = metadata
        self.loggerID = loggerID
    }
}

/// Log level enumeration
public enum LogLevel: String, Codable, Sendable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    
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

/// Logger configuration
public struct LoggerConfiguration: Sendable {
    public let minimumLevel: LogLevel
    public let includeMetadata: Bool
    public let includeCorrelationID: Bool
    public let enableStructuredLogging: Bool
    public let maxMessageLength: Int?
    
    public static let `default` = LoggerConfiguration(
        minimumLevel: .info,
        includeMetadata: true,
        includeCorrelationID: true,
        enableStructuredLogging: true,
        maxMessageLength: 10000
    )
    
    public init(
        minimumLevel: LogLevel = .info,
        includeMetadata: Bool = true,
        includeCorrelationID: Bool = true,
        enableStructuredLogging: Bool = true,
        maxMessageLength: Int? = 10000
    ) {
        self.minimumLevel = minimumLevel
        self.includeMetadata = includeMetadata
        self.includeCorrelationID = includeCorrelationID
        self.enableStructuredLogging = enableStructuredLogging
        self.maxMessageLength = maxMessageLength
    }
}

/// Logger health status
public struct LoggerHealth: Codable, Sendable {
    public let status: HealthStatus
    public let messagesLogged: Int
    public let errorsLogged: Int
    public let lastLogTime: Date
    public let outputDestination: String
    
    public init(
        status: HealthStatus,
        messagesLogged: Int,
        errorsLogged: Int,
        lastLogTime: Date,
        outputDestination: String
    ) {
        self.status = status
        self.messagesLogged = messagesLogged
        self.errorsLogged = errorsLogged
        self.lastLogTime = lastLogTime
        self.outputDestination = outputDestination
    }
}