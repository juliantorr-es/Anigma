//
//  CLIUtilities.swift
//  HarmoniaCLI
//
//  [Brief description of file purpose]
//

import Foundation

struct CLIError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

struct OutputWriter {
    static func emit<P: Encodable>(
        command: String,
        payload: P,
        format: OutputFormat,
        status: String = "ok"
    ) throws {
        let envelope = OutputEnvelope(
            status: status,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            command: command,
            payload: payload,
            contractVersion: 1,
            dbPath: ProcessInfo.processInfo.environment["HARMONIA_DB_PATH"],
            traceRecordingEnabled: nil,
            factoryType: nil
        )

        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(envelope)
            if let string = String(data: data, encoding: .utf8) {
                print(string)
            }
        case .text:
            print("status: \(status)")
            print("command: \(command)")
            print("payload: \(payload)")
        }
    }
}
