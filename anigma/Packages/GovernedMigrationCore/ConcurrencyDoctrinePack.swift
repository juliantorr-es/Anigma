//
//  ConcurrencyDoctrinePack.swift
//  GovernedMigrationCore
//
//  [Brief description of file purpose]
//

#if GOVERNED_CORE

import Foundation
import DoctrineCore

public struct ConcurrencyDoctrinePack: DoctrinePack {
    public init() {}

    public func evaluate(for fileURL: URL) async throws -> [DoctrineViolation] {
        let stderr = try runSwiftTypecheck(fileURL: fileURL)

        if let violation = mapDiagnostics(stderr: stderr, filePath: fileURL.path) {
            return [violation]
        }

        return []
    }

    private func runSwiftTypecheck(fileURL: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")

        // Keep serialized diagnostics for future structured parsing, but v1 uses stderr.
        let diagPath = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("dia")

        process.arguments = [
            "swiftc",
            "-typecheck",
            "-strict-concurrency=complete",
            "-serialize-diagnostics",
            "-serialize-diagnostics-path", diagPath.path,
            fileURL.path
        ]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe() // Discard standard output

        try process.run()
        process.waitUntilExit()

        let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }

    private func mapDiagnostics(stderr: String, filePath: String) -> DoctrineViolation? {
        guard stderr.lowercased().contains("sendable") else { return nil }

        let (line, column, message) = parseFirstErrorLine(stderr: stderr, filePath: filePath)
        return DoctrineViolation(
            ruleId: "CS-002",
            severity: DoctrineCore.DoctrineSeverity.error,
            message: message ?? "Non-Sendable type used across an actor boundary.",
            filePath: filePath,
            lineNumber: line,
            columnNumber: column,
            context: stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func parseFirstErrorLine(stderr: String, filePath: String) -> (Int?, Int?, String?) {
        let lines = stderr.split(separator: "\n").map(String.init)
        guard let line = lines.first(where: { $0.contains("error:") }) ?? lines.first else {
            return (nil, nil, nil)
        }

        // Expect shape: /path/to/file.swift:line:column: error: message
        let components = line.split(separator: ":")
        guard components.count >= 4 else {
            let message = line.components(separatedBy: "error:").last?.trimmingCharacters(in: .whitespaces)
            return (nil, nil, message)
        }

        let lineNumber = Int(components[1])
        let columnNumber = Int(components[2])
        let messagePart = components.dropFirst(3).joined(separator: ":")
        let message = messagePart.replacingOccurrences(of: "error:", with: "").trimmingCharacters(in: .whitespaces)

        return (lineNumber, columnNumber, message.isEmpty ? nil : message)
    }
}

#endif
