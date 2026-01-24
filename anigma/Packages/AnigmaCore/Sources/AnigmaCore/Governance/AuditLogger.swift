//
//  AuditLogger.swift
//  AnigmaCore
//

import Foundation
import ContractsCore

/// Logs all sandboxed operations for audit trail.
public actor AuditLogger {
    private let logFile: URL

    public init(logFile: URL? = nil) {
        if let logFile = logFile {
            self.logFile = logFile
        } else {
            let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent("Logs")
                .appendingPathComponent("Anigma") ?? URL(fileURLWithPath: "/tmp/anigma_audit.log")

            self.logFile = logsDir.appendingPathComponent("audit.log")
        }

        // Create directory if needed
        let logDir = self.logFile.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
    }

    /// Log an operation.
    public func logOperation(
        engineId: String,
        operation: String,
        command: String,
        arguments: [String],
        config: SandboxConfig
    ) {
        let entry = AuditEntry(
            timestamp: Date(),
            engineId: engineId,
            operation: operation,
            command: command,
            arguments: arguments,
            error: nil,
            metadata: [
                "config_workingDirectory": config.workingDirectory,
                "config_allowedReadPaths": config.allowedReadPaths.joined(separator: ","),
                "config_allowedWritePaths": config.allowedWritePaths.joined(separator: ","),
                "config_allowNetwork": "\(config.allowNetwork)",
                "config_allowedEndpoints": config.allowedEndpoints.joined(separator: ","),
                "config_maxMemoryMB": "\(config.maxMemoryMB)",
                "config_maxCPUTimeSeconds": "\(config.maxCPUTimeSeconds)",
                "config_runAsDifferentUser": "\(config.runAsDifferentUser)"
            ]
        )
        logEntry(entry)
    }

    /// Log a result.
    public func logResult(
        engineId: String,
        operation: String,
        result: ProcessResult,
        startTime: Date,
        endTime: Date
    ) {
        let entry = AuditEntry(
            timestamp: endTime,
            engineId: engineId,
            operation: operation,
            command: nil,
            arguments: nil,
            error: result.succeeded ? nil : result.error,
            metadata: [
                "result_exitCode": "\(result.exitCode)",
                "result_output": result.output,
                "result_error": result.error,
                "result_duration": "\(result.duration)",
                "result_timedOut": "\(result.timedOut)"
            ]
        )
        logEntry(entry)
    }

    /// Log an error.
    public func logError(
        engineId: String,
        operation: String,
        error: String
    ) {
        let entry = AuditEntry(
            timestamp: Date(),
            engineId: engineId,
            operation: operation,
            command: nil,
            arguments: nil,
            error: error,
            metadata: nil
        )
        logEntry(entry)
    }

    /// Log a custom audit event with metadata.
    public func logCustomEvent(
        engineId: String,
        operation: String,
        metadata: [String: String]
    ) {
        let entry = AuditEntry(
            timestamp: Date(),
            engineId: engineId,
            operation: operation,
            command: nil,
            arguments: nil,
            error: nil,
            metadata: metadata
        )
        logEntry(entry)
    }

    /// Get audit trail for an engine.
    public func getAuditTrail(for engineId: String, limit: Int = 100) async -> [AuditEntry] {
        guard let data = try? Data(contentsOf: logFile),
              let entries = try? JSONDecoder().decode([AuditEntry].self, from: data) else {
            return []
        }

        return entries
            .filter { $0.engineId == engineId }
            .suffix(limit)
    }

    /// Get all audit entries.
    public func getAllEntries(limit: Int = 1000) async -> [AuditEntry] {
        guard let data = try? Data(contentsOf: logFile),
              let entries = try? JSONDecoder().decode([AuditEntry].self, from: data) else {
            return []
        }

        return entries.suffix(limit)
    }

    private func logEntry(_ entry: AuditEntry) {
        // This is a simple implementation. In a real system, we'd use a more efficient way to append to a log.
        // For this prototype, we read and write the whole file.

        // Note: Task used to avoid blocking actor during I/O
        Task {
            var entries = await getAllEntries(limit: 10000)
            entries.append(entry)

            if entries.count > 10000 {
                entries = Array(entries.suffix(10000))
            }

            if let data = try? JSONEncoder().encode(entries) {
                try? data.write(to: logFile)
            }
        }
    }
}
