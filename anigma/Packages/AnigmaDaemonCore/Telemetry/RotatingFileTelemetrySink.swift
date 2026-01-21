//
//  RotatingFileTelemetrySink.swift
//  AnigmaDaemonCore
//
//  Telemetry sink that writes structured logs to a rotating file.
//

import Foundation
import TelemetryCore


public actor RotatingFileTelemetrySink: TelemetrySink {
    public let id: String = "rotating_file"
    public let isEnabled: Bool = true

    private let fileURL: URL
    private let maxFileSize: UInt64
    private var fileHandle: FileHandle

    private let encoder: JSONEncoder

    public init(logDirectory: URL, fileName: String = "daemon.log", maxFileSize: UInt64 = 10 * 1024 * 1024) throws {
        self.maxFileSize = maxFileSize
        try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        self.fileURL = logDirectory.appendingPathComponent(fileName)

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }

        self.fileHandle = try FileHandle(forWritingTo: fileURL)
        self.fileHandle.seekToEndOfFile()

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.sortedKeys]
    }

    deinit {
        try? fileHandle.close()
    }

    public func handle(_ event: WireRedactedEvent) async throws {
        try writeSync(event)
    }

    public func flush() async throws {
        // Sync writing means it's already flushed or in the queue
    }

    private func writeSync(_ event: WireRedactedEvent) throws {
        // Check rotation
        let currentOffset = (try? fileHandle.offset()) ?? 0
        if currentOffset > maxFileSize {
            try rotate()
        }

        var data = try encoder.encode(event)
        data.append(contentsOf: [0x0A]) // Newline

        try fileHandle.write(contentsOf: data)
    }

    private func rotate() throws {
        try fileHandle.close()

        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let rotatedURL = fileURL.deletingPathExtension().appendingPathExtension("\(timestamp).log")

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.moveItem(at: fileURL, to: rotatedURL)
        }
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)

        self.fileHandle = try FileHandle(forWritingTo: fileURL)
    }
}
