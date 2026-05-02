//
//  HarmoniaRuntimePersistence.swift
//  HarmoniaRuntime
//
//  Durable local journaling for runtime receipts and audit events.
//

import ExecutionCore
import Foundation
import TelemetryCore

internal enum HarmoniaRuntimeJournalError: LocalizedError, Sendable {
    case directoryCreationFailed(path: String, reason: String)
    case receiptEncodingFailed(reason: String)
    case auditEncodingFailed(reason: String)
    case writeFailed(path: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let path, let reason):
            return "Failed to create HarmoniaRuntime journal directory at \(path): \(reason)"
        case .receiptEncodingFailed(let reason):
            return "Failed to encode HarmoniaRuntime receipt: \(reason)"
        case .auditEncodingFailed(let reason):
            return "Failed to encode HarmoniaRuntime audit event: \(reason)"
        case .writeFailed(let path, let reason):
            return "Failed to write HarmoniaRuntime journal entry to \(path): \(reason)"
        }
    }
}

internal final class HarmoniaRuntimeJournal: @unchecked Sendable {
    static let shared = HarmoniaRuntimeJournal()

    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.anigma.harmonia-runtime.journal")
    private let receiptsURL: URL
    private let auditURL: URL
    private let auditEncoder: JSONEncoder

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let baseDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(
            "Library/Application Support",
            isDirectory: true
        )

        let journalDirectory = baseDirectory
            .appendingPathComponent("Anigma", isDirectory: true)
            .appendingPathComponent("HarmoniaRuntime", isDirectory: true)

        self.receiptsURL = journalDirectory.appendingPathComponent(
            "harmonia_receipts.jsonl",
            isDirectory: false
        )
        self.auditURL = journalDirectory.appendingPathComponent(
            "harmonia_audit.jsonl",
            isDirectory: false
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        self.auditEncoder = encoder
    }

    func record(receipt: ReceiptWire) throws {
        do {
            let data = try receipt.deterministicJSON()
            try appendJSONLine(data, to: receiptsURL)
        } catch let error as HarmoniaRuntimeJournalError {
            throw error
        } catch {
            throw HarmoniaRuntimeJournalError.receiptEncodingFailed(reason: error.localizedDescription)
        }
    }

    func record(auditEvent: DiagnosticEvent) throws {
        do {
            let data = try auditEncoder.encode(auditEvent)
            try appendJSONLine(data, to: auditURL)
        } catch let error as HarmoniaRuntimeJournalError {
            throw error
        } catch {
            throw HarmoniaRuntimeJournalError.auditEncodingFailed(reason: error.localizedDescription)
        }
    }

    private func appendJSONLine(_ data: Data, to url: URL) throws {
        try queue.sync {
            let directoryURL = url.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directoryURL.path) {
                do {
                    try fileManager.createDirectory(
                        at: directoryURL,
                        withIntermediateDirectories: true,
                        attributes: [.posixPermissions: 0o700]
                    )
                } catch {
                    throw HarmoniaRuntimeJournalError.directoryCreationFailed(
                        path: directoryURL.path,
                        reason: error.localizedDescription
                    )
                }
            }

            var line = data
            line.append(0x0A)

            if fileManager.fileExists(atPath: url.path) {
                do {
                    let handle = try FileHandle(forWritingTo: url)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: line)
                } catch {
                    throw HarmoniaRuntimeJournalError.writeFailed(
                        path: url.path,
                        reason: error.localizedDescription
                    )
                }
            } else {
                do {
                    try line.write(to: url, options: .atomic)
                } catch {
                    throw HarmoniaRuntimeJournalError.writeFailed(
                        path: url.path,
                        reason: error.localizedDescription
                    )
                }
            }
        }
    }
}
