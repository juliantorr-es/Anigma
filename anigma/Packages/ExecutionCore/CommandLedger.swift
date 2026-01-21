//
//  CommandLedger.swift
//  ExecutionCore
//
//  Command ledger implementation with deterministic encoding.
//  Provides stable API while wrapping existing ledger patterns.
//

import Foundation
import TelemetryCore

// MARK: - Command Ledger Types

/// Wire format for command ledger entries.
/// Codable format for persistence and transmission.
public struct CommandLedgerWire: Codable, Sendable {
    /// Unique identifier for this ledger entry
    public let entryID: String

    /// Type/kind of command
    public let kind: String

    /// Deterministic timestamp (milliseconds since epoch)
    public let timestampMs: Int64

    /// Session identifier (if applicable)
    public let sessionID: String?

    /// Agent that executed the command
    public let agent: String?

    /// Command that was executed
    public let command: String?

    /// Message/receipt ID (if applicable)
    public let messageID: String?

    /// Structured detail data (controlled keys only)
    public let details: [String: TelemetryValue]

    public init(
        entryID: String,
        kind: String,
        timestampMs: Int64,
        sessionID: String? = nil,
        agent: String? = nil,
        command: String? = nil,
        messageID: String? = nil,
        details: [String: TelemetryValue] = [:]
    ) {
        self.entryID = entryID
        self.kind = kind
        self.timestampMs = timestampMs
        self.sessionID = sessionID
        self.agent = agent
        self.command = command
        self.messageID = messageID
        self.details = details
    }
}

/// Filter criteria for ledger queries
public struct LedgerFilter: Codable, Sendable {
    public let kind: String?
    public let sessionID: String?
    public let agent: String?
    public let fromTimestampMs: Int64?
    public let toTimestampMs: Int64?

    public init(
        kind: String? = nil,
        sessionID: String? = nil,
        agent: String? = nil,
        fromTimestampMs: Int64? = nil,
        toTimestampMs: Int64? = nil
    ) {
        self.kind = kind
        self.sessionID = sessionID
        self.agent = agent
        self.fromTimestampMs = fromTimestampMs
        self.toTimestampMs = toTimestampMs
    }
}

// MARK: - Command Ledger Runtime

/// Runtime engine for command ledger operations.
/// Wraps existing ledger patterns with stable API.
public actor CommandLedger {
    private let ledgerURL: URL
    private let encoder: JSONEncoder
    private let telemetry: TelemetryClient

    public init(repoRoot: URL, telemetry: TelemetryClient) {
        let ledgerDir = repoRoot.appendingPathComponent(".opencode", isDirectory: true)
            .appendingPathComponent("ledger", isDirectory: true)
        self.ledgerURL = ledgerDir.appendingPathComponent("workflow.jsonl", isDirectory: false)

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]

        self.telemetry = telemetry
    }

    /// Appends a command entry to the ledger
    public func append(
        kind: String,
        sessionID: String? = nil,
        agent: String? = nil,
        command: String? = nil,
        messageID: String? = nil,
        details: [String: TelemetryValue] = [:]
    ) async throws -> String {
        let timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
        let entryID = UUID().uuidString

        let entry = CommandLedgerWire(
            entryID: entryID,
            kind: kind,
            timestampMs: timestampMs,
            sessionID: sessionID,
            agent: agent,
            command: command,
            messageID: messageID,
            details: details
        )

        // Write to JSONL file
        try await writeEntry(entry)

        // Emit telemetry
        _ = await telemetry.emit(
            category: .audit,
            name: "ledger_entry_created",
            values: [
                "entry_id": .hashedToken(TelemetryHash(input: entryID)),
                "kind": .hashedToken(TelemetryHash(input: kind)),
                "session_id": sessionID != nil ? .hashedToken(TelemetryHash(input: sessionID!)) : nil,
                "agent": agent != nil ? .hashedToken(TelemetryHash(input: agent!)) : nil
            ].compactMapValues { $0 }
        )

        return entryID
    }

    /// Reads ledger entries with optional filter
    public func read(filter: LedgerFilter? = nil) async throws -> [CommandLedgerWire] {
        guard FileManager.default.fileExists(atPath: ledgerURL.path) else {
            return []
        }

        let content = try String(contentsOf: ledgerURL, encoding: .utf8)
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)

        var entries: [CommandLedgerWire] = []

        for line in lines {
            guard let data = line.data(using: .utf8) else { continue }

            do {
                let entry = try decoder.decode(CommandLedgerWire.self, from: data)

                // Apply filter if provided
                if let filter = filter {
                    if !matchesFilter(entry: entry, filter: filter) {
                        continue
                    }
                }

                entries.append(entry)
            } catch {
                // Log error but continue processing other entries
                _ = await telemetry.emit(
                    category: .error,
                    name: "ledger_parse_error",
                    values: [
                        "error": .hashedToken(TelemetryHash(input: error.localizedDescription)),
                        "line_preview": .hashedToken(TelemetryHash(input: String(line.prefix(100))))
                    ]
                )
            }
        }

        // Return sorted by timestamp (newest first)
        return entries.sorted { $0.timestampMs > $1.timestampMs }
    }

    /// Gets ledger entries by session ID
    public func getBySession(sessionID: String) async throws -> [CommandLedgerWire] {
        let filter = LedgerFilter(sessionID: sessionID)
        return try await read(filter: filter)
    }

    /// Gets ledger entries by agent
    public func getByAgent(agent: String) async throws -> [CommandLedgerWire] {
        let filter = LedgerFilter(agent: agent)
        return try await read(filter: filter)
    }

    /// Gets ledger entries by kind
    public func getByKind(kind: String) async throws -> [CommandLedgerWire] {
        let filter = LedgerFilter(kind: kind)
        return try await read(filter: filter)
    }

    // MARK: - Private Helpers

    private let decoder = JSONDecoder()

    /// Writes a single entry to the JSONL file
    private func writeEntry(_ entry: CommandLedgerWire) async throws {
        let data = try encoder.encode(entry)
        guard let line = String(data: data, encoding: .utf8) else {
            fatalError("Failed to unwrap line")
        }

        // Ensure directory exists
        try FileManager.default.createDirectory(
            at: ledgerURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Atomic write
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .utility).async {
                do {
                    if FileManager.default.fileExists(atPath: self.ledgerURL.path) {
                        let handle = try FileHandle(forWritingTo: self.ledgerURL)
                        try handle.seekToEnd()
                        handle.write(line.data(using: .utf8)!)
                        try handle.close()
                    } else {
                        try line.write(to: self.ledgerURL, atomically: true, encoding: .utf8)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Checks if entry matches filter criteria
    private func matchesFilter(entry: CommandLedgerWire, filter: LedgerFilter) -> Bool {
        if let kind = filter.kind, entry.kind != kind {
            return false
        }

        if let sessionID = filter.sessionID, entry.sessionID != sessionID {
            return false
        }

        if let agent = filter.agent, entry.agent != agent {
            return false
        }

        if let fromTimestamp = filter.fromTimestampMs, entry.timestampMs < fromTimestamp {
            return false
        }

        if let toTimestamp = filter.toTimestampMs, entry.timestampMs > toTimestamp {
            return false
        }

        return true
    }
}

// MARK: - Shims for Compatibility

/// Compatibility shims for existing PraxisCore usage
extension CommandLedger {
    /// Compatibility shim for existing PraxisCore usage
    public func appendLegacy(
        kind: String,
        sessionID: String?,
        agent: String?,
        command: String,
        messageID: String?,
        detail: [String: String]? = nil
    ) async throws -> String {
        // Convert legacy string details to TelemetryValue format
        let details: [String: TelemetryValue] = (detail ?? [:]).mapValues { value in
            .hashedToken(TelemetryHash(input: value))
        }

        return try await append(
            kind: kind,
            sessionID: sessionID,
            agent: agent,
            command: command,
            messageID: messageID,
            details: details
        )
    }
}
