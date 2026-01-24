//
//  Logging.swift
//  AnigmaCore
//
//  Structured logging utilities for the Anigma ECS.
//  Provides hooks for integrating with external logging systems.
//

import Foundation

// MARK: - Log Level

/// Log severity levels.
public enum LogLevel: Int, Comparable, Sendable {
    case trace = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case critical = 5

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var emoji: String {
        switch self {
        case .trace: return "🔍"
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }

    public var label: String {
        switch self {
        case .trace: return "TRACE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        case .critical: return "CRIT"
        }
    }
}

// MARK: - Log Entry

/// A structured log entry.
public struct LogEntry: Sendable {
    public let timestamp: Date
    public let level: LogLevel
    public let message: String
    public let category: String
    public let metadata: [String: String]
    public let file: String
    public let function: String
    public let line: UInt

    public init(
        timestamp: Date = Date(),
        level: LogLevel,
        message: String,
        category: String = "AnigmaCore",
        metadata: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.category = category
        self.metadata = metadata
        self.file = file
        self.function = function
        self.line = line
    }

    /// Formatted log line for console output.
    public var formatted: String {
        let filename = (file as NSString).lastPathComponent
        let meta = metadata.isEmpty ? "" : " \(metadata)"
        return "[\(level.label)] [\(category)] \(message)\(meta) (\(filename):\(line))"
    }
}

// MARK: - Log Handler Protocol

/// Protocol for log output handlers.
/// Implement this to integrate with external logging systems (swift-log, OSLog, etc.).
public protocol LogHandler: Sendable {
    func log(_ entry: LogEntry)
}

/// Default console log handler.
public struct ConsoleLogHandler: LogHandler {
    public let minLevel: LogLevel
    public let includeEmoji: Bool

    public init(minLevel: LogLevel = .info, includeEmoji: Bool = true) {
        self.minLevel = minLevel
        self.includeEmoji = includeEmoji
    }

    public func log(_ entry: LogEntry) {
        guard entry.level >= minLevel else { return }
        let prefix = includeEmoji ? "\(entry.level.emoji) " : ""
        print("\(prefix)\(entry.formatted)")
    }
}

// MARK: - Logger

/// Central logger for AnigmaCore.
/// Supports multiple handlers and structured metadata.
public actor Logger {
    public static let shared = Logger()

    private var handlers: [any LogHandler] = [ConsoleLogHandler()]
    private var defaultCategory: String = "AnigmaCore"
    private var globalMetadata: [String: String] = [:]

    private init() {}

    /// Sets the log handlers.
    public func setHandlers(_ handlers: [any LogHandler]) {
        self.handlers = handlers
    }

    /// Adds a log handler.
    public func addHandler(_ handler: any LogHandler) {
        handlers.append(handler)
    }

    /// Sets the default category for logs.
    public func setDefaultCategory(_ category: String) {
        self.defaultCategory = category
    }

    /// Sets global metadata that will be included in all logs.
    public func setGlobalMetadata(_ metadata: [String: String]) {
        self.globalMetadata = metadata
    }

    /// Logs a message.
    public func log(
        level: LogLevel,
        _ message: String,
        category: String? = nil,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        var allMetadata = globalMetadata
        for (key, value) in metadata {
            allMetadata[key] = value
        }

        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            category: category ?? defaultCategory,
            metadata: allMetadata,
            file: file,
            function: function,
            line: line
        )

        for handler in handlers {
            handler.log(entry)
        }
    }

    // MARK: - Convenience Methods

    public func trace(_ message: String, category: String? = nil, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: UInt = #line) {
        log(level: .trace, message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    public func debug(_ message: String, category: String? = nil, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: UInt = #line) {
        log(level: .debug, message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    public func info(_ message: String, category: String? = nil, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: UInt = #line) {
        log(level: .info, message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    public func warning(_ message: String, category: String? = nil, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: UInt = #line) {
        log(level: .warning, message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    public func error(_ message: String, category: String? = nil, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: UInt = #line) {
        log(level: .error, message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    public func critical(_ message: String, category: String? = nil, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: UInt = #line) {
        log(level: .critical, message, category: category, metadata: metadata, file: file, function: function, line: line)
    }
}

// MARK: - Free Functions

/// Convenience logging functions that use the shared logger.
/// These are synchronous wrappers for quick logging.

public func logTrace(_ message: String, category: String? = nil, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: UInt = #line) {
    Task { await Logger.shared.trace(message, category: category, metadata: metadata, file: file, function: function, line: line) }
}

public func logDebug(_ message: String, category: String? = nil, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: UInt = #line) {
    Task { await Logger.shared.debug(message, category: category, metadata: metadata, file: file, function: function, line: line) }
}

public func logInfo(_ message: String, category: String? = nil, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: UInt = #line) {
    Task { await Logger.shared.info(message, category: category, metadata: metadata, file: file, function: function, line: line) }
}

public func logWarning(_ message: String, category: String? = nil, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: UInt = #line) {
    Task { await Logger.shared.warning(message, category: category, metadata: metadata, file: file, function: function, line: line) }
}

public func logError(_ message: String, category: String? = nil, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: UInt = #line) {
    Task { await Logger.shared.error(message, category: category, metadata: metadata, file: file, function: function, line: line) }
}

public func logCritical(_ message: String, category: String? = nil, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: UInt = #line) {
    Task { await Logger.shared.critical(message, category: category, metadata: metadata, file: file, function: function, line: line) }
}
