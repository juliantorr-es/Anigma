//
//  HarmoniaCommandHistory.swift
//  AnigmaAppMac
//
//  Tracks Harmonia CLI command invocations and results.
//

import Foundation
import AnigmaHostMac

/// Tracks and stores Harmonia CLI command history.
@MainActor
public final class HarmoniaCommandHistory: ObservableObject {
    public struct HistoryEntry: Identifiable, Codable {
        public let id: UUID
        public let timestamp: Date
        public let command: String
        public let arguments: [String]
        public let exitCode: Int32?
        public let duration: TimeInterval
        public let success: Bool
        public let output: String?
        public let error: String?

        public init(
            id: UUID = UUID(),
            timestamp: Date = Date(),
            command: String,
            arguments: [String],
            exitCode: Int32? = nil,
            duration: TimeInterval,
            success: Bool,
            output: String? = nil,
            error: String? = nil
        ) {
            self.id = id
            self.timestamp = timestamp
            self.command = command
            self.arguments = arguments
            self.exitCode = exitCode
            self.duration = duration
            self.success = success
            self.output = output
            self.error = error
        }

        public var fullCommand: String {
            "harmonia " + arguments.joined(separator: " ")
        }

        public var formattedDuration: String {
            String(format: "%.3fs", duration)
        }
    }

    @Published public private(set) var entries: [HistoryEntry] = []

    public var maxEntries: Int = 1000
    public var persistToDisk: Bool = true

    private let storageURL: URL

    public init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let harmoniaDir = appSupport.appendingPathComponent("Anigma/Harmonia", isDirectory: true)
        try? FileManager.default.createDirectory(at: harmoniaDir, withIntermediateDirectories: true)

        storageURL = harmoniaDir.appendingPathComponent("command_history.json")
        loadHistory()
    }

    public func record(
        command: String,
        arguments: [String],
        exitCode: Int32,
        duration: TimeInterval,
        success: Bool,
        output: String? = nil,
        error: String? = nil
    ) async {
        let entry = HistoryEntry(
            command: command,
            arguments: arguments,
            exitCode: exitCode,
            duration: duration,
            success: success,
            output: output,
            error: error
        )

        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        if persistToDisk {
            saveHistory()
        }
    }

    public func entries(for command: String) -> [HistoryEntry] {
        entries.filter { $0.command == command }
    }

    public var successfulEntries: [HistoryEntry] {
        entries.filter { $0.success }
    }

    public var failedEntries: [HistoryEntry] {
        entries.filter { !$0.success }
    }

    public func entries(fromLastHours hours: Int) -> [HistoryEntry] {
        let cutoff = Date().addingTimeInterval(-TimeInterval(hours * 3600))
        return entries.filter { $0.timestamp >= cutoff }
    }

    public func lastEntry(for command: String) -> HistoryEntry? {
        entries.first { $0.command == command }
    }

    public struct Statistics {
        public let totalCommands: Int
        public let successfulCommands: Int
        public let failedCommands: Int
        public let averageDuration: TimeInterval
        public let mostUsedCommand: String?
        public let successRate: Double

        public var formattedSuccessRate: String {
            String(format: "%.1f%%", successRate * 100)
        }
    }

    public var statistics: Statistics {
        let successful = successfulEntries.count
        let failed = failedEntries.count
        let total = entries.count

        let avgDuration = total > 0
            ? entries.map { $0.duration }.reduce(0, +) / Double(total)
            : 0

        var commandCounts: [String: Int] = [:]
        for entry in entries {
            commandCounts[entry.command, default: 0] += 1
        }
        let mostUsed = commandCounts.max { $0.value < $1.value }?.key
        let successRate = total > 0 ? Double(successful) / Double(total) : 0

        return Statistics(
            totalCommands: total,
            successfulCommands: successful,
            failedCommands: failed,
            averageDuration: avgDuration,
            mostUsedCommand: mostUsed,
            successRate: successRate
        )
    }

    public func clear() {
        entries.removeAll()
        if persistToDisk {
            saveHistory()
        }
    }

    public func clearOld(days: Int) {
        let cutoff = Date().addingTimeInterval(-TimeInterval(days * 86400))
        entries.removeAll { $0.timestamp < cutoff }
        if persistToDisk {
            saveHistory()
        }
    }

    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(entries)
    }

    public func exportCSV() -> String {
        var csv = "Timestamp,Command,Arguments,Exit Code,Duration,Success,Error\n"
        let dateFormatter = ISO8601DateFormatter()

        for entry in entries {
            let timestamp = dateFormatter.string(from: entry.timestamp)
            let arguments = entry.arguments.joined(separator: " ")
            let exitCode = entry.exitCode.map(String.init) ?? "N/A"
            let duration = String(format: "%.3f", entry.duration)
            let success = entry.success ? "true" : "false"
            let error = entry.error?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""

            csv += "\"\(timestamp)\",\"\(entry.command)\",\"\(arguments)\",\"\(exitCode)\",\"\(duration)\",\"\(success)\",\"\(error)\"\n"
        }

        return csv
    }

    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            try data.write(to: storageURL)
        } catch {
            print("[HarmoniaCommandHistory] Failed to save: \(error)")
        }
    }

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([HistoryEntry].self, from: data)
        } catch {
            print("[HarmoniaCommandHistory] Failed to load: \(error)")
        }
    }
}

extension HarmoniaClient {
    public func executeWithHistory<T: Decodable>(
        _ arguments: [String],
        history: HarmoniaCommandHistory,
        timeout: TimeInterval = 30.0
    ) async throws -> T {
        let startTime = Date()

        do {
            let result: T = try await execute(arguments, timeout: timeout)
            let duration = Date().timeIntervalSince(startTime)

            await history.record(
                command: arguments.first ?? "unknown",
                arguments: arguments,
                exitCode: 0,
                duration: duration,
                success: true,
                output: nil,
                error: nil
            )

            return result
        } catch {
            let duration = Date().timeIntervalSince(startTime)

            await history.record(
                command: arguments.first ?? "unknown",
                arguments: arguments,
                exitCode: -1,
                duration: duration,
                success: false,
                output: nil,
                error: error.localizedDescription
            )

            throw error
        }
    }
}
