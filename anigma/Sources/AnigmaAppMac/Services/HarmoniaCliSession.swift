//
//  HarmoniaCliSession.swift
//  AnigmaAppMac
//
//  Shared CLI execution state for launcher and backend-aware shells.
//

import Foundation
import Observation
import AnigmaHostMac

@MainActor
protocol HarmoniaCliExecution {
    var isAvailable: Bool { get }
    var statusLabel: String { get }
    func executeStreaming(
        _ arguments: [String],
        timeout: TimeInterval
    ) -> AsyncThrowingStream<String, Error>
}

@MainActor
struct HarmoniaClientBackend: HarmoniaCliExecution {
    let client: HarmoniaClient?
    let statusLabel: String

    init(client: HarmoniaClient?, statusLabel: String = "Connected") {
        self.client = client
        self.statusLabel = statusLabel
    }

    var isAvailable: Bool {
        client?.isBinaryAvailable == true
    }

    func executeStreaming(
        _ arguments: [String],
        timeout: TimeInterval
    ) -> AsyncThrowingStream<String, Error> {
        guard let client, isAvailable else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: HarmoniaClient.HarmoniaError.binaryNotFound("harmonia"))
            }
        }

        return client.executeStreaming(arguments, timeout: timeout)
    }
}

@MainActor
@Observable
final class HarmoniaCliSession {
    let history: HarmoniaCommandHistory

    var commandInput: String = ""
    var isExecuting: Bool = false
    var outputLines: [ConsoleEntry] = []
    var selectedHistoryEntry: HarmoniaCommandHistory.HistoryEntry?
    var showHistory: Bool = true

    private let backendResolver: () -> (any HarmoniaCliExecution)?
    private var executionOutput: [String] = []

    init(
        history: HarmoniaCommandHistory,
        backendResolver: @escaping () -> (any HarmoniaCliExecution)?
    ) {
        self.history = history
        self.backendResolver = backendResolver
    }

    var isBackendAvailable: Bool {
        backendResolver()?.isAvailable == true
    }

    var backendStatusLabel: String {
        backendResolver()?.statusLabel ?? "Unavailable"
    }

    func executeCommand() {
        let trimmedCommand = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty, !isExecuting else { return }

        guard isBackendAvailable else {
            addOutputLine("Error: Harmonia CLI backend is not available", level: .error)
            addOutputLine("Please ensure the Harmonia binary is installed and accessible", level: .warning)
            return
        }

        isExecuting = true
        outputLines.removeAll()
        executionOutput.removeAll()

        let arguments = parseCommandArguments(trimmedCommand)
        addOutputLine("$ harmonia \(trimmedCommand)", level: .info)

        Task { @MainActor in
            await executeCommandStreaming(arguments: arguments)
        }
    }

    func clearOutput() {
        outputLines.removeAll()
    }

    func clearHistory() {
        history.clear()
        selectedHistoryEntry = nil
    }

    func loadHistoryEntry(_ entry: HarmoniaCommandHistory.HistoryEntry) {
        commandInput = entry.arguments.joined(separator: " ")

        clearOutput()
        addOutputLine("# Historical command execution", level: .info)
        addOutputLine("$ \(entry.fullCommand)", level: .info)
        addOutputLine("Executed: \(formatFullDate(entry.timestamp))", level: .info)
        addOutputLine("Duration: \(entry.formattedDuration)", level: .info)

        if let output = entry.output {
            addOutputLine("--- Output ---", level: .info)
            for line in output.split(separator: "\n") {
                addOutputLine(String(line), level: .info)
            }
        }

        if let error = entry.error {
            addOutputLine("--- Error ---", level: .error)
            addOutputLine(error, level: .error)
        }

        addOutputLine(entry.success ? "✓ Success" : "✗ Failed", level: entry.success ? .success : .error)
    }

    private func executeCommandStreaming(arguments: [String]) async {
        guard let backend = backendResolver(), backend.isAvailable else {
            addOutputLine("Error: Harmonia CLI backend is not available", level: .error)
            isExecuting = false
            return
        }

        let startTime = Date()
        var sawOutput = false

        do {
            let stream = backend.executeStreaming(arguments, timeout: 300)
            for try await line in stream {
                sawOutput = true
                executionOutput.append(line)
                addOutputLine(line, level: .info)
            }

            let duration = Date().timeIntervalSince(startTime)
            if !sawOutput {
                addOutputLine("(no output)", level: .info)
            }
            addOutputLine("Command completed in \(String(format: "%.3fs", duration))", level: .success)

            await history.record(
                command: arguments.first ?? "unknown",
                arguments: arguments,
                exitCode: 0,
                duration: duration,
                success: true,
                output: executionOutput.isEmpty ? nil : executionOutput.joined(separator: "\n"),
                error: nil
            )

            isExecuting = false
            commandInput = ""
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            addOutputLine("Error: \(error.localizedDescription)", level: .error)

            await history.record(
                command: arguments.first ?? "unknown",
                arguments: arguments,
                exitCode: -1,
                duration: duration,
                success: false,
                output: executionOutput.isEmpty ? nil : executionOutput.joined(separator: "\n"),
                error: error.localizedDescription
            )

            isExecuting = false
        }
    }

    private func addOutputLine(_ message: String, level: LogLevel) {
        outputLines.append(
            ConsoleEntry(
                timestamp: Date(),
                message: message,
                level: level
            )
        )
    }

    private func parseCommandArguments(_ command: String) -> [String] {
        var arguments: [String] = []
        var currentArg = ""
        var inQuotes = false

        for character in command {
            switch character {
            case "\"":
                inQuotes.toggle()
            case " " where !inQuotes:
                if !currentArg.isEmpty {
                    arguments.append(currentArg)
                    currentArg = ""
                }
            default:
                currentArg.append(character)
            }
        }

        if !currentArg.isEmpty {
            arguments.append(currentArg)
        }

        return arguments
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
