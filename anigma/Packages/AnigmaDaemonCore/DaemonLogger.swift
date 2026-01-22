//
//  DaemonLogger.swift
//  AnigmaDaemonCore
//
//  Comprehensive logging system with rotation and structured output for daemon operations.
//

import Foundation
import os.log

/// Log level for daemon messages
public enum DaemonLogLevel: String, CaseIterable, Comparable {
    case trace = "TRACE"
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    public var osLogType: OSLogType {
        switch self {
        case .trace, .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
    
    public static func < (lhs: DaemonLogLevel, rhs: DaemonLogLevel) -> Bool {
        let order: [DaemonLogLevel] = [.trace, .debug, .info, .warning, .error, .critical]
        return order.firstIndex(of: lhs) ?? 0 < order.firstIndex(of: rhs) ?? 0
    }
}

/// Log entry with structured metadata
public struct DaemonLogEntry: Codable {
    public let timestamp: Date
    public let level: DaemonLogLevel
    public let category: String
    public let message: String
    public let metadata: [String: String]
    public let threadId: UInt64
    public let processId: pid_t
    
    public init(
        timestamp: Date = Date(),
        level: DaemonLogLevel,
        category: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
        self.threadId = pthread_mach_thread_np(pthread_self())
        self.processId = getpid()
    }
}

/// Log rotation configuration
public struct LogRotationConfig {
    public let maxFileSize: UInt64
    public let maxFiles: Int
    public let rotationInterval: TimeInterval
    
    public init(
        maxFileSize: UInt64 = 50 * 1024 * 1024, // 50MB
        maxFiles: Int = 10,
        rotationInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    ) {
        self.maxFileSize = maxFileSize
        self.maxFiles = maxFiles
        self.rotationInterval = rotationInterval
    }
}

/// Comprehensive daemon logging system
public class DaemonLogger {
    
    private static let shared = DaemonLogger()
    
    private let config: LogRotationConfig
    private let logDirectory: URL
    private let osLog: OSLog
    private let dateFormatter: DateFormatter
    private let logQueue = DispatchQueue(label: "com.anigma.daemon.logging", qos: .utility)
    
    // Current log file handles
    private var currentLogFileHandle: FileHandle?
    private var currentLogFilePath: URL?
    private var currentLogFileSize: UInt64 = 0
    private var lastRotationTime: Date
    
    // Log level filtering
    private var minimumLogLevel: DaemonLogLevel = .info
    private var enabledCategories: Set<String> = Set(DaemonLogLevel.allCases.map { $0.rawValue })
    
    public init(
        logDirectory: URL,
        config: LogRotationConfig = LogRotationConfig(),
        minimumLogLevel: DaemonLogLevel = .info
    ) {
        self.logDirectory = logDirectory
        self.config = config
        self.minimumLogLevel = minimumLogLevel
        self.lastRotationTime = Date()
        
        self.osLog = OSLog(subsystem: "com.anigma.daemon", category: "daemon")
        
        self.dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        dateFormatter.timeZone = TimeZone.current
        
        // Ensure log directory exists
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        // Initialize current log file
        setupCurrentLogFile()
    }
    
    /// Set minimum log level
    public func setMinimumLevel(_ level: DaemonLogLevel) {
        logQueue.async {
            self.minimumLogLevel = level
        }
    }
    
    /// Enable/disable specific categories
    public func setCategories(_ categories: Set<String>) {
        logQueue.async {
            self.enabledCategories = categories
        }
    }
    
    /// Log a message with specified level and category
    public func log(
        level: DaemonLogLevel,
        category: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        logQueue.async { [weak self] in
            self?.writeLog(level: level, category: category, message: message, metadata: metadata)
        }
    }
    
    /// Log trace message
    public func trace(category: String, message: String, metadata: [String: String] = [:]) {
        log(level: .trace, category: category, message: message, metadata: metadata)
    }
    
    /// Log debug message
    public func debug(category: String, message: String, metadata: [String: String] = [:]) {
        log(level: .debug, category: category, message: message, metadata: metadata)
    }
    
    /// Log info message
    public func info(category: String, message: String, metadata: [String: String] = [:]) {
        log(level: .info, category: category, message: message, metadata: metadata)
    }
    
    /// Log warning message
    public func warning(category: String, message: String, metadata: [String: String] = [:]) {
        log(level: .warning, category: category, message: message, metadata: metadata)
    }
    
    /// Log error message
    public func error(category: String, message: String, metadata: [String: String] = [:]) {
        log(level: .error, category: category, message: message, metadata: metadata)
    }
    
    /// Log critical message
    public func critical(category: String, message: String, metadata: [String: String] = [:]) {
        log(level: .critical, category: category, message: message, metadata: metadata)
    }
    
    /// Get recent log entries
    public func getRecentEntries(limit: Int = 100, category: String? = nil) -> [DaemonLogEntry] {
        return logQueue.sync {
            guard let currentLogFilePath = currentLogFilePath else { return [] }
            
            do {
                let data = try Data(contentsOf: currentLogFilePath)
                let lines = String(data: data, encoding: .utf8)?.components(separatedBy: .newlines) ?? []
                
                var entries: [DaemonLogEntry] = []
                for line in lines.reversed() where !line.isEmpty {
                    if let entry = parseLogLine(line) {
                        if let category = category {
                            if entry.category.lowercased() == category.lowercased() {
                                entries.append(entry)
                                if entries.count >= limit { break }
                            }
                        } else {
                            entries.append(entry)
                            if entries.count >= limit { break }
                        }
                    }
                }
                
                return Array(entries.reversed())
            } catch {
                return []
            }
        }
    }
    
    /// Search log entries by message content
    public func searchEntries(searchTerm: String, limit: Int = 50) -> [DaemonLogEntry] {
        return logQueue.sync {
            guard let currentLogFilePath = currentLogFilePath else { return [] }
            
            do {
                let data = try Data(contentsOf: currentLogFilePath)
                let lines = String(data: data, encoding: .utf8)?.components(separatedBy: .newlines) ?? []
                
                var entries: [DaemonLogEntry] = []
                for line in lines.reversed() where !line.isEmpty {
                    if line.localizedCaseInsensitiveContains(searchTerm) {
                        if let entry = parseLogLine(line) {
                            entries.append(entry)
                            if entries.count >= limit { break }
                        }
                    }
                }
                
                return Array(entries.reversed())
            } catch {
                return []
            }
        }
    }
    
    /// Get log statistics
    public func getStatistics() -> LogStatistics {
        return logQueue.sync {
            var stats = LogStatistics()
            
            guard let currentLogFilePath = currentLogFilePath else {
                return stats
            }
            
            do {
                let data = try Data(contentsOf: currentLogFilePath)
                let lines = String(data: data, encoding: .utf8)?.components(separatedBy: .newlines) ?? []
                
                stats.totalEntries = lines.count
                stats.currentFileSize = currentLogFileSize
                stats.logFiles = getAllLogFiles().count
                
                for line in lines {
                    if let entry = parseLogLine(line) {
                        stats.entriesByLevel[entry.level, default: 0] += 1
                        stats.entriesByCategory[entry.category, default: 0] += 1
                    }
                }
                
            } catch {
                // Stats remain at default values
            }
            
            return stats
        }
    }
    
    /// Force log rotation
    public func rotateLogs() {
        logQueue.async { [weak self] in
            self?.performLogRotation()
        }
    }
    
    /// Cleanup old log files
    public func cleanupOldLogs() {
        logQueue.async { [weak self] in
            self?.performLogCleanup()
        }
    }
    
    // MARK: - Private Methods
    
    private func writeLog(level: DaemonLogLevel, category: String, message: String, metadata: [String: String]) {
        // Filter by log level
        guard level >= minimumLogLevel else { return }
        
        // Filter by category
        guard enabledCategories.contains(category) || enabledCategories.contains("*") else { return }
        
        // Create log entry
        let entry = DaemonLogEntry(
            level: level,
            category: category,
            message: message,
            metadata: metadata
        )
        
        // Write to OS log
        let osMessage = formatOSLogMessage(entry)
        os_log("%{public}@", log: osLog, type: level.osLogType, osMessage)
        
        // Write to file
        writeToFile(entry)
        
        // Check if rotation is needed
        checkRotationNeeded()
    }
    
    private func setupCurrentLogFile() {
        let fileName = "anigma-daemon-\(dateFormatter.string(from: Date())).log"
        currentLogFilePath = logDirectory.appendingPathComponent(fileName)
        
        guard let path = currentLogFilePath else { return }
        
        if !FileManager.default.fileExists(atPath: path.path) {
            FileManager.default.createFile(atPath: path.path, contents: nil)
        }
        
        do {
            currentLogFileHandle = try FileHandle(forWritingTo: path)
            currentLogFileHandle?.seekToEndOfFile()
            
            let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
            currentLogFileSize = (attributes[.size] as? UInt64) ?? 0
            
            // Write log header
            let header = "# Anigma Daemon Log Started at \(dateFormatter.string(from: Date()))\n"
            currentLogFileHandle?.write(header.data(using: .utf8) ?? Data())
            
        } catch {
            os_log("Failed to setup log file: %{public}@", log: osLog, type: .error, error.localizedDescription)
        }
    }
    
    private func writeToFile(_ entry: DaemonLogEntry) {
        guard let fileHandle = currentLogFileHandle else { return }
        
        let logLine = formatLogLine(entry)
        guard let data = logLine.data(using: .utf8) else { return }
        
        do {
            try fileHandle.write(contentsOf: data)
            currentLogFileSize += UInt64(data.count)
        } catch {
            os_log("Failed to write to log file: %{public}@", log: osLog, type: .error, error.localizedDescription)
        }
    }
    
    private func formatLogLine(_ entry: DaemonLogEntry) -> String {
        var components: [String] = []
        
        // Timestamp
        components.append(dateFormatter.string(from: entry.timestamp))
        
        // Level
        components.append("[\(entry.level.rawValue)]")
        
        // Category
        components.append("[\(entry.category)]")
        
        // Thread and Process ID
        components.append("[T:\(entry.threadId)|P:\(entry.processId)]")
        
        // Message
        components.append(entry.message)
        
        // Metadata
        if !entry.metadata.isEmpty {
            let metadataString = entry.metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            components.append("{\(metadataString)}")
        }
        
        return components.joined(separator: " ") + "\n"
    }
    
    private func formatOSLogMessage(_ entry: DaemonLogEntry) -> String {
        if entry.metadata.isEmpty {
            return "[\(entry.category)] \(entry.message)"
        } else {
            let metadataString = entry.metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            return "[\(entry.category)] \(entry.message) {\(metadataString)}"
        }
    }
    
    private func checkRotationNeeded() {
        let timeSinceRotation = Date().timeIntervalSince(lastRotationTime)
        
        if currentLogFileSize > config.maxFileSize || timeSinceRotation > config.rotationInterval {
            performLogRotation()
        }
    }
    
    private func performLogRotation() {
        guard let currentPath = currentLogFilePath else { return }
        
        // Close current file
        currentLogFileHandle?.closeFile()
        currentLogFileHandle = nil
        
        // Compress old log file
        let compressedPath = currentPath.appendingPathExtension("gz")
        compressLogFile(at: currentPath, to: compressedPath)
        
        // Remove uncompressed file
        try? FileManager.default.removeItem(at: currentPath)
        
        // Cleanup old files
        performLogCleanup()
        
        // Setup new log file
        lastRotationTime = Date()
        setupCurrentLogFile()
    }
    
    private func compressLogFile(at source: URL, to destination: URL) {
        do {
            let data = try Data(contentsOf: source)
            let compressedData = try (data as NSData).compressed(using: .lzfse)
            try compressedData.write(to: destination)
        } catch {
            os_log("Failed to compress log file: %{public}@", log: osLog, type: .error, error.localizedDescription)
            // If compression fails, just move the file
            try? FileManager.default.moveItem(at: source, to: destination)
        }
    }
    
    private func performLogCleanup() {
        let allLogFiles = getAllLogFiles()
        
        if allLogFiles.count > config.maxFiles {
            let filesToDelete = allLogFiles.sorted { $0.creationDate ?? Date.distantPast < $1.creationDate ?? Date.distantPast }
                .prefix(allLogFiles.count - config.maxFiles)
            
            for file in filesToDelete {
                try? FileManager.default.removeItem(at: file.url)
            }
        }
    }
    
    private func getAllLogFiles() -> [(url: URL, creationDate: Date?)] {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: logDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            return files.compactMap { url in
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    let creationDate = attributes[.creationDateKey] as? Date
                    return (url: url, creationDate: creationDate)
                } catch {
                    return nil
                }
            }.filter { $0.url.lastPathComponent.hasPrefix("anigma-daemon-") }
            
        } catch {
            return []
        }
    }
    
    private func parseLogLine(_ line: String) -> DaemonLogEntry? {
        // Expected format: "YYYY-MM-DD HH:MM:SS.sss [LEVEL] [CATEGORY] [T:thread|P:process] message {metadata}"
        
        let pattern = #"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}) \[([A-Z]+)\] \[([^\]]+)\] \[T:(\d+)\|P:(\d+)\] (.+)$"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else { return nil }
        
        guard let timestampRange = Range(match.range(at: 1), in: line),
              let levelRange = Range(match.range(at: 2), in: line),
              let categoryRange = Range(match.range(at: 3), in: line),
              let threadRange = Range(match.range(at: 4), in: line),
              let processRange = Range(match.range(at: 5), in: line),
              let messageRange = Range(match.range(at: 6), in: line) else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.timeZone = TimeZone.current
        
        guard let timestamp = formatter.date(from: String(line[timestampRange])) else { return nil }
        
        guard let level = DaemonLogLevel(rawValue: String(line[levelRange])) else { return nil }
        
        let message = String(line[messageRange])
        let category = String(line[categoryRange])
        let threadId = UInt64(String(line[threadRange])) ?? 0
        let processId = pid_t(String(line[processRange]))
        
        // Parse metadata if present
        var metadata: [String: String] = [:]
        if message.contains("{") && message.contains("}") {
            let metadataStart = message.firstIndex(of: "{")!
            let metadataEnd = message.lastIndex(of: "}")!
            let metadataString = String(message[message.index(after: metadataStart)..<metadataEnd])
            
            for pair in metadataString.components(separatedBy: ",") {
                let keyValue = pair.components(separatedBy: "=")
                if keyValue.count == 2 {
                    metadata[keyValue[0].trimmingCharacters(in: .whitespaces)] = keyValue[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        return DaemonLogEntry(
            timestamp: timestamp,
            level: level,
            category: category,
            message: message.components(separatedBy: " {").first ?? message, // Remove metadata from message
            metadata: metadata
        )
    }
}

// MARK: - Supporting Types

/// Log statistics
public struct LogStatistics {
    public var totalEntries: Int = 0
    public var currentFileSize: UInt64 = 0
    public var logFiles: Int = 0
    public var entriesByLevel: [DaemonLogLevel: Int] = [:]
    public var entriesByCategory: [String: Int] = [:]
}

// MARK: - Convenience Extensions

extension TelemetryClient {
    /// Create a TelemetryClient that uses DaemonLogger
    public static func daemonLogger(logDirectory: URL) -> TelemetryClient {
        let logger = DaemonLogger(logDirectory: logDirectory)
        
        return TelemetryClient { event in
            logger.log(
                level: event.level,
                category: event.category,
                message: "\(event.name): \(event.values)",
                metadata: event.values.mapValues { String(describing: $0) }
            )
        }
    }
}